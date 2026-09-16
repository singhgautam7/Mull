#!/usr/bin/env python3
"""Build dictionary.db for Mull. See README.md for inputs and usage.

Two datasets, one file, different rules:

  A. Lookup dictionary: every attested English word from Wiktionary (kaikki),
     lightly cleaned, no curation. Completeness is the only requirement.
  B. Learning set: ~5,000 words picked by prevalence, frequency, age of
     acquisition and register tags. Pure arithmetic, no LLM.
  C. LLM pass over the learning set: definitions, one example, synonyms,
     register and topics, rewritten from the source material, never invented.
  D. QA gates on every generated record; reject twice, drop the word.
  E. Collections built from the LLM topics, the norms, and the idiom table.

The app never transforms dictionary data at runtime (rule D6). Everything that
needs a decision is decided here, once, and the result is committed as
assets/db/dictionary.db.gz.
"""
from __future__ import annotations

import argparse
import collections
import csv
import datetime as dt
import gzip
import json
import math
import random
import re
import sqlite3
import statistics
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

# A sense carrying any of these is a redirect or noise, not a definition.
STUB_SENSE_TAGS = {
    "form-of", "alt-of", "misspelling", "no-gloss", "in-compounds", "morpheme", "letter",
    "misconstruction", "nonce-word", "pronunciation-spelling", "slur",
}
DROP_GLOSS_PREFIX = re.compile(
    r"^\(?(alternative|obsolete|archaic|dated|rare|nonstandard|misspelling|eye dialect|"
    r"british|american|us|uk|commonwealth|canadian|australian)\b[^:]{0,40}?(spelling|form|"
    r"letter-case form|typography) of\b|^(plural|past|present participle|third-person singular|"
    r"comparative|superlative|synonym|abbreviation|initialism|acronym|short) (form )?(of|for)\b|"
    r"^\(?(taxonomy|taxonomic)|^a taxonomic ",
    re.IGNORECASE,
)
# Redirect stubs whose gloss names the lemma but whose sense has no form_of.
STUB_GLOSS_RE = re.compile(
    r"^(?P<pre>(?:[a-z\-]+ ){0,7}?)(?:spelling|form|letter-case form|typography) of (?P<lemma>[a-z][a-z'\-]*)\.?$",
    re.IGNORECASE,
)
UK_LABEL_RE = re.compile(r"\b(british|uk|commonwealth)\b", re.IGNORECASE)
US_LABEL_RE = re.compile(r"\b(us|american|oxford)\b", re.IGNORECASE)


def is_uk_spelling_of(form: str, lemma: str, tags: set[str], label: str) -> bool:
    """A stub page is the British spelling of its lemma when it says so, is tagged
    so, or is the -ise twin of an -ize lemma (Wiktionary tags those inconsistently)."""
    if tags & UK_SPELLING_TAGS:
        return True
    if UK_LABEL_RE.search(label) and not US_LABEL_RE.search(label):
        return True
    return len(form) == len(lemma) and form != lemma and any(
        form[:i] + "z" + form[i + 1:] == lemma for i, ch in enumerate(form) if ch == "s")
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

# Senses with these tags are kept for lookup but shown after modern senses,
# with the label in the text, and never lead a learning card.
LABEL_TAGS = ("obsolete", "archaic", "dated", "historical", "rare", "dialectal", "vulgar",
              "offensive", "derogatory", "slang", "informal", "colloquial", "formal", "literary",
              "humorous", "euphemistic", "childish", "nonstandard", "proscribed")
OLD_TAGS = {"obsolete", "archaic", "dated", "historical"}
# A learning word must not lead with a sense carrying one of these.
LEARNING_VETO_TAGS = OLD_TAGS | {"rare", "dialectal", "vulgar", "offensive", "derogatory", "slang", "slur",
                                 "nonstandard", "proscribed", "abbreviation", "initialism", "acronym",
                                 "clipping", "ellipsis", "contraction", "childish", "ethnic", "humorous"}

INFLECTION_TAGS = {"plural", "past", "participle", "present", "comparative", "superlative", "third-person"}
US_SPELLING_TAGS = {"US", "American"}
UK_SPELLING_TAGS = {"UK", "British", "Commonwealth"}
RP_TAGS = {"Received-Pronunciation", "UK", "British"}

# Bands are "how likely are you to already know this", by prevalence. The
# learning set lives between LEARNING_PREVALENCE bounds; the cuts split it.
BANDS = ("core", "everyday", "well_read", "uncommon")
BAND_TITLES = {
    "core": ("Easy Words", "You probably know these. Worth being sure."),
    "everyday": ("Everyday", "Words you will meet this week."),
    "well_read": ("Well Read", "The vocabulary of essays and long novels."),
    "uncommon": ("Uncommon", "Rare, but worth having."),
}
BAND_CUTS = (0.92, 0.85, 0.75)          # prevalence >= cut -> core, everyday, well_read; else uncommon
RANK_CUTS = (5_000, 10_000, 20_000)      # fallback for words with no prevalence data

# Stage B filter.
# Prevalence saturates at 0.995 for ordinary adult vocabulary ("mundane" and
# "water" both score it), so it only has a floor. Age of acquisition, a cap on
# spoken frequency, and concreteness are what separate "mundane" from "water"
# and "temerity" from "duvet". Tuned against curation/holdout.yaml.
LEARNING_MIN_PREVALENCE = 0.65
LEARNING_MIN_ZIPF = 2.7          # on max(spoken, written): words that exist but never appear
LEARNING_MAX_ZIPF_SPOKEN = 4.0   # said too often to need teaching
LEARNING_MIN_AOA = 11.0
LEARNING_NO_AOA_MAX_PREVALENCE = 0.97  # no AoA rating: an unsaturated prevalence stands in for a late AoA
LEARNING_MAX_CONCRETENESS = 3.5  # nouns for things you can point at are not vocabulary to teach
REVIVAL_MIN_PREVALENCE = 0.65
LEARNING_POOL_TARGET = (4_000, 6_000)

# Stage C/E closed vocabularies. The model may only assign from these.
TOPICS = (
    "describing_people", "feelings", "intensity",
    "argument", "work", "money",
    "speech_and_writing", "time_and_change", "movement",
    "senses_and_perception", "weather_and_light", "food_and_taste",
    "society_and_news", "body_and_health", "thinking_and_knowing",
    "formal_register", "conversational_register", "borrowed_word",
)
REGISTERS = ("neutral", "formal", "informal", "literary", "technical")

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
MAX_EXAMPLES_PER_SENSE = 1
MAX_SYNONYMS_PER_SENSE = 6
COLLECTION_MIN, COLLECTION_MAX = 60, 200
COLLECTION_MID_PREVALENCE = 0.775

# Wiktionary spells a few idioms the American way; the phrase is shown British.
UK_SPELLING_SWAPS = {"colors": "colours", "color": "colour", "favor": "favour", "honor": "honour",
                     "center": "centre", "gray": "grey"}

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


def clean_etymology(text: str) -> str:
    """The opening of the etymology, without the 'Etymology tree' dump kaikki
    prepends: the first paragraph, plus the next while one ends in a colon."""
    paras = text.split("\n")
    if text.startswith("Etymology tree"):
        # The tree ends with the line "English <headword>"; the prose follows it.
        last = max((i for i, ln in enumerate(paras) if ln.startswith("English ")), default=-1)
        paras = paras[last + 1:]
    out = []
    for para in paras:
        para = para.strip()
        if not para:
            continue
        out.append(para)
        if not para.endswith(":"):
            break
    text = " ".join(out)
    if len(text) > 600:
        cut = text[:600].rsplit(". ", 1)[0]
        text = cut + "." if len(cut) > 100 else text[:600]
    return text


def sense_label(tags: list[str]) -> str:
    """'(obsolete, humorous) ' for a labelled sense, '' for a plain one."""
    labels = [t for t in LABEL_TAGS if t in tags]
    return f"({', '.join(labels)}) " if labels else ""


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


