#!/usr/bin/env python3
"""Build dictionary.db for Mull from Wiktionary (kaikki), SUBTLEX-UK, BNC and
Open English WordNet. See README.md for inputs and usage.

The app never transforms dictionary data at runtime (rule D6). Everything that
needs a decision is decided here, once, and the result is committed as
assets/db/dictionary.db.gz.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import gzip
import json
import math
import re
import sqlite3
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
SCHEMA = HERE / "schema.sql"
CURATION = HERE / "curation"

# ---------------------------------------------------------------- constants

# Parts of speech that make a vocabulary entry. Everything else (names,
# prefixes, symbols, characters, phrases) is dropped at stage 1.
WORD_POS = {"noun", "verb", "adj", "adv", "intj", "prep", "conj", "pron", "det", "num"}
IDIOM_POS = {"phrase", "verb", "noun", "adj", "adv", "prep_phrase", "intj", "proverb"}

# A sense carrying any of these is not a definition worth showing.
DROP_SENSE_TAGS = {
    "form-of", "alt-of", "obsolete", "archaic", "rare", "historical", "dated",
    "misspelling", "abbreviation", "initialism", "acronym", "no-gloss",
    "vulgar", "offensive", "slur", "in-compounds", "nonstandard", "proscribed",
    "misconstruction", "nonce-word", "pronunciation-spelling", "clipping",
    "ellipsis", "contraction", "morpheme", "letter",
}
DROP_GLOSS_PREFIX = re.compile(
    r"^\(?(alternative|obsolete|archaic|dated|rare|nonstandard|misspelling|eye dialect|"
    r"british|american|us|uk|commonwealth|canadian|australian)\b[^:]{0,40}?(spelling|form|"
    r"letter-case form|typography) of\b|^(plural|past|present participle|third-person singular|"
    r"comparative|superlative|synonym|abbreviation|initialism|acronym|short) (form )?(of|for)\b|"
    r"^\(?(taxonomy|taxonomic)|^a taxonomic ",
    re.IGNORECASE,
)
# Wiktionary maintenance categories carry no meaning and are most of the bytes.
NOISE_CATEGORY_RE = re.compile(
    r"^(Terms with .* translations|Pages with |Entries with |English (terms|lemmas|nouns|verbs|adjectives|adverbs|"
    r"countable|uncountable|entries|links|words|\d)|.* terms (with|in) |.* terms with redundant|"
    r"Requests for |Words |Rhymes:|Manglish|Singlish|Multiword)",
)
# Categories that mark proper nouns and taxonomy even when the pos is not "name".
DROP_CATEGORY_RE = re.compile(
    r"^(Places in|Cities in|Towns in|Villages in|Rivers in|Islands|Demonyms|Taxonomic names|"
    r"Individuals|Fictional characters|Organizations|Given names|Surnames|Countries|"
    r"Census-designated places|Unincorporated communities|Ghost towns|Suburbs of|"
    r"Former political divisions|Former settlements|Languages|Ethnonyms)",
)

INFLECTION_TAGS = {"plural", "past", "participle", "present", "comparative", "superlative", "third-person"}
US_SPELLING_TAGS = {"US", "American"}
UK_SPELLING_TAGS = {"UK", "British", "Commonwealth"}
RP_TAGS = {"Received-Pronunciation", "UK", "British"}

BANDS = (("core", 5_000), ("everyday", 10_000), ("well_read", 20_000), ("uncommon", 40_000))
BAND_TITLES = {
    "core": ("Easy Words", "The common core, worth being sure of."),
    "everyday": ("Everyday", "Words you will use this week."),
    "well_read": ("Well Read", "The vocabulary of essays and long novels."),
    "uncommon": ("Uncommon", "Rare, but worth having."),
}

REGISTER_TAGS = {"formal", "informal", "colloquial", "slang", "literary", "humorous",
                 "euphemistic", "derogatory", "vulgar", "dated", "rhetoric", "childish",
                 "offensive", "slur"}

# Topics whose senses should not lead a card when a plainer sense exists.
TECHNICAL_TOPICS = {
    "chemistry", "organic-chemistry", "inorganic-chemistry", "biochemistry", "physics", "mathematics",
    "computing", "programming", "medicine", "anatomy", "pathology", "biology", "microbiology",
    "zoology", "botany", "geology", "engineering", "law", "linguistics", "grammar", "phonology",
    "astronomy", "mineralogy", "genetics", "electronics", "military", "nautical", "heraldry",
    "cricket", "baseball", "chess", "poker", "card-games", "video-games", "sciences", "natural-sciences",
    "physical-sciences", "human-sciences", "finance", "economics", "statistics", "logic", "philosophy",
    "aviation", "aeronautics", "automotive", "railways", "rail-transport", "typography", "printing",
}

SHORT_MAX_WORDS = 15
MAX_SENSES_PER_POS = 4
MAX_EXAMPLES_PER_SENSE = 2
MAX_SYNONYMS_PER_SENSE = 6

# ---------------------------------------------------------------- helpers


def norm(s: str) -> str:
    """Lowercase, diacritics stripped, punctuation removed, whitespace collapsed."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = s.lower().replace("-", " ")
    s = re.sub(r"[^a-z0-9 ]+", "", s)
    return re.sub(r"\s+", " ", s).strip()