def sense_examples(sense: dict, needles: list[re.Pattern[str]], limit: int = MAX_EXAMPLES_PER_SENSE) -> list[str]:
    usage, quotes = [], []
    for ex in sense.get("examples") or []:
        text = (ex.get("text") or "").strip()
        if not good_example(text, needles):
            continue
        (quotes if ex.get("ref") or ex.get("type") in ("quote", "quotation") else usage).append(text)
    picked = sorted(usage, key=len) + sorted(quotes, key=len)
    return picked[:limit]


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


def britishise(phrase: str) -> str:
    return " ".join(UK_SPELLING_SWAPS.get(w, w) for w in phrase.split())


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
                "etymology": clean_etymology(e.get("etymology_text") or ""),
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
                        "form_of": [x.get("word") for x in (s.get("form_of") or []) + (s.get("alt_of") or []) if x.get("word")],
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


# ---------------------------------------------------------------- inputs


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


def load_xlsx_column(path: Path, sheet: int, word_col: str, value_col: str) -> dict[str, float]:
    import openpyxl

    ws = openpyxl.load_workbook(path, read_only=True).worksheets[sheet]
    rows = ws.iter_rows(values_only=True)
    header = next(rows)
    iw, iv = header.index(word_col), header.index(value_col)
    out: dict[str, float] = {}
    for r in rows:
        if isinstance(r[iw], str) and isinstance(r[iv], (int, float)):
            out.setdefault(r[iw].lower(), float(r[iv]))
    return out


def load_prevalence(path: Path) -> dict[str, float]:
    """UK share-known per word, 0..1, from the probit prevalence of the UK respondents."""
    probit = load_xlsx_column(path, 1, "Word", "Prevalence_UK")
    nd = statistics.NormalDist()
    out = {w: nd.cdf(z) for w, z in probit.items()}
    print(f"norms: {len(out):,} prevalence (Brysbaert et al. 2019, UK)")
    return out


def load_aoa(path: Path) -> dict[str, float]:
    out = load_xlsx_column(path, 0, "Word", "Rating.Mean")
    print(f"norms: {len(out):,} age of acquisition (Kuperman et al. 2012)")
    return out


def load_concreteness(path: Path) -> dict[str, float]:
    out: dict[str, float] = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            try:
                out.setdefault(row["Word"].lower(), float(row["Conc.M"]))
            except (ValueError, KeyError):
                pass
    print(f"norms: {len(out):,} concreteness (Brysbaert et al. 2014)")
    return out


def load_valence(path: Path) -> dict[str, float]:
    out: dict[str, float] = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            try:
                out.setdefault(row["Word"].lower(), float(row["V.Mean.Sum"]))
            except (ValueError, KeyError):
                pass
    print(f"norms: {len(out):,} valence (Warriner et al. 2013)")
    return out


def load_wordnet(path: Path) -> tuple[dict[tuple[str, str], set[str]], dict[tuple[str, str], str]]:
    """(lemma_lower, pos) -> synonyms, and -> the first synset's gloss. Glosses feed the
    LLM as source material only; they are never definition text."""
    print(f"wordnet: reading {path.name}")
    pos_map = {"n": "noun", "v": "verb", "a": "adj", "s": "adj", "r": "adv"}
    synset_members: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
    synset_gloss: dict[str, str] = {}
    with gzip.open(path, "rb") as f:
        for _, el in ET.iterparse(f, events=("end",)):
            if el.tag == "Synset":
                d = el.find("Definition")
                if d is not None and d.text:
                    synset_gloss[el.get("id")] = d.text.strip()
                el.clear()
                continue
            if el.tag != "LexicalEntry":
                continue
            lemma = el.find("Lemma")
            if lemma is not None:
                written = lemma.get("writtenForm", "")
                pos = pos_map.get(lemma.get("partOfSpeech", ""), None)
                if pos and " " not in written and re.fullmatch(r"[A-Za-z'\-]+", written):
                    for sense in el.findall("Sense"):
                        synset_members[sense.get("synset")].append((written.lower(), pos))
            el.clear()
    syn: dict[tuple[str, str], set[str]] = collections.defaultdict(set)
    gloss: dict[tuple[str, str], str] = {}
    for sid, members in synset_members.items():
        for w, p in members:
            gloss.setdefault((w, p), synset_gloss.get(sid, ""))
            for w2, _ in members:
                if w2 != w:
                    syn[(w, p)].add(w2)
    print(f"wordnet: {len(syn):,} lemma/pos pairs with synonyms")
    return syn, gloss


def load_curation() -> dict:
    out = {}
    for name in ("idioms", "holdout", "pairs"):
        with open(CURATION / f"{name}.yaml", encoding="utf-8") as f:
            out[name] = yaml.safe_load(f) or {}
    out["coverage"] = [ln.strip() for ln in (CURATION / "coverage.txt").read_text(encoding="utf-8").splitlines()
                       if ln.strip() and not ln.startswith("#")]
    return out


# ---------------------------------------------------------------- stage A: lookup


class Entry:
    __slots__ = ("headword", "pos", "senses", "ipa", "inflections", "us_spelling", "variants", "order", "etymology")

    def __init__(self, headword: str, pos: str, order: int):
        self.headword = headword
        self.pos = pos
        self.senses: list[dict] = []
        self.ipa: str | None = None
        self.inflections: set[str] = set()
        self.us_spelling: str | None = None
        self.variants: set[str] = set()
        self.order = order
        self.etymology = ""


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
    """A sense is a definition unless it is a redirect stub, a proper noun, or empty."""
    if not s["glosses"]:
        return False
    if set(s["tags"]) & STUB_SENSE_TAGS:
        return False
    if any(DROP_CATEGORY_RE.match(c) for c in s["categories"]):
        return False
    gloss = s["glosses"][-1].strip()
    if not gloss or DROP_GLOSS_PREFIX.search(gloss) or STUB_GLOSS_RE.match(gloss):
        return False
    return len(gloss.split()) >= 2


def is_old(s: dict) -> bool:
    return bool(set(s["tags"]) & OLD_TAGS)


def assemble_words(cache: Path, subtlex: dict[str, int]):
    """Merge kaikki entries into one Entry per (headword_norm, pos); collect idioms
    and the inflection stubs ("ran" -> "run") that become aliases."""
    entries: dict[tuple[str, str], Entry] = {}
    idioms: list[dict] = []
    stubs: list[tuple[str, str]] = []     # (form_norm, lemma_norm)
    uk_stubs: list[dict] = []             # "British spelling of X" pages, applied after the pass
    order = 0
    for e in load_stage1(cache):
        if " " in e["word"]:
            idioms.append(e)
            continue
        headword, us, variants = british_headword(e, subtlex)
        key = (norm(headword), e["pos"])
        for s in e["senses"]:
            targets = list(s["form_of"])
            label = ""
            m = STUB_GLOSS_RE.match(s["glosses"][-1]) if s["glosses"] and not targets else None
            if m:
                targets.append(m.group("lemma"))
                label = m.group("pre")
            if "alt-of" in s["tags"] and s["glosses"]:
                label = s["glosses"][-1]
            for lemma in targets:
                if (m or "alt-of" in s["tags"]) and is_uk_spelling_of(e["word"], lemma, set(s["tags"]), label):
                    uk_stubs.append({"form": e["word"], "pos": e["pos"], "lemma": norm(lemma),
                                     "forms": [f["form"] for f in e["forms"]], "ipa": e["ipa"]})
                    break
            for lemma in targets:
                if re.fullmatch(r"[a-z][a-z'\-]*", lemma) and norm(lemma) != key[0]:
                    stubs.append((key[0], norm(lemma)))
        ent = entries.get(key)
        if ent is None:
            order += 1
            ent = entries[key] = Entry(headword, e["pos"], order)
        if ent.ipa is None:
            ent.ipa = e["ipa"]
        if not ent.etymology:
            ent.etymology = e.get("etymology", "")
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
    entries = {k: v for k, v in entries.items() if v.senses}
    # "endeavour: British standard spelling of endeavor" is a stub page, and
    # the lemma page does not tag its alternative as UK. Rename the lemma's
    # entry to the British form when Britons use it at least as much.
    for st in uk_stubs:
        ent = entries.get((st["lemma"], st["pos"]))
        fn = norm(st["form"])
        if ent is None or fn == st["lemma"] or subtlex.get(fn, 0) < subtlex.get(st["lemma"], 0):
            continue
        if (fn, st["pos"]) in entries:
            continue
        ent.us_spelling, ent.headword = ent.headword, st["form"]
        ent.inflections.update(f for f in st["forms"] if re.fullmatch(r"[a-z][a-z'\-]*", f))
        ent.ipa = ent.ipa or st["ipa"]
        entries[(fn, st["pos"])] = entries.pop((st["lemma"], st["pos"]))
    for ent in entries.values():
        # Plain modern senses first; labelled ones are kept for lookup but never lead.
        ent.senses.sort(key=lambda s: (bool(set(s["tags"]) & LEARNING_VETO_TAGS), is_old(s)))
    print(f"assemble: {len(entries):,} (headword, pos) entries with a definition, "
          f"{len(idioms):,} idiom candidates, {len(stubs):,} inflection stubs")
    return entries, idioms, stubs


def forms_by_headword(entries: dict[tuple[str, str], Entry]) -> dict[str, set[str]]:
    forms_of: dict[str, set[str]] = collections.defaultdict(set)
    for (hn, _), ent in entries.items():
        forms_of[hn].add(ent.headword.lower())
        if ent.us_spelling:
            forms_of[hn].add(ent.us_spelling.lower())
        forms_of[hn].update(f.lower() for f in ent.inflections)
    return forms_of


def attested(hn: str, forms: set[str], ent_ipa: bool, subtlex, bnc, norms: set[str]) -> bool:
    """The lookup gate. Not a frequency cap: one appearance in a British corpus,
    a place in a psycholinguistic norm, or a recorded pronunciation is enough."""
    return (any(subtlex.get(f, 0) > 0 or bnc.get(f, 0) > 0 for f in forms)
            or hn in norms or ent_ipa)


def rank_headwords(forms_of: dict[str, set[str]], subtlex, bnc) -> dict[str, int]:
    """Every headword gets a rank: by SUBTLEX-UK count aggregated over its forms,
    then by BNC count for the ones subtitles never use, then alphabetically."""
    def score(hn):
        forms = forms_of[hn]
        return (-sum(subtlex.get(f, 0) for f in forms), -sum(bnc.get(f, 0) for f in forms), hn)
    return {hn: i + 1 for i, hn in enumerate(sorted(forms_of, key=score))}


def zipf(count: int, total: int) -> float | None:
    return math.log10(count / total * 1e9) if count > 0 else None


def band_of(prevalence: float | None, rank: int) -> str:
    if prevalence is not None:
        for b, cut in zip(BANDS, BAND_CUTS):
            if prevalence >= cut:
                return b
        return BANDS[-1]
    for b, cut in zip(BANDS, RANK_CUTS):
        if rank < cut:
            return b
    return BANDS[-1]


# ---------------------------------------------------------------- stage B: learning set


def select_learning_set(primary: dict[str, dict], ent_of: dict[str, Entry], alias_norms: set[str],
                        holdout: dict) -> tuple[dict[str, str], dict[str, int]]:
    """Pure arithmetic. Returns {headword_norm: 'learning' | 'revival'} and the
    pool size after each filter, in order, so the report shows what each removed."""
    stages = collections.OrderedDict()
    pool = list(primary)
    stages["headwords"] = len(pool)

    def step(label, keep):
        nonlocal pool
        pool = [hn for hn in pool if keep(primary[hn])]
        stages[label] = len(pool)

    step(f"prevalence >= {LEARNING_MIN_PREVALENCE:.2f}", lambda w: w["prevalence"] is not None and w["prevalence"] >= LEARNING_MIN_PREVALENCE)
    step(f"zipf >= {LEARNING_MIN_ZIPF}", lambda w: max(w["zipf_spoken"] or 0, w["zipf_written"] or 0) >= LEARNING_MIN_ZIPF)
    step(f"zipf spoken <= {LEARNING_MAX_ZIPF_SPOKEN}", lambda w: (w["zipf_spoken"] or 0) <= LEARNING_MAX_ZIPF_SPOKEN)
    step(f"aoa >= {LEARNING_MIN_AOA:.0f}, or unrated and prevalence < {LEARNING_NO_AOA_MAX_PREVALENCE}",
         lambda w: w["aoa"] >= LEARNING_MIN_AOA if w["aoa"] is not None else w["prevalence"] < LEARNING_NO_AOA_MAX_PREVALENCE)
    step(f"nouns: concreteness <= {LEARNING_MAX_CONCRETENESS}",
         lambda w: w["pos"] != "noun" or w["concreteness"] is None or w["concreteness"] <= LEARNING_MAX_CONCRETENESS)

    def is_lemma(w):
        hn, h = w["headword_norm"], w["headword"]
        if not re.fullmatch(r"[a-z]+(-[a-z]+)?", h) or len(hn) < 3:
            return False
        if hn in alias_norms and w["pos"] != "adj":   # "jaded" has its own adjective sense; "shivered" does not
            return False
        for suffix in ("ly", "ness"):
            if h.endswith(suffix) and (h[: -len(suffix)] in primary or h[: -len(suffix) - 1] + "y" in primary):
                return False
        return True
    step("form: a lemma, not an inflection or -ly/-ness derivative", is_lemma)
    step("not technical in every sense",
         lambda w: not all(set(s["topics"]) & TECHNICAL_TOPICS for s in ent_of[w["headword_norm"]].senses))

    out: dict[str, str] = {}
    for hn in pool:
        w = primary[hn]
        veto = set(w["tags"]) & LEARNING_VETO_TAGS
        if not veto:
            out[hn] = "learning"
        elif veto <= OLD_TAGS and w["prevalence"] >= REVIVAL_MIN_PREVALENCE:
            # Old and Worth Reviving: rejected only for age, and still widely known.
            out[hn] = "revival"
    stages["tags: not old, slang, vulgar, dialect, abbreviation"] = sum(1 for v in out.values() if v == "learning")
    stages["+ revival carve-out"] = len(out)

    belongs = {norm(w) for w in holdout.get("belongs", [])}
    does_not = {norm(w) for w in holdout.get("does_not", [])}
    chosen = set(out)
    tp = belongs & chosen
    fp = does_not & chosen
    precision = len(tp) / max(1, len(tp) + len(fp))
    recall = len(tp) / max(1, len(belongs))
    print(f"stage B: {len(out):,} words in the learning pool")
    for k, v in stages.items():
        print(f"  {k:<60} {v:>7,}")
    print(f"  holdout: precision {precision:.2f} ({len(tp)} right, {len(fp)} wrongly in), recall {recall:.2f} ({len(belongs - chosen)} missed)")
    if belongs - chosen:
        print("  missed:", ", ".join(sorted(belongs - chosen)))
    if fp:
        print("  wrongly in:", ", ".join(sorted(fp)))
    lo_t, hi_t = LEARNING_POOL_TARGET
    if not lo_t <= len(out) <= hi_t:
        print(f"  WARNING: pool is outside {lo_t:,}..{hi_t:,}; adjust the stage B bounds")
    return out, stages


# ---------------------------------------------------------------- stage D: QA


STOPWORDS = set("""a an the and or but of to in on at for with by from as is are was were be been being it its
this that these those which who whom whose what when where how than then so such not no nor very
something someone somebody anything one ones some any all each other another more most much many
you your yours he she they them their his her him we our us i me my do does did done have has had
having make makes made making can could will would shall should may might must into onto over under
about between among through without within up down out off also only just there here if while
because although though even both either neither like used use using etc eg ie person people thing things
way ways""".split())