def short_definition(text: str, max_words: int = SHORT_MAX_WORDS) -> str:
    """Cap a gloss at max_words, cutting at a clause boundary and never mid-word."""
    words = text.split()
    if len(words) <= max_words:
        return text
    head = " ".join(words[:max_words])
    # Prefer the last clause boundary in the second half of the allowance.
    best = -1
    for m in re.finditer(r"[;:,]|\s(?:and|or|but|which|that|especially)\s", head):
        if m.start() >= len(" ".join(words[: max_words // 2])):
            best = m.start()
    if best > 0:
        return head[:best].rstrip(" ,;:") + "."
    return head.rstrip(" ,;:") + "…"


def clean_gloss(gloss: str) -> str:
    g = gloss.strip()
    # Leading label brackets: "(transitive, of a person) To ...".
    g = re.sub(r"^\((?:[^()]{1,60})\)\s*", "", g)
    g = re.sub(r"\s+", " ", g)
    if g and g[0].islower():
        g = g[0].upper() + g[1:]
    return g


EXAMPLE_BAD = re.compile(r"[ſ…\[\]\n|{}<>=_*#]|\.\.\.")


def good_example(text: str, needles: list[re.Pattern[str]]) -> bool:
    if not (20 <= len(text) <= 160):
        return False
    if EXAMPLE_BAD.search(text):
        return False
    # Modern text only: no long-s, and mostly ASCII letters.
    non_ascii = sum(1 for ch in text if ord(ch) > 127)
    if non_ascii > 3:
        return False
    return any(n.search(text) for n in needles)


def sense_examples(sense: dict, needles: list[re.Pattern[str]]) -> list[str]:
    usage, quotes = [], []
    for ex in sense.get("examples") or []:
        text = (ex.get("text") or "").strip()
        if not good_example(text, needles):
            continue
        (quotes if ex.get("ref") or ex.get("type") in ("quote", "quotation") else usage).append(text)
    picked = sorted(usage, key=len) + sorted(quotes, key=len)
    return picked[:MAX_EXAMPLES_PER_SENSE]


def pick_ipa(sounds: list[dict]) -> str | None:
    rp, untagged, any_ipa = None, None, None
    for s in sounds or []:
        ipa = s.get("ipa")
        if not ipa or not ipa.startswith("/"):
            continue
        tags = set(s.get("tags") or [])
        if tags & RP_TAGS and rp is None:
            rp = ipa
        elif not tags and untagged is None:
            untagged = ipa
        if any_ipa is None:
            any_ipa = ipa
    return rp or untagged or any_ipa


def sense_categories(sense: dict) -> list[str]:
    out = []
    for c in sense.get("categories") or []:
        name = c.get("name") if isinstance(c, dict) else c
        if name and not NOISE_CATEGORY_RE.match(name):
            out.append(name)
    return out


# ---------------------------------------------------------------- stage 1: parse


def stage1(kaikki: Path, cache: Path, rescan: bool) -> Path:
    """Stream the kaikki extract once and keep only what later stages need."""
    if cache.exists() and not rescan:
        print(f"stage 1: reusing {cache}")
        return cache
    cache.parent.mkdir(parents=True, exist_ok=True)
    kept = total = 0
    print(f"stage 1: scanning {kaikki} (this takes a few minutes)")
    with gzip.open(kaikki, "rt", encoding="utf-8") as fin, gzip.open(cache, "wt", encoding="utf-8") as fout:
        for line in fin:
            total += 1
            e = json.loads(line)
            if e.get("lang_code") != "en":
                continue
            word = e.get("word") or ""
            pos = e.get("pos")
            is_phrase = " " in word.strip()
            if is_phrase:
                if pos not in IDIOM_POS or not any("idiomatic" in (s.get("tags") or []) for s in e.get("senses", [])):
                    continue
            else:
                if pos not in WORD_POS or not word or not word[0].islower():
                    continue
                if not re.fullmatch(r"[a-z][a-z'\-]*", word):
                    continue
            slim = {
                "word": word,
                "pos": pos,
                "etym": e.get("etymology_number", 0),
                "ipa": pick_ipa(e.get("sounds") or []),
                "forms": [{"form": f.get("form"), "tags": f.get("tags") or []} for f in e.get("forms") or [] if f.get("form")],
                "senses": [
                    {
                        "glosses": s.get("glosses") or [],
                        "tags": s.get("tags") or [],
                        "topics": s.get("topics") or [],
                        "categories": sense_categories(s),
                        "examples": [
                            {"text": x.get("text"), "ref": bool(x.get("ref")), "type": x.get("type")}
                            for x in (s.get("examples") or []) if x.get("text")
                        ],
                        "synonyms": [x.get("word") for x in (s.get("synonyms") or []) if x.get("word")],
                    }
                    for s in e.get("senses") or []
                ],
            }
            fout.write(json.dumps(slim, ensure_ascii=False) + "\n")
            kept += 1
            if total % 200_000 == 0:
                print(f"  {total:,} lines, {kept:,} kept", flush=True)
    print(f"stage 1: {total:,} lines, {kept:,} entries cached to {cache}")
    return cache


def load_stage1(cache: Path):
    with gzip.open(cache, "rt", encoding="utf-8") as f:
        for line in f:
            yield json.loads(line)


# ---------------------------------------------------------------- frequency


def load_subtlex(path: Path) -> tuple[dict[str, int], int]:
    import openpyxl  # imported lazily so tests without the file still import this module

    print(f"frequency: reading {path.name}")
    wb = openpyxl.load_workbook(path, read_only=True)
    ws = wb.worksheets[0]
    rows = ws.iter_rows(values_only=True)
    header = next(rows)
    i_word, i_freq = header.index("Spelling"), header.index("Freq")
    freq: dict[str, int] = collections.defaultdict(int)
    for row in rows:
        w, f = row[i_word], row[i_freq]
        if isinstance(w, str) and isinstance(f, (int, float)):
            freq[w.lower()] += int(f)
    total = sum(freq.values())
    print(f"frequency: {len(freq):,} SUBTLEX-UK types, {total:,} tokens")
    return freq, total


def load_bnc_written(path: Path) -> tuple[dict[str, int], int]:
    freq: dict[str, int] = collections.defaultdict(int)
    total = 0
    with gzip.open(path, "rt", encoding="latin-1") as f:
        for line in f:
            parts = line.split()
            if len(parts) < 3:
                continue
            if parts[1] == "!!ANY":
                total = int(parts[0])
                continue
            freq[parts[1].lower()] += int(parts[0])
    print(f"frequency: {len(freq):,} BNC written types, {total:,} tokens")
    return freq, total


# ---------------------------------------------------------------- wordnet


def load_wordnet(path: Path) -> dict[tuple[str, str], set[str]]:
    """(lemma_lower, pos) -> set of synonym lemmas, from Open English WordNet."""
    print(f"wordnet: reading {path.name}")
    pos_map = {"n": "noun", "v": "verb", "a": "adj", "s": "adj", "r": "adv"}
    lemma_of_sense: dict[str, tuple[str, str]] = {}
    synset_members: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
    with gzip.open(path, "rb") as f:
        for _, el in ET.iterparse(f, events=("end",)):
            if el.tag != "LexicalEntry":
                continue
            lemma = el.find("Lemma")
            if lemma is None:
                el.clear()
                continue
            written = lemma.get("writtenForm", "")
            pos = pos_map.get(lemma.get("partOfSpeech", ""), None)
            if pos and " " not in written and re.fullmatch(r"[A-Za-z'\-]+", written):
                for sense in el.findall("Sense"):
                    synset_members[sense.get("synset")].append((written.lower(), pos))
            el.clear()
    syn: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    for members in synset_members.values():
        for w, p in members:
            for w2, _ in members:
                if w2 != w:
                    syn[(w, p)].add(w2)
    print(f"wordnet: {len(syn):,} lemma/pos pairs with synonyms")
    return syn


# ---------------------------------------------------------------- stage 2+: assemble


class Entry:
    __slots__ = ("headword", "pos", "senses", "ipa", "inflections", "us_spelling", "variants", "order")

    def __init__(self, headword: str, pos: str, order: int):
        self.headword = headword
        self.pos = pos
        self.senses: list[dict] = []
        self.ipa: str | None = None
        self.inflections: set[str] = set()
        self.us_spelling: str | None = None
        self.variants: set[str] = set()
        self.order = order


def british_headword(e: dict, subtlex: dict[str, int]) -> tuple[str, str | None, list[str]]:
    """Prefer the British spelling: of the entry word and its UK-tagged
    alternatives, the headword is the one SUBTLEX-UK (a British corpus) counts
    most. Returns (headword, us_spelling or None, other variants)."""
    word = e["word"]
    alts = [(f["form"], set(f["tags"])) for f in e["forms"]
            if "alternative" in f["tags"] and re.fullmatch(r"[a-z][a-z'\-]*", f["form"] or "")]
    uk = [f for f, t in alts if t & UK_SPELLING_TAGS]
    us = [f for f, t in alts if t & US_SPELLING_TAGS]
    head = max([word] + uk, key=lambda c: (subtlex.get(c, 0), c == word))
    if head != word:
        us_spelling = word
    else:
        us_spelling = us[0] if us else None
    variants = [f for f in uk + us if f != head and f != us_spelling]
    return head, us_spelling, variants


def keep_sense(s: dict) -> bool:
    if not s["glosses"]:
        return False
    tags = set(s["tags"])
    if tags & DROP_SENSE_TAGS:
        return False
    if any(DROP_CATEGORY_RE.match(c) for c in s["categories"]):
        return False
    gloss = s["glosses"][-1].strip()
    if not gloss or DROP_GLOSS_PREFIX.search(gloss):
        return False
    if len(gloss.split()) < 2:
        return False
    return True


def assemble_words(cache: Path, subtlex: dict[str, int]) -> tuple[dict[tuple[str, str], Entry], list[dict]]:
    """Merge kaikki entries into one Entry per (headword_norm, pos); collect idioms."""
    entries: dict[tuple[str, str], Entry] = {}
    idioms: list[dict] = []
    order = 0
    for e in load_stage1(cache):
        if " " in e["word"]:
            idioms.append(e)
            continue
        headword, us, variants = british_headword(e, subtlex)
        key = (norm(headword), e["pos"])
        ent = entries.get(key)
        if ent is None:
            order += 1
            ent = entries[key] = Entry(headword, e["pos"], order)
        if ent.ipa is None:
            ent.ipa = e["ipa"]
        if us and ent.us_spelling is None:
            ent.us_spelling = us
        ent.variants.update(variants)
        for f in e["forms"]:
            if set(f["tags"]) & INFLECTION_TAGS and re.fullmatch(r"[a-z][a-z'\-]*", f["form"]):
                ent.inflections.add(f["form"])
        seen_gloss = {s["glosses"][-1] for s in ent.senses}
        for s in e["senses"]:
            s["categories"] = [c for c in s["categories"] if not NOISE_CATEGORY_RE.match(c)]
            if keep_sense(s) and s["glosses"][-1] not in seen_gloss:
                ent.senses.append(s)
                seen_gloss.add(s["glosses"][-1])
    # Drop entries with no usable sense.
    entries = {k: v for k, v in entries.items() if v.senses}
    print(f"assemble: {len(entries):,} (headword, pos) entries with a definition, {len(idioms):,} idiom candidates")
    return entries, idioms


def rank_headwords(entries: dict[tuple[str, str], Entry], subtlex: dict[str, int], max_rank: int):
    """Aggregate SUBTLEX-UK over headword + US spelling + inflections; rank by total."""
    agg: dict[str, int] = collections.defaultdict(int)
    forms_of: dict[str, set[str]] = collections.defaultdict(set)
    for (hn, _), ent in entries.items():
        forms_of[hn].add(ent.headword.lower())
        if ent.us_spelling:
            forms_of[hn].add(ent.us_spelling.lower())
        forms_of[hn].update(f.lower() for f in ent.inflections)
    for hn, forms in forms_of.items():
        agg[hn] = sum(subtlex.get(f, 0) for f in forms)
    ranked = sorted((hn for hn in agg if agg[hn] > 0), key=lambda h: -agg[h])
    rank = {hn: i + 1 for i, hn in enumerate(ranked) if i < max_rank}
    print(f"rank: {len(ranked):,} headwords with frequency, {len(rank):,} within rank {max_rank:,}")
    return rank, forms_of


def band_of(rank: int) -> str:
    for name, limit in BANDS:
        if rank < limit:
            return name
    return BANDS[-1][0]


def freq_ratio(forms: set[str], subtlex, subtlex_total, bnc, bnc_total) -> float:
    s = sum(subtlex.get(f, 0) for f in forms)
    b = sum(bnc.get(f, 0) for f in forms)
    return math.log10((s + 1) / subtlex_total * 1e6) - math.log10((b + 1) / bnc_total * 1e6)


# ---------------------------------------------------------------- collections


def load_curation():
    with open(CURATION / "collections.yaml", encoding="utf-8") as f:
        cur = yaml.safe_load(f)
    with open(CURATION / "idioms.yaml", encoding="utf-8") as f:
        idi = yaml.safe_load(f) or {}
    return cur, idi


def build_topic_collections(cur: dict, words: list[dict], primary: dict[str, dict], ratio: dict[str, float],
                            min_size_override: int | None):
    """Return (collection defs, memberships). Signals apply in order 1, 2, 3, then manual."""
    defaults = cur.get("defaults", {})
    veto = set(defaults.get("veto_tags", []))
    out_defs, out_members, report = [], {}, {}
    by_head: dict[str, list[dict]] = collections.defaultdict(list)
    for w in words:
        by_head[w["headword_norm"]].append(w)

    for order, (slug, d) in enumerate(cur["collections"].items()):
        topics = set(d.get("topics") or [])
        cats = set(d.get("categories") or [])
        regs = set(d.get("registers") or [])
        regs_ex = set(d.get("registers_exclude") or [])
        bands = set(d.get("bands") or [b for b, _ in BANDS])
        fr = d.get("freq_ratio") or None
        include = [str(x) for x in d.get("include") or []]
        exclude = {norm(str(x)) for x in d.get("exclude") or []}
        max_size = int(d.get("max_size") or defaults.get("max_size", 400))
        min_size = min_size_override if min_size_override is not None else int(d.get("min_size") or defaults.get("min_size", 40))

        chosen: dict[str, tuple[dict, str]] = {}  # headword_norm -> (word row, source)

        def admit(w: dict, source: str, force: bool = False):
            hn = w["headword_norm"]
            if hn in exclude and not force:
                return
            if not force and (set(w["tags"]) & veto or w["band"] not in bands):
                return
            if hn not in chosen or force:
                chosen[hn] = (w, source)

        # Signal 1: Wiktionary topics and categories, on the specific sense.
        if topics or cats:
            for w in words:
                if set(w["topics"]) & topics or set(w["categories"]) & cats:
                    admit(w, "wiktionary_topic")
        # Signal 2: register labels, on the specific sense.
        if regs:
            for w in words:
                tags = set(w["tags"])
                if tags & regs and not tags & regs_ex:
                    admit(w, "register")
        # Signal 3: spoken/written ratio, on the headword's primary sense.
        if fr:
            lo, hi = fr.get("min", -1e9), fr.get("max", 1e9)
            for hn, w in primary.items():
                r = ratio.get(hn)
                if r is not None and lo <= r <= hi:
                    admit(w, "freq_ratio")
        # Signal 4: hand curation. Forced entries always win.
        for item in include:
            if "|" in item:
                hits = [w for w in words if w["word_key"] == item]
            else:
                hits = [primary[norm(item)]] if norm(item) in primary else []
            for w in hits:
                admit(w, "manual", force=True)

        members = sorted(chosen.values(), key=lambda t: t[0]["freq_rank"])
        forced = [m for m in members if m[1] == "manual"]
        auto = [m for m in members if m[1] != "manual"]
        members = forced + auto[: max(0, max_size - len(forced))]
        counts = collections.Counter(src for _, src in members)
        report[slug] = counts
        if len(members) < min_size:
            print(f"  WARNING: {slug} has {len(members)} members (< {min_size}); not shipped. {dict(counts)}")
            continue
        out_defs.append({"slug": slug, "title": d["title"], "description": d["description"], "kind": "topic",
                         "band": None, "icon": d.get("icon"), "sort_order": 100 + order})
        out_members[slug] = members
    return out_defs, out_members, report


# ---------------------------------------------------------------- idioms


def build_idioms(candidates: list[dict], rank: dict[str, int], idi: dict, max_size: int) -> list[dict]:
    include = {norm(p): p for p in idi.get("include") or []}
    exclude = {norm(p) for p in idi.get("exclude") or []}
    scored = []
    seen = set()
    for e in candidates:
        phrase = e["word"].strip()
        pn = norm(phrase)
        if pn in seen or pn in exclude:
            continue
        if not re.fullmatch(r"[a-z][a-z' \-]*", phrase) or not 2 <= len(pn.split()) <= 8:
            continue
        sense = next((s for s in e["senses"] if "idiomatic" in s["tags"] and keep_sense(s)), None)
        if sense is None:
            continue
        tags = set(sense["tags"])
        forced = pn in include
        if not forced and tags & {"vulgar", "offensive", "slur", "derogatory", "obsolete", "archaic", "dated"}:
            continue
        content = [w for w in pn.split() if w not in {"the", "a", "an", "of", "to", "in", "on", "at", "for", "and", "or", "one's", "ones", "someone", "someones", "somebody", "something", "it", "up", "out", "with", "off", "into", "be", "have", "get"}]
        ranks = [rank.get(w) for w in content]
        if not forced and (not content or any(r is None for r in ranks)):
            continue
        needles = [re.compile(re.escape(content[0]), re.IGNORECASE)] if content else []
        examples = sense_examples(sense, needles) if needles else []
        if not forced and not examples:
            continue
        if tags & {"formal", "literary"}:
            register = "formal"
        elif tags & {"informal", "colloquial", "slang", "humorous"}:
            register = "informal"
        elif tags & {"dated", "historical"}:
            register = "dated"
        else:
            register = "neutral"
        worst = max((r for r in ranks if r is not None), default=10**9)
        seen.add(pn)
        scored.append({
            "idiom_key": f"{pn}|idiom|1",
            "phrase": phrase,
            "phrase_norm": pn,
            "meaning": short_definition(clean_gloss(sense["glosses"][-1]), 40),
            "example": examples[0] if examples else None,
            "register": register,
            "_score": (0 if forced else 1, worst, len(pn)),
        })
    scored.sort(key=lambda d: d["_score"])
    missing = [p for k, p in include.items() if k not in seen]
    if missing:
        print(f"  idioms: {len(missing)} forced idioms not found in Wiktionary: {missing[:10]}")
    return scored[:max_size]


# ---------------------------------------------------------------- emit


def emit(db_path: Path, words, examples, synonyms, aliases, idioms, coll_defs, coll_members, word_tags, meta):
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.executescript(SCHEMA.read_text(encoding="utf-8"))
    con.executemany("INSERT INTO meta(key, value) VALUES (?, ?)", meta.items())
    con.executemany(
        "INSERT INTO words(id, word_key, headword, headword_norm, pos, sense_index, definition_short, definition_full, ipa, freq_rank, band)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        [(w["id"], w["word_key"], w["headword"], w["headword_norm"], w["pos"], w["sense_index"], w["definition_short"],
          w["definition_full"], w["ipa"], w["freq_rank"], w["band"]) for w in words],
    )
    con.executemany("INSERT INTO examples(word_key, text) VALUES (?, ?)", examples)
    con.executemany("INSERT INTO synonyms(word_key, synonym) VALUES (?, ?)", synonyms)
    con.executemany("INSERT OR IGNORE INTO aliases(alias_norm, word_key, kind) VALUES (?, ?, ?)", aliases)
    con.executemany(
        "INSERT INTO idioms(idiom_key, phrase, phrase_norm, meaning, example, register) VALUES (?,?,?,?,?,?)",
        [(i["idiom_key"], i["phrase"], i["phrase_norm"], i["meaning"], i["example"], i["register"]) for i in idioms],
    )
    for cid, d in enumerate(coll_defs, start=1):
        con.execute(
            "INSERT INTO collections(id, slug, title, description, kind, band, icon, sort_order) VALUES (?,?,?,?,?,?,?,?)",
            (cid, d["slug"], d["title"], d["description"], d["kind"], d["band"], d["icon"], d["sort_order"]),
        )
        con.executemany(
            "INSERT OR IGNORE INTO collection_words(collection_id, word_key, position, source) VALUES (?,?,?,?)",
            [(cid, w["word_key"], pos, src) for pos, (w, src) in enumerate(coll_members[d["slug"]])],
        )
    con.executemany("INSERT OR IGNORE INTO word_tags(word_key, tag) VALUES (?, ?)", word_tags)
    con.execute("INSERT INTO words_fts(words_fts) VALUES ('rebuild')")
    con.execute("INSERT INTO words_trigram(words_trigram) VALUES ('rebuild')")
    con.commit()
    con.execute("PRAGMA journal_mode = DELETE")
    con.execute("VACUUM")
    con.close()


# ---------------------------------------------------------------- main


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kaikki", type=Path, default=HERE / "raw" / "kaikki.org-dictionary-English.jsonl.gz")
    ap.add_argument("--subtlex", type=Path, default=HERE / "raw" / "SUBTLEX-UK_all.xlsx")
    ap.add_argument("--bnc", type=Path, default=HERE / "raw" / "bnc-written.num.gz")
    ap.add_argument("--wordnet", type=Path, default=HERE / "raw" / "english-wordnet-2024.xml.gz")
    ap.add_argument("--work", type=Path, default=HERE / "work")
    ap.add_argument("--out-dir", type=Path, default=HERE.parent.parent / "assets" / "db")
    ap.add_argument("--version", default=dt.date.today().strftime("%Y.%m.%d"))
    ap.add_argument("--max-rank", type=int, default=40_000, help="drop headwords ranked below this")
    ap.add_argument("--sample", type=int, default=0, help="build a stratified sample of N headwords")
    ap.add_argument("--min-collection-size", type=int, default=None, help="override the curation default")
    ap.add_argument("--idiom-cap", type=int, default=None, help="override curation max_size for idioms")
    ap.add_argument("--rescan", action="store_true", help="ignore the stage 1 cache")
    args = ap.parse_args(argv)

    cache = stage1(args.kaikki, args.work / "stage1.jsonl.gz", args.rescan)
    subtlex, subtlex_total = load_subtlex(args.subtlex)
    bnc, bnc_total = load_bnc_written(args.bnc)
    wordnet = load_wordnet(args.wordnet)
    cur, idi = load_curation()

    entries, idiom_candidates = assemble_words(cache, subtlex)
    rank, forms_of = rank_headwords(entries, subtlex, args.max_rank)
    # Two-letter headwords are abbreviations far more often than words
    # ("ac", "pm"); keep only the ones common enough to be real ("go", "up").
    entries = {k: v for k, v in entries.items() if k[0] in rank and (len(k[0]) >= 3 or rank[k[0]] < 2000)}

    # Sample: stratified across bands, evenly spaced by rank, plus every
    # curated include so the curation test can be run against the sample.
    if args.sample:
        forced = set()
        for d in cur["collections"].values():
            for x in d.get("include") or []:
                forced.add(norm(str(x)).split("|")[0])
        per_band = collections.defaultdict(list)
        for hn, r in sorted(rank.items(), key=lambda kv: kv[1]):
            if (hn, "noun") in entries or any((hn, p) in entries for p in WORD_POS):
                per_band[band_of(r)].append(hn)
        keep = set(h for h in forced if h in rank)
        quota = max(1, (args.sample - len(keep)) // len(BANDS))
        for b, hs in per_band.items():
            step = max(1, len(hs) // quota)
            keep.update(hs[::step][:quota])
        entries = {k: v for k, v in entries.items() if k[0] in keep}
        print(f"sample: {len(keep):,} headwords, {len(entries):,} entries")
        args.version = f"{args.version}-sample"

    # Flatten to sense rows. Primary sense per headword = first pos in
    # Wiktionary order, sense 1: that is what band collections play.
    words, examples, synonyms, aliases, word_tags = [], [], [], [], []
    primary: dict[str, dict] = {}
    next_id = 1
    for (hn, pos), ent in sorted(entries.items(), key=lambda kv: kv[1].order):
        r = rank[hn]
        needles = [re.compile(r"\b" + re.escape(f) + r"\b", re.IGNORECASE) for f in sorted(forms_of[hn], key=len, reverse=True)]
        wn_syn = sorted(wordnet.get((ent.headword.lower(), pos), ()), key=lambda s: rank.get(norm(s), 10**9))
        for idx, s in enumerate(ent.senses[:MAX_SENSES_PER_POS], start=1):
            key = f"{hn}|{pos}|{idx}"
            full = clean_gloss(s["glosses"][-1])
            row = {
                "id": next_id, "word_key": key, "headword": ent.headword, "headword_norm": hn, "pos": pos,
                "sense_index": idx, "definition_short": short_definition(full), "definition_full": full,
                "ipa": ent.ipa, "freq_rank": r, "band": band_of(r),
                "tags": s["tags"], "topics": s["topics"], "categories": s["categories"],
            }
            next_id += 1
            words.append(row)
            # The primary sense is what a band collection plays: the first
            # sense that is not a technical one, so "cracking" leads with
            # "very good" rather than petroleum chemistry.
            if hn not in primary or (
                set(primary[hn]["topics"]) & TECHNICAL_TOPICS and not set(s["topics"]) & TECHNICAL_TOPICS
            ):
                primary[hn] = row
            examples.extend((key, t) for t in sense_examples(s, needles))
            syns = []
            # Wiktionary synonyms are per sense; WordNet's are per lemma, so
            # they go on the first sense only rather than repeating four times.
            for cand in list(s["synonyms"]) + (wn_syn if idx == 1 else []):
                c = cand.strip()
                if c and " " not in c and norm(c) != hn and c.lower() not in syns:
                    syns.append(c.lower())
                if len(syns) >= MAX_SYNONYMS_PER_SENSE:
                    break
            synonyms.extend((key, sy) for sy in syns)
            word_tags.extend((key, f"tag:{t}") for t in s["tags"])
            word_tags.extend((key, f"topic:{t}") for t in s["topics"])
            word_tags.extend((key, f"category:{c}") for c in s["categories"])
            if idx == 1:
                if ent.us_spelling:
                    aliases.append((norm(ent.us_spelling), key, "us_spelling"))
                for f in ent.inflections:
                    if norm(f) != hn:
                        aliases.append((norm(f), key, "inflection"))
                for f in ent.variants:
                    if norm(f) != hn:
                        aliases.append((norm(f), key, "variant"))

    # Spoken/written ratio per headword (signal 3).
    ratio = {hn: freq_ratio(forms_of[hn], subtlex, subtlex_total, bnc, bnc_total) for hn in primary}

    # Collections: axis 1 from the band, axis 2 from the curation file.
    coll_defs, coll_members = [], {}
    for order, (b, _) in enumerate(BANDS):
        title, desc = BAND_TITLES[b]
        members = sorted((w for w in primary.values() if w["band"] == b), key=lambda w: w["freq_rank"])
        coll_defs.append({"slug": b, "title": title, "description": desc, "kind": "band", "band": b, "icon": None, "sort_order": order})
        coll_members[b] = [(w, "band") for w in members]
    topic_defs, topic_members, report = build_topic_collections(cur, words, primary, ratio, args.min_collection_size)
    coll_defs += topic_defs
    coll_members.update(topic_members)
    coll_defs.append({"slug": "idioms", "title": "Idioms", "description": "Phrases and where they came from.",
                      "kind": "idiom", "band": None, "icon": "quote", "sort_order": 999})
    coll_members["idioms"] = []

    idiom_cap = args.idiom_cap or int(idi.get("max_size") or 1500)
    if args.sample and args.idiom_cap is None:
        idiom_cap = min(idiom_cap, 200)
    idioms = build_idioms(idiom_candidates, rank, idi, idiom_cap)

    meta = {
        "dict_version": args.version,
        "built_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "source_attribution": (
            "Definitions, pronunciations, examples and idioms from Wiktionary via Kaikki.org (wiktextract), CC BY-SA 4.0. "
            "Frequency ranks from SUBTLEX-UK (van Heuven, Mandera, Keuleers & Brysbaert, 2014) and the British National Corpus. "
            "Synonyms from Open English WordNet 2024, CC BY 4.0."
        ),
        "entry_count": str(len(words)),
        "headword_count": str(len(primary)),
        "idiom_count": str(len(idioms)),
        "sample": "1" if args.sample else "0",
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.work.mkdir(parents=True, exist_ok=True)
    db_path = args.work / "dictionary.db"
    emit(db_path, words, examples, synonyms, aliases, idioms, coll_defs, coll_members, word_tags, meta)
    gz_path = args.out_dir / "dictionary.db.gz"
    with open(db_path, "rb") as fin, gzip.open(gz_path, "wb", compresslevel=9) as fout:
        while chunk := fin.read(1 << 20):
            fout.write(chunk)
    (args.out_dir / "dictionary.version").write_text(args.version + "\n", encoding="utf-8")

    # ---- build report
    print("\n=== build report ===")
    print(f"dict_version      {args.version}")
    print(f"headwords         {len(primary):,}")
    print(f"sense rows        {len(words):,}")
    band_counts = collections.Counter(w["band"] for w in primary.values())
    for b, _ in BANDS:
        print(f"  {b:<10} {band_counts.get(b, 0):>7,} headwords")
    print(f"examples          {len(examples):,}")
    print(f"synonyms          {len(synonyms):,}")
    print(f"aliases           {len(aliases):,}")
    print(f"idioms            {len(idioms):,}")
    print(f"uncompressed      {db_path.stat().st_size / 1e6:.1f} MB")
    print(f"compressed        {gz_path.stat().st_size / 1e6:.1f} MB  -> {gz_path}")
    rs = sorted(ratio.values())
    if rs:
        pct = lambda p: rs[min(len(rs) - 1, int(p * len(rs)))]
        print("freq_ratio (log10 spoken/million - log10 written/million), per headword:")
        print(f"  p05 {pct(.05):+.2f}  p25 {pct(.25):+.2f}  p50 {pct(.5):+.2f}  p75 {pct(.75):+.2f}  p95 {pct(.95):+.2f}")
        hist = collections.Counter(max(-3, min(3, round(r))) for r in rs)
        print("  histogram: " + "  ".join(f"{k:+d}:{hist[k]}" for k in sorted(hist)))
        print("  thresholds in use: daily_use >= +0.35, professional_words <= -0.50 (see curation/collections.yaml)")
    print("collections (members by producing signal):")
    for d in coll_defs:
        m = coll_members[d["slug"]]
        counts = collections.Counter(src for _, src in m)
        parts = "  ".join(f"{k}={v}" for k, v in sorted(counts.items()))
        print(f"  {d['slug']:<22} {len(m):>5}  {parts}")
    for slug, counts in report.items():
        if slug not in coll_members:
            print(f"  {slug:<22} REJECTED  {dict(counts)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