def content_words(text: str) -> set[str]:
    out = set()
    for tok in re.findall(r"[a-z]+", text.lower()):
        if len(tok) < 3 or tok in STOPWORDS:
            continue
        # ponytail: crude stemmer, enough to match "persuaded" with "persuade".
        for suf in ("ing", "ies", "ed", "es", "ly", "s"):
            if tok.endswith(suf) and len(tok) - len(suf) >= 3:
                tok = tok[: -len(suf)]
                break
        out.add(tok)
    return out


def contains_headword(text: str, headword: str, inflections: set[str]) -> bool:
    toks = set(re.findall(r"[a-z']+", text.lower()))
    forms = {headword.lower()} | {f.lower() for f in inflections}
    if toks & forms:
        return True
    # Derived forms count too ("adamantly" for "adamant"): stem match on words
    # long enough for that not to be a coincidence.
    stem = headword.lower().rstrip("ey")
    return len(stem) >= 5 and any(t.startswith(stem) for t in toks)


WEBSTER_MARKERS_RE = re.compile(
    r"\b("
    r"inordinate|preferment|whence|betokening|hitherto|thence|wherefore|"
    r"peradventure|anent|hereunto|erstwhile|whilom|verily|prithee|methinks|"
    r"betimes|trow|ere|thither|forsooth|betwixt|yclept|eftsoons|quoth|"
    r"unto|thereof|wherein|whereupon|therein|therewith|wherewith|thereunto|"
    r"doth|hath|thou|thee|thy|thine|shalt|wilt|art|fain|"
    r"pertaining|appertaining|becoming|bespeaking|cognisant|beseeming|"
    r"inasmuch|notwithstanding|aforementioned|herein|hereinafter"
    r")\b",
    re.IGNORECASE,
)


def score_definition_need(src: dict, us_spellings: set[str] = ()) -> float:
    """Score how badly a word's source definition needs rewriting. Higher = worse."""
    senses = src.get("senses") or []
    if not senses:
        return 100.0
    lead_gloss = senses[0].get("gloss", "")
    all_gloss = " ".join(s.get("gloss", "") for s in senses)

    score = 0.0
    markers = WEBSTER_MARKERS_RE.findall(all_gloss)
    score += len(markers) * 5.0
    score += lead_gloss.count(";") * 3.0
    score += (all_gloss.count(";") - lead_gloss.count(";")) * 1.0

    lead_words = len(lead_gloss.split())
    if lead_words > 25:
        score += min(20.0, (lead_words - 25) * 0.8)

    if us_spellings:
        words_norm = {norm(w) for w in re.findall(r"[a-zA-Z]+", all_gloss)}
        us_found = words_norm & us_spellings
        score += len(us_found) * 4.0

    hw = src.get("headword", "")
    infls = set(src.get("inflections") or [])
    if hw and contains_headword(lead_gloss, hw, infls):
        score += 8.0
    elif hw and contains_headword(all_gloss, hw, infls):
        score += 4.0

    if re.match(r"^(the\s+)?(act|state|quality|condition|fact)\s+of\b", lead_gloss, re.IGNORECASE):
        score += 3.0

    return round(score, 2)


def qa_check(rec: dict, src: dict, lookup_norms: set[str], us_spellings: set[str]) -> tuple[list[str], float]:
    """Stage D gates. Returns (failure reasons, source overlap)."""
    reasons: list[str] = []
    if rec.get("note"):
        return ["insufficient source"], 0.0
    short, full, example = rec.get("definition_short") or "", rec.get("definition_full") or "", rec.get("example") or ""
    if not short or not full or not example:
        return ["missing fields"], 0.0
    if len(short.split()) > 14:
        reasons.append("definition_short over 14 words")
    if contains_headword(short, src["headword"], set(src["inflections"])):
        reasons.append("definition_short contains the headword")
    if not contains_headword(example, src["headword"], set(src["inflections"])):
        reasons.append("example lacks the headword")
    if not 8 <= len(example.split()) <= 18:
        reasons.append("example not 8-18 words")
    if "—" in short or ";" in short:
        reasons.append("em dash or semicolon in definition_short")
    if "—" in full or "—" in example:
        reasons.append("em dash")
    all_text = " ".join([short, full, example] + list(rec.get("synonyms") or []))
    us = sorted(set(re.findall(r"[a-z]+", all_text.lower())) & us_spellings)
    if us:
        reasons.append("US spelling: " + ", ".join(us))
    bad_topics = [t for t in rec.get("topics") or [] if t not in TOPICS]
    if bad_topics:
        reasons.append("unknown topic: " + ", ".join(bad_topics))
    if rec.get("register") not in REGISTERS:
        reasons.append(f"unknown register: {rec.get('register')}")
    bad_syn = [s for s in rec.get("synonyms") or [] if norm(s) not in lookup_norms or norm(s) == src["headword_norm"]]
    if bad_syn:
        reasons.append("synonym not a headword: " + ", ".join(bad_syn))
    source_text = " ".join([s["gloss"] for s in src["senses"]] + [src.get("wordnet_gloss") or ""]
                           + list(src.get("wordnet_synonyms") or []) + list(src.get("examples") or []))
    dw, sw = content_words(short + " " + full), content_words(source_text)
    overlap = len(dw & sw) / len(dw) if dw else 0.0
    if overlap < 0.15:
        reasons.append("low overlap with source")
    return reasons, overlap


# ---------------------------------------------------------------- stage E: collections


def has_topic(w: dict, *topics: str) -> bool:
    return bool(set(w.get("llm_topics") or ()) & set(topics))


def topic_collections() -> list[dict]:
    """Each collection makes a promise a specific word can fulfil. `pick` is the
    membership rule over a learning-set primary row; `rank` orders candidates
    when there are more than COLLECTION_MAX (default: prevalence nearest the
    middle of the learning band)."""
    mid = lambda w: abs((w["prevalence"] or 0) - COLLECTION_MID_PREVALENCE)
    return [
        dict(slug="better_than_very", title='Better Than "Very"', description="Words that carry their own intensity.",
             icon="flame", pick=lambda w: has_topic(w, "intensity"), rank=mid),
        dict(slug="feelings_without_names", title="Feelings Without Names",
             description="Precise words for states you know but cannot name.", icon="heart",
             pick=lambda w: has_topic(w, "feelings") and (w["concreteness"] is None or w["concreteness"] < 3.0), rank=mid),
        dict(slug="describing_people", title="Describing People",
             description="For the person you can picture but cannot pin down.", icon="people",
             pick=lambda w: has_topic(w, "describing_people"), rank=mid),
        dict(slug="politely_damning", title="Politely Damning", description="Criticism that stays civil.", icon="quote",
             pick=lambda w: has_topic(w, "argument", "describing_people")
             and (w["llm_register"] == "formal" or has_topic(w, "formal_register"))
             and w["valence"] is not None and w["valence"] < 4.0, rank=lambda w: w["valence"]),
        dict(slug="words_for_arguments", title="Words for Arguments", description="Making a case, and taking one apart.",
             icon="scale", pick=lambda w: has_topic(w, "argument", "thinking_and_knowing"), rank=mid),
        dict(slug="read_but_never_said", title="Read but Never Said", description="Common in print, rare out loud.",
             icon="book", pick=lambda w: w["zipf_written"] is not None and (w["zipf_written"] - (w["zipf_spoken"] or 0)) >= 0.5,
             rank=lambda w: -(w["zipf_written"] - (w["zipf_spoken"] or 0))),
        dict(slug="borrowed_and_kept", title="Borrowed and Kept", description="English took these and never gave them back.",
             icon="globe", pick=lambda w: has_topic(w, "borrowed_word"), rank=mid),
        dict(slug="weather_and_light", title="Weather and Light", description="For the sky, and how it changes.",
             icon="sun", pick=lambda w: has_topic(w, "weather_and_light"), rank=mid),
        dict(slug="words_at_work", title="Words at Work", description="Precise, and not jargon.", icon="briefcase",
             pick=lambda w: has_topic(w, "work", "money") and w["llm_register"] != "technical", rank=mid),
        dict(slug="small_but_sharp", title="Small but Sharp", description="Five letters or fewer, more useful than they look.",
             icon="spark", pick=lambda w: len(w["headword"]) <= 5 and (w["prevalence"] or 1) < 0.85, rank=mid),
        dict(slug="news_vocabulary", title="The News Vocabulary", description="The words the headlines assume you know.",
             icon="news", pick=lambda w: has_topic(w, "society_and_news"), rank=mid),
        dict(slug="old_and_worth_reviving", title="Old and Worth Reviving", description="Out of fashion, not out of use.",
             icon="clock", pick=lambda w: w["learning_kind"] == "revival", rank=lambda w: -(w["prevalence"] or 0)),
    ]


def build_collections(learning_rows: list[dict]) -> tuple[list[dict], dict[str, list[tuple[dict, str]]]]:
    defs, members = [], {}
    for order, b in enumerate(BANDS):
        title, desc = BAND_TITLES[b]
        rows = sorted((w for w in learning_rows if w["band"] == b), key=lambda w: -(w["prevalence"] or 0))
        defs.append(dict(slug=b, title=title, description=desc, kind="band", band=b, icon=None, sort_order=order))
        members[b] = [(w, "band") for w in rows]
    for order, c in enumerate(topic_collections()):
        rows = [w for w in learning_rows if c["pick"](w)]
        rows.sort(key=c["rank"])
        rows = rows[:COLLECTION_MAX]
        if len(rows) < COLLECTION_MIN:
            print(f"  WARNING: {c['slug']} has {len(rows)} members (< {COLLECTION_MIN}); not shipped")
            continue
        defs.append(dict(slug=c["slug"], title=c["title"], description=c["description"], kind="topic", band=None,
                         icon=c["icon"], sort_order=100 + order))
        members[c["slug"]] = [(w, "topic") for w in rows]
    return defs, members


# ---------------------------------------------------------------- idioms


def build_idioms(candidates: list[dict], rank: dict[str, int], idi: dict, max_size: int) -> list[dict]:
    include = {norm(p): p for p in (idi.get("include") or []) + (idi.get("odd_origins") or [])}
    exclude = {norm(p) for p in idi.get("exclude") or []}
    scored = []
    seen = set()
    etym_of: dict[str, str] = {}
    for e in candidates:
        if e.get("etymology"):
            etym_of.setdefault(norm(britishise(e["word"])), e["etymology"])
    for e in candidates:
        phrase = britishise(e["word"].strip())
        pn = norm(phrase)
        if pn in seen or pn in exclude:
            continue
        if not re.fullmatch(r"[a-zA-Z][a-zA-Z' \-]*", phrase) or not 2 <= len(pn.split()) <= 8:
            continue
        sense = next((s for s in e["senses"] if "idiomatic" in s["tags"] and keep_sense(s) and not is_old(s)), None)
        if sense is None:
            continue
        tags = set(sense["tags"])
        forced = pn in include
        if not forced and tags & {"vulgar", "offensive", "slur", "derogatory"}:
            continue
        content = [w for w in pn.split() if w not in {"the", "a", "an", "of", "to", "in", "on", "at", "for", "and", "or", "one's", "ones", "someone", "someones", "somebody", "something", "it", "up", "out", "with", "off", "into", "be", "have", "get"}]
        ranks = [rank.get(w) for w in content]
        if not forced and (not content or any(r is None or r > 40_000 for r in ranks)):
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
        origin = etym_of.get(pn, "")
        if origin.startswith("See ") or origin.endswith(":") or len(origin) < 30:
            origin = ""
        seen.add(pn)
        scored.append({
            "idiom_key": f"{pn}|idiom|1",
            "phrase": phrase,
            "phrase_norm": pn,
            "meaning": short_definition(clean_gloss(sense["glosses"][-1]), 40),
            "example": examples[0] if examples else None,
            "register": register,
            "origin": origin or None,
            "_score": (0 if forced else 1, worst, len(pn)),
        })
    scored.sort(key=lambda d: d["_score"])
    missing = [p for k, p in include.items() if k not in seen]
    if missing:
        print(f"  idioms: {len(missing)} forced idioms not found in Wiktionary: {missing}")
    return scored[:max_size]


def idiom_collections(idioms: list[dict], idi: dict) -> tuple[list[dict], dict[str, list]]:
    by_norm = {i["phrase_norm"]: i for i in idioms}
    everyday = sorted((i for i in idioms if i["example"]), key=lambda i: i["_score"])[: int(idi.get("everyday") or 150)]
    odd, no_origin = [], []
    for p in idi.get("odd_origins") or []:
        i = by_norm.get(norm(p))
        if i is None:
            continue
        (odd if i["origin"] else no_origin).append(i)
    if no_origin:
        print(f"  idioms: {len(no_origin)} odd_origins entries have no usable etymology: {[i['phrase'] for i in no_origin]}")
    defs = [
        dict(slug="idioms_everyday", title="Idioms: Everyday", description="The ones people actually say.",
             kind="idiom", band=None, icon="quote", sort_order=900),
        dict(slug="idioms_odd_origins", title="Idioms: Odd Origins", description="Where the strange ones came from.",
             kind="idiom", band=None, icon="compass", sort_order=901),
    ]
    members = {"idioms_everyday": [(i, "idiom") for i in everyday], "idioms_odd_origins": [(i, "idiom") for i in odd]}
    for d in list(defs):
        if len(members[d["slug"]]) < COLLECTION_MIN:
            print(f"  WARNING: {d['slug']} has {len(members[d['slug']])} members (< {COLLECTION_MIN}); not shipped")
            defs.remove(d)
            del members[d["slug"]]
    return defs, members


# ---------------------------------------------------------------- emit


def emit(db_path: Path, words, examples, synonyms, aliases, idioms, coll_defs, coll_members, word_tags, pairs, meta):
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.executescript(SCHEMA.read_text(encoding="utf-8"))
    con.executemany("INSERT INTO meta(key, value) VALUES (?, ?)", meta.items())
    con.executemany(
        "INSERT INTO words(id, word_key, headword, headword_norm, pos, sense_index, definition_short, definition_full, ipa,"
        " freq_rank, band, in_learning_set, prevalence, aoa, zipf_spoken, zipf_written, concreteness, definition_source, generated_at)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [(w["id"], w["word_key"], w["headword"], w["headword_norm"], w["pos"], w["sense_index"],
          "" if w["definition_short"] == w["definition_full"] else w["definition_short"],
          w["definition_full"], w["ipa"], w["freq_rank"], w["band"], w["in_learning_set"],
          # The norms are per headword; storing them on sense 1 only saves 8 MB of repeats.
          *((w["prevalence"], w["aoa"], w["zipf_spoken"], w["zipf_written"], w["concreteness"])
            if w["sense_index"] == 1 or w["in_learning_set"] else (None,) * 5),
          w["definition_source"], w["generated_at"]) for w in words],
    )
    con.executemany("INSERT INTO examples(word_key, text) VALUES (?, ?)", examples)
    con.executemany("INSERT INTO synonyms(word_key, synonym) VALUES (?, ?)", synonyms)
    con.executemany("INSERT OR IGNORE INTO aliases(alias_norm, word_key, kind) VALUES (?, ?, ?)", aliases)
    con.executemany(
        "INSERT INTO idioms(idiom_key, phrase, phrase_norm, meaning, example, register, origin) VALUES (?,?,?,?,?,?,?)",
        [(i["idiom_key"], i["phrase"], i["phrase_norm"], i["meaning"], i["example"], i["register"], i["origin"]) for i in idioms],
    )
    for cid, d in enumerate(coll_defs, start=1):
        con.execute(
            "INSERT INTO collections(id, slug, title, description, kind, band, icon, sort_order) VALUES (?,?,?,?,?,?,?,?)",
            (cid, d["slug"], d["title"], d["description"], d["kind"], d["band"], d["icon"], d["sort_order"]),
        )
        con.executemany(
            "INSERT OR IGNORE INTO collection_words(collection_id, word_key, position, source) VALUES (?,?,?,?)",
            [(cid, w.get("word_key") or w["idiom_key"], pos, src) for pos, (w, src) in enumerate(coll_members.get(d["slug"], []))],
        )
    con.executemany("INSERT INTO pairs(word_a, word_b, note) VALUES (?,?,?)", pairs)
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
    raw = HERE / "raw"
    ap.add_argument("--kaikki", type=Path, default=raw / "kaikki.org-dictionary-English.jsonl.gz")
    ap.add_argument("--subtlex", type=Path, default=raw / "SUBTLEX-UK_all.xlsx")
    ap.add_argument("--bnc", type=Path, default=raw / "bnc-written.num.gz")
    ap.add_argument("--wordnet", type=Path, default=raw / "english-wordnet-2024.xml.gz")
    ap.add_argument("--prevalence", type=Path, default=raw / "WordprevalencesSupplementaryfilefirstsubmission.xlsx")
    ap.add_argument("--aoa", type=Path, default=raw / "AoA_ratings_Kuperman_et_al_BRM.xlsx")
    ap.add_argument("--concreteness", type=Path, default=raw / "Concreteness_ratings_Brysbaert_et_al_BRM.txt")
    ap.add_argument("--valence", type=Path, default=raw / "Ratings_Warriner_et_al.csv")
    ap.add_argument("--work", type=Path, default=HERE / "work")
    ap.add_argument("--out-dir", type=Path, default=HERE.parent.parent / "assets" / "db")
    ap.add_argument("--version", default=dt.date.today().strftime("%Y.%m.%d"))
    ap.add_argument("--sample", type=int, default=0, help="keep only N lookup-only headwords (plus the learning set)")
    ap.add_argument("--idiom-cap", type=int, default=None, help="override curation max_size for idioms")
    ap.add_argument("--rescan", action="store_true", help="ignore the stage 1 cache")
    ap.add_argument("--llm", action="store_true", help="run stage C for learning words with no passing rewrite yet")
    ap.add_argument("--llm-model", default=None, help="model for stage C (default: claude-haiku-4-5 for anthropic, gemini-3.5-flash-lite for gemini)")
    ap.add_argument("--llm-limit", type=int, default=0, help="only send this many words to the LLM (0 = all)")
    ap.add_argument("--provider", choices=["anthropic", "gemini"], default="anthropic", help="LLM provider for stage C")
    ap.add_argument("--rpm", type=int, default=None, help="max requests per minute (rate limiting for Gemini)")
    ap.add_argument("--rpd", type=int, default=None, help="max requests per day (daily quota for Gemini)")
    ap.add_argument("--wiktionary-fallback", action="store_true",
                    help="dev builds only: learning words without a passing rewrite keep their Wiktionary definition")
    args = ap.parse_args(argv)
    if args.llm_model is None:
        args.llm_model = "gemini-3.5-flash-lite" if args.provider == "gemini" else "claude-haiku-4-5"

    cache = stage1(args.kaikki, args.work / "stage1.jsonl.gz", args.rescan)
    subtlex, subtlex_total = load_subtlex(args.subtlex)
    bnc, bnc_total = load_bnc_written(args.bnc)
    wordnet, wn_gloss = load_wordnet(args.wordnet)
    prevalence, aoa = load_prevalence(args.prevalence), load_aoa(args.aoa)
    concreteness, valence = load_concreteness(args.concreteness), load_valence(args.valence)
    cur = load_curation()
    idi = cur["idioms"]

    # ---- stage A: the lookup dictionary
    entries, idiom_candidates, stubs = assemble_words(cache, subtlex)
    forms_of = forms_by_headword(entries)
    norm_words = set(prevalence) | set(aoa) | set(concreteness) | set(wordnet_heads(wordnet))
    ipa_of = {hn: any(entries[(hn, p)].ipa for p in WORD_POS if (hn, p) in entries) for hn in forms_of}
    keep = {hn for hn in forms_of if attested(hn, forms_of[hn], ipa_of[hn], subtlex, bnc, norm_words)}
    keep |= {hn for hn in forms_of if any(norm(entries[(hn, p)].us_spelling or "") in norm_words for p in WORD_POS if (hn, p) in entries)}
    # The norms are American-spelled: "candour" is listed as "candor".
    us_of = {hn: next((entries[(hn, p)].us_spelling for p in WORD_POS if (hn, p) in entries and entries[(hn, p)].us_spelling), None)
             for hn in forms_of}

    def norm_value(table: dict[str, float], hn: str) -> float | None:
        v = table.get(hn)
        return v if v is not None or not us_of.get(hn) else table.get(norm(us_of[hn]))
    # Two-letter headwords are abbreviations far more often than words
    # ("ac", "pm"); keep only the ones common enough to be real ("go", "up").
    keep = {hn for hn in keep if len(hn) >= 3 or subtlex.get(hn, 0) > 5_000}
    entries = {k: v for k, v in entries.items() if k[0] in keep}
    forms_of = {hn: f for hn, f in forms_of.items() if hn in keep}
    rank = rank_headwords(forms_of, subtlex, bnc)
    print(f"stage A: {len(keep):,} attested headwords, {len(entries):,} (headword, pos) entries")

    # Flatten to sense rows. Primary sense per headword = first pos in Wiktionary
    # order, sense 1, unless that sense is technical and a plainer one exists.
    words, examples, synonyms, aliases, word_tags = [], [], [], [], []
    primary: dict[str, dict] = {}
    ent_of: dict[str, Entry] = {}
    next_id = 1
    for (hn, pos), ent in sorted(entries.items(), key=lambda kv: kv[1].order):
        r = rank[hn]
        forms = forms_of[hn]
        needles = [re.compile(r"\b" + re.escape(f) + r"\b", re.IGNORECASE) for f in sorted(forms, key=len, reverse=True)]
        wn_syn = sorted(wordnet.get((ent.headword.lower(), pos), ()), key=lambda s: rank.get(norm(s), 10**9))
        p = norm_value(prevalence, hn)
        for idx, s in enumerate(ent.senses[:MAX_SENSES_PER_POS], start=1):
            key = f"{hn}|{pos}|{idx}"
            full = sense_label(s["tags"]) + clean_gloss(s["glosses"][-1])
            row = {
                "id": next_id, "word_key": key, "headword": ent.headword, "headword_norm": hn, "pos": pos,
                "sense_index": idx, "definition_short": short_definition(full), "definition_full": full,
                "ipa": ent.ipa, "freq_rank": r, "band": band_of(p, r), "in_learning_set": 0,
                "prevalence": p, "aoa": norm_value(aoa, hn), "concreteness": norm_value(concreteness, hn),
                "valence": norm_value(valence, hn),
                "zipf_spoken": zipf(sum(subtlex.get(f, 0) for f in forms), subtlex_total),
                "zipf_written": zipf(sum(bnc.get(f, 0) for f in forms), bnc_total),
                "definition_source": "wiktionary", "generated_at": None,
                "tags": s["tags"], "topics": s["topics"], "llm_topics": [], "llm_register": None, "learning_kind": None,
            }
            next_id += 1
            words.append(row)
            if hn not in primary or (
                set(primary[hn]["topics"]) & TECHNICAL_TOPICS and not set(s["topics"]) & TECHNICAL_TOPICS and not is_old(s)
            ):
                primary[hn], ent_of[hn] = row, ent
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
            word_tags.extend((key, f"tag:{t}") for t in s["tags"] if t in LABEL_TAGS)
            word_tags.extend((key, f"topic:{t}") for t in s["topics"])
            if idx == 1:
                if ent.us_spelling:
                    aliases.append((norm(ent.us_spelling), key, "us_spelling"))
                for f in ent.inflections:
                    if norm(f) != hn:
                        aliases.append((norm(f), key, "inflection"))
                for f in ent.variants:
                    if norm(f) != hn:
                        aliases.append((norm(f), key, "variant"))
    # Inflection stubs Wiktionary keeps as their own pages ("ran" -> "run").
    for form_norm, lemma_norm in stubs:
        if lemma_norm in primary and form_norm not in primary:
            aliases.append((form_norm, primary[lemma_norm]["word_key"], "inflection"))
    alias_norms = {a for a, _, _ in aliases}
    lookup_norms = set(primary) | alias_norms

    # ---- coverage test: a word missing from lookup is a bug of the highest severity
    missing = [w for w in cur["coverage"] if norm(w) not in lookup_norms]
    print(f"coverage: {len(cur['coverage']) - len(missing)}/{len(cur['coverage'])} resolve")
    if missing:
        print("  MISSING:", ", ".join(missing))
        return 1

    # ---- stage B: the learning set
    learning, stage_sizes = select_learning_set(primary, ent_of, alias_norms, cur["holdout"])
    for hn, kind in learning.items():
        primary[hn]["learning_kind"] = kind

    # ---- stage C: the LLM pass, cached in work/llm_cache.jsonl; stage D gates it
    us_spellings = {a for a, _, k in aliases if k == "us_spelling"} - set(primary)
    inputs = {}
    for hn in learning:
        w, ent = primary[hn], ent_of[hn]
        inputs[w["word_key"]] = {
            "word_key": w["word_key"], "headword": w["headword"], "headword_norm": hn, "pos": w["pos"],
            "senses": [{"gloss": clean_gloss(s["glosses"][-1]), "tags": [t for t in s["tags"] if t in LABEL_TAGS]}
                       for s in ent.senses[:6]],
            "wordnet_gloss": wn_gloss.get((ent.headword.lower(), w["pos"])) or None,
            "wordnet_synonyms": sorted(wordnet.get((ent.headword.lower(), w["pos"]), ()))[:8],
            "examples": None,  # filled below from the flattened examples
            "inflections": sorted(ent.inflections),
            "prevalence": round(w["prevalence"], 3), "zipf": round(w["zipf_spoken"] or 0, 2),
            "register_tags": [t for t in w["tags"] if t in LABEL_TAGS],
        }
    ex_by_key = collections.defaultdict(list)
    for k, t in examples:
        ex_by_key[k].append(t)
    for k, src in inputs.items():
        src["examples"] = ex_by_key[k][:3]
    (args.work / "learning_set.jsonl").write_text("".join(json.dumps(v, ensure_ascii=False) + "\n" for v in inputs.values()), encoding="utf-8")

    cache_path = args.work / "llm_cache.jsonl"
    attempts: dict[str, list[dict]] = collections.defaultdict(list)
    if cache_path.exists():
        for line in cache_path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                rec = json.loads(line)
                attempts[rec["word_key"]].append(rec)

    def verdicts():
        out = {}
        for key, src in inputs.items():
            tried = [a for a in attempts.get(key, []) if a["word_key"] == key]
            best = None
            for a in tried:
                reasons, overlap = qa_check(a["output"], src, lookup_norms, us_spellings)
                a["_reasons"], a["_overlap"] = reasons, overlap
                if not reasons:
                    best = a
            out[key] = (best, tried)
        return out

    qa = verdicts()
    trial_keys: list[str] = []
    if args.llm:
        import llm_rewrite  # lazy: the anthropic/gemini SDK is only needed with --llm
        for round_no in (1, 2):
            pending = [key for key, (best, tried) in qa.items()
                       if best is None and len(tried) == round_no - 1 and not any(a["output"].get("note") for a in tried)]
            # Step 1b: Prioritise worst entries first
            pending.sort(key=lambda k: (score_definition_need(inputs[k], us_spellings), k), reverse=True)
            if args.llm_limit:
                pending = pending[: args.llm_limit]
            if round_no == 1 and args.llm_limit:
                trial_keys = list(pending)
            if not pending:
                break
            print(f"stage C: round {round_no}, {len(pending):,} words -> {args.llm_model} ({args.provider})")
            batch_inputs = []
            for key in pending:
                src = dict(inputs[key])
                if qa[key][1]:
                    last = qa[key][1][-1]
                    src["previous_attempt"] = last["output"]
                    src["rejected_because"] = last["_reasons"]
                batch_inputs.append(src)
            try:
                for rec in llm_rewrite.generate(batch_inputs, args.llm_model, cache_path,
                                                provider=args.provider, rpm=args.rpm, rpd=args.rpd):
                    attempts[rec["word_key"]].append(rec)
            except (llm_rewrite.DailyQuotaExhaustedError, llm_rewrite.Sustained429Error) as e:
                qa = verdicts()
                remaining = sum(1 for k in inputs if qa[k][0] is None)
                print(f"\n[QUOTA STOPPED] {e}")
                print(f"Clean exit: {remaining:,} words remain unrewritten in learning set.")
                print(f"Cache saved to {cache_path}. Re-run once quota resets.")
                return 0
            qa = verdicts()

    # ---- apply: passing rewrites become the learning card; failures are dropped
    fail_reasons = collections.Counter()
    dropped, passed, fallback = [], [], []
    for hn, kind in learning.items():
        w = primary[hn]
        key = w["word_key"]
        best, tried = qa[key]
        if best is not None:
            o = best["output"]
            w.update(definition_short=o["definition_short"], definition_full=o["definition_full"],
                     definition_source="llm_rewrite", generated_at=best["generated_at"], in_learning_set=1,
                     llm_topics=o.get("topics") or [], llm_register=o.get("register"))
            examples = [(k, t) for k, t in examples if k != key or t != o["example"]]
            examples.insert(0, (key, o["example"]))
            synonyms = [(k, s) for k, s in synonyms if k != key] + [(key, s) for s in o.get("synonyms") or []]
            word_tags.extend((key, f"topic:{t}") for t in w["llm_topics"])
            if w["llm_register"]:
                word_tags.append((key, f"register:{w['llm_register']}"))
            passed.append(hn)
        else:
            for a in tried:
                fail_reasons.update(a["_reasons"])
            if args.wiktionary_fallback:
                w["in_learning_set"] = 1
                fallback.append(hn)
            else:
                w["learning_kind"] = None
                dropped.append(hn)
    learning_rows = [primary[hn] for hn in learning if primary[hn]["in_learning_set"]]
    if fallback:
        args.version += "-fallback"   # so a dev build can never pass as the real one
    # Wiktionary topics are kept for re-slicing the learning set only; on the
    # other 250k rows they are most of the bytes and nothing will read them.
    learning_keys = {w["word_key"] for w in learning_rows}
    word_tags = [(k, t) for k, t in word_tags if k in learning_keys or not t.startswith("topic:")]

    # ---- stage E: collections, idioms, pairs
    coll_defs, coll_members = build_collections(learning_rows)
    idiom_cap = args.idiom_cap or int(idi.get("max_size") or 1500)
    idioms = build_idioms(idiom_candidates, rank, idi, idiom_cap)
    i_defs, i_members = idiom_collections(idioms, idi)
    coll_defs += i_defs
    coll_members.update(i_members)
    pairs, bad_pairs = [], []
    key_of_alias = {a: k for a, k, _ in aliases}
    resolve = lambda w: primary[norm(w)]["word_key"] if norm(w) in primary else key_of_alias.get(norm(w))
    for a, b, note in cur["pairs"].get("pairs") or []:
        ka, kb = resolve(a), resolve(b)
        if ka and kb and ka != kb:
            pairs.append((ka, kb, note))
        else:
            bad_pairs.append(f"{a}/{b}")
    if bad_pairs:
        print(f"  pairs: {len(bad_pairs)} pairs with a word missing from lookup: {bad_pairs}")
    coll_defs.append(dict(slug="almost_the_same", title=cur["pairs"]["title"], description=cur["pairs"]["description"],
                          kind="pairs", band=None, icon="split", sort_order=950))

    # ---- sample: the learning set, the coverage words, and N random lookup words
    if args.sample:
        rnd = random.Random(1)
        keep_hn = set(learning) | {norm(w) for w in cur["coverage"]} | {k.split("|")[0] for a, b, _ in pairs for k in (a, b)}
        rest = sorted(set(primary) - keep_hn)
        keep_hn |= set(rnd.sample(rest, min(args.sample, len(rest))))
        words = [w for w in words if w["headword_norm"] in keep_hn]
        kept_keys = {w["word_key"] for w in words}
        examples = [(k, t) for k, t in examples if k in kept_keys]
        synonyms = [(k, s) for k, s in synonyms if k in kept_keys]
        aliases = [(a, k, kind) for a, k, kind in aliases if k in kept_keys]
        word_tags = [(k, t) for k, t in word_tags if k in kept_keys]
        idioms = idioms[: min(len(idioms), 300)]
        args.version = f"{args.version}-sample"
        print(f"sample: {len(keep_hn):,} headwords, {len(words):,} rows")

    meta = {
        "dict_version": args.version,
        "built_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "source_attribution": (
            "Definitions, pronunciations, examples and idioms from Wiktionary via Kaikki.org (wiktextract), CC BY-SA 4.0; "
            "learning-set definitions rewritten from that material. "
            "Word prevalence from Brysbaert, Mandera, McCormick & Keuleers (2019); age of acquisition from Kuperman, "
            "Stadthagen-Gonzalez & Brysbaert (2012); concreteness from Brysbaert, Warriner & Kuperman (2014); "
            "valence from Warriner, Kuperman & Brysbaert (2013). Frequencies from SUBTLEX-UK (van Heuven, Mandera, "
            "Keuleers & Brysbaert, 2014) and the British National Corpus. Synonyms from Open English WordNet 2024, CC BY 4.0."
        ),
        "entry_count": str(len(words)),
        "headword_count": str(len({w["headword_norm"] for w in words})),
        "learning_count": str(sum(1 for w in words if w["in_learning_set"])),
        "idiom_count": str(len(idioms)),
        "sample": "1" if args.sample else "0",
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.work.mkdir(parents=True, exist_ok=True)
    db_path = args.work / "dictionary.db"
    emit(db_path, words, examples, synonyms, aliases, idioms, coll_defs, coll_members, word_tags, pairs, meta)
    gz_path = args.out_dir / "dictionary.db.gz"
    with open(db_path, "rb") as fin, gzip.open(gz_path, "wb", compresslevel=9) as fout:
        while chunk := fin.read(1 << 20):
            fout.write(chunk)
    (args.out_dir / "dictionary.version").write_text(args.version + "\n", encoding="utf-8")

    # ---- build report
    ex_by_key = collections.defaultdict(list)
    for k, t in examples:
        ex_by_key[k].append(t)
    syn_by_key = collections.defaultdict(list)
    for k, s in synonyms:
        syn_by_key[k].append(s)
    heads = {w["headword_norm"] for w in words}
    print("\n=== build report ===")
    print(f"dict_version      {args.version}")
    print("1. lookup")
    print(f"  headwords       {len(heads):,}")
    print(f"  sense rows      {len(words):,}")
    print(f"  with IPA        {sum(1 for w in words if w['ipa']) / max(1, len(words)):.0%} of rows")
    print(f"  with example    {sum(1 for w in words if ex_by_key[w['word_key']]) / max(1, len(words)):.0%} of rows")
    print(f"  aliases         {len(aliases):,}   idioms {len(idioms):,}   pairs {len(pairs)}")
    print(f"  uncompressed    {db_path.stat().st_size / 1e6:.1f} MB   compressed {gz_path.stat().st_size / 1e6:.1f} MB -> {gz_path}")
    print(f"2. coverage       {len(cur['coverage'])}/{len(cur['coverage'])} resolve")
    print("3. learning set pool by stage (see stage B above)")
    print(f"5. LLM pass       attempted {sum(1 for k in inputs if qa[k][1]):,}   passed {len(passed):,}   dropped {len(dropped):,}"
          + (f"   wiktionary fallback {len(fallback):,}" if fallback else ""))
    for reason, n in fail_reasons.most_common():
        print(f"     {n:>5}  {reason}")
    lowest = sorted((a for k in inputs for a in qa[k][1] if not a["_reasons"]), key=lambda a: a["_overlap"])[:30]
    if lowest:
        print("   30 lowest-overlap passes (eyeball these):")
        for a in lowest:
            print(f"     {a['_overlap']:.2f}  {a['word_key']:<28} {a['output']['definition_short']}")
    print("6. collections (size, prevalence p10/p50/p90)")
    for d in coll_defs:
        m = coll_members.get(d["slug"], [])
        ps = sorted(w["prevalence"] for w, _ in m if w.get("prevalence") is not None)
        dist = f"{ps[len(ps) // 10]:.2f} / {ps[len(ps) // 2]:.2f} / {ps[len(ps) * 9 // 10]:.2f}" if ps else "-"
        print(f"  {d['slug']:<24} {len(m):>5}   {dist}")
    band_counts = collections.Counter(w["band"] for w in learning_rows)
    print("   learning set by band: " + "  ".join(f"{b}={band_counts.get(b, 0)}" for b in BANDS))
    print("7. 40 cards as the Mull tab would show them")
    rnd = random.Random(7)
    for w in rnd.sample(learning_rows, min(40, len(learning_rows))):
        ex = ex_by_key[w["word_key"]]
        print(f"\n  {w['headword']}  {w['ipa'] or ''}  ({w['pos']}, {w['band']}, known by {w['prevalence']:.0%})")
        print(f"    {w['definition_short']}")
        if ex:
            print(f"    “{ex[0]}”")
        if syn_by_key[w["word_key"]]:
            print("    " + " · ".join(syn_by_key[w["word_key"]][:4]))
        if w["llm_topics"]:
            print(f"    [{', '.join(w['llm_topics'])}]  {w['llm_register']}")

    if args.llm_limit and trial_keys:
        print(f"\n==================================================================")
        print(f"--- TRIAL RUN FINISHED CARDS ({len(trial_keys)} words attempted) ---")
        print(f"==================================================================")
        trial_pass = 0
        trial_fail_reasons = collections.Counter()
        for idx, key in enumerate(trial_keys, 1):
            src = inputs[key]
            best, tried = qa.get(key, (None, []))
            hn = src["headword_norm"]
            hw = src["headword"]
            pos = src["pos"]
            w_info = primary.get(hn, {})
            ipa = w_info.get("ipa") or ""
            band = w_info.get("band") or "unknown"
            prev = src.get("prevalence")
            prev_str = f", known by {prev:.0%}" if prev is not None else ""

            if best is not None:
                trial_pass += 1
                o = best["output"]
                print(f"\n[{idx}/{len(trial_keys)}] {hw}  {ipa}  ({pos}, {band}{prev_str})  [QA: PASS]")
                print(f"    {o.get('definition_short') or ''}")
                if o.get("example"):
                    print(f"    “{o['example']}”")
                if o.get("synonyms"):
                    print("    " + " · ".join(o["synonyms"][:4]))
                if o.get("topics"):
                    print(f"    [{', '.join(o['topics'])}]  {o.get('register')}")
            else:
                last_rec = tried[-1] if tried else {}
                last_out = last_rec.get("output", {})
                reasons = last_rec.get("_reasons", ["no attempt"])
                trial_fail_reasons.update(reasons)
                print(f"\n[{idx}/{len(trial_keys)}] {hw}  {ipa}  ({pos}, {band}{prev_str})  [QA: FAIL - {', '.join(reasons)}]")
                print(f"    short: {last_out.get('definition_short') or '(none)'}")
                print(f"    example: “{last_out.get('example') or '(none)'}”")

        print(f"\n------------------------------------------------------------------")
        print(f"TRIAL RUN QA SUMMARY:")
        print(f"  Attempted: {len(trial_keys)}")
        print(f"  Passed:    {trial_pass}/{len(trial_keys)} ({trial_pass / len(trial_keys):.1%})")
        print(f"  Failed:    {len(trial_keys) - trial_pass}/{len(trial_keys)}")
        if trial_fail_reasons:
            print("  Failures by reason:")
            for r, c in trial_fail_reasons.most_common():
                print(f"    {c:>3}  {r}")
        print(f"------------------------------------------------------------------\n")

    return 0


def wordnet_heads(wordnet) -> set[str]:
    return {w for w, _ in wordnet}


if __name__ == "__main__":
    sys.exit(main())
