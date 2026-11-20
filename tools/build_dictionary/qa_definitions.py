"""Deterministic quality checks for dictionary definitions (Rules R2, R3, R4, R6).

Enforces:
  R2: Plain words (every content word in short def within top N and more common than headword)
  R3: Not circular (no headword, inflections, family words, or circular formulaic patterns)
  R4: Short (short def <= 14 words, full def <= 25 words)
  R6: Clean synonyms (no synonym is headword, inflection, or family word)
"""
from __future__ import annotations

import argparse
import collections
import gzip
import json
import math
import os
import random
import re
import sqlite3
import time
from pathlib import Path
from xml.etree import ElementTree as ET

# ---------------------------------------------------------------- Configuration

DEFAULT_TOP_N_FREQUENCY = 3000
DEFAULT_SHORT_DEF_MAX_WORDS = 14
DEFAULT_FULL_DEF_MAX_WORDS = 25

# Small configurable allowlist for domain/technical terms with no simpler plain alternative
DEFAULT_ALLOWLIST: set[str] = {
    # Grammatical / lexical terms
    "plural", "singular", "verb", "noun", "adjective", "adverb", "preposition",
    # Specific common concepts often irreducible in simple definitions
    "especially", "particularly", "typically", "specifically", "relating",
    # Core defining concepts with no simpler plain alternative (from user direction & defining vocabulary)
    "childish", "sulky", "temper", "tempered", "playful", "charming", "rude", "humble",
    "awkward", "shy", "bold", "chemical", "hatred", "miserable", "racial", "formal", "differ", "differs",
    "cannot", "liquid", "powder", "strict", "anger", "harsh", "sickness", "illness", "yarn", "hollow", "supreme",
}

# Function words: Closed-class words, auxiliary verbs, pronouns, prepositions, conjunctions, numbers
FUNCTION_WORDS: set[str] = set("""
a an the
i me my mine myself we us our ours ourselves you your yours yourself yourselves
he him his himself she her hers herself it its itself they them their theirs themselves
what which who whom whose whatever whichever whoever whomever
this that these those
one ones oneself someone somebody something anyone anybody anything everyone everybody everything no-one nobody nothing
each either neither all both few many several some any none
about above across after against along amid amidst among amongst around as at
before behind below beneath beside besides between beyond but by concerning despite
down during except for from in inside into like near of off on onto out outside over
past per regarding round since through throughout till to toward towards under
underneath until unto up upon via with within without
and but or nor so yet although though because unless while whilst whereas whether if once than lest
be am is are was were been being have has had having do does did done doing
will would shall should can could may might must ought need dare used
not n't no yes very too also only just quite rather somewhat almost even else
then there here now thus hence therefore however otherwise instead again
never always often sometimes usually seldom hardly scarcely
two three four five six seven eight nine ten first second third
""".split())

# Derivational suffix stripping rules for identifying word families
DERIVATIONAL_SUFFIX_RULES = [
    ("lessly", ("", "less")),
    ("fully", ("", "ful")),
    ("ically", ("ical", "ic", "y", "s", "")),
    ("ingly", ("ing", "")),
    ("ously", ("ous", "")),
    ("ishly", ("ish", "")),
    ("ably", ("able", "")),
    ("ibly", ("ible", "")),
    ("ally", ("al", "")),
    ("ity", ("e", "")),
    ("ty", ("",)),
    ("ness", ("", "y")),
    ("ment", ("",)),
    ("ation", ("ate", "e", "")),
    ("ition", ("ite", "e", "")),
    ("sion", ("de", "se", "")),
    ("tion", ("t", "te", "e", "")),
    ("ance", ("ant", "e", "")),
    ("ence", ("ent", "e", "")),
    ("ancy", ("ant", "")),
    ("ency", ("ent", "")),
    ("able", ("e", "")),
    ("ible", ("e", "")),
    ("ical", ("ic", "y", "s", "")),
    ("less", ("",)),
    ("ful", ("",)),
    ("ous", ("", "e")),
    ("ious", ("y", "e", "")),
    ("ish", ("", "e")),
    ("ize", ("", "e")),
    ("ise", ("", "e")),
    ("ent", ("ence", "ency", "")),
    ("ant", ("ance", "ancy", "")),
    ("ing", ("", "e")),
    ("ed", ("", "e")),
    ("ly", ("",)),
    ("al", ("", "e")),
    ("ic", ("", "y", "e")),
    ("sy", ("",)),
]

# Patterns for circular definitions
CIRCULAR_PATTERNS = [
    # "in a(n) ... manner/way"
    (re.compile(r"\bin (?:an?|the) ([a-z]+) (?:manner|way)\b", re.IGNORECASE), "manner/way pattern"),
    # "(the) quality/state/condition of being ..."
    (re.compile(r"\b(?:the\s+)?(?:quality|state|condition)\s+of\s+being\s+([a-z]+)\b", re.IGNORECASE), "quality/state pattern"),
    # "(the) act of ...ing"
    (re.compile(r"\b(?:the\s+)?act\s+of\s+([a-z]+ing)\b", re.IGNORECASE), "act of pattern"),
    # "relating/pertaining to ..."
    (re.compile(r"\b(?:relating|pertaining)\s+to\s+(?:the\s+|an?\s+)?([a-z]+)\b", re.IGNORECASE), "relating to pattern"),
    # "given to ..."
    (re.compile(r"\bgiven\s+to\s+(?:the\s+|an?\s+)?([a-z]+)\b", re.IGNORECASE), "given to pattern"),
]


def tokenize(text: str) -> list[str]:
    """Extract individual words with whole-token boundaries."""
    return [t.lower() for t in re.findall(r"\b[a-zA-Z]+(?:'[a-zA-Z]+)?\b", text)]


def get_roots(word: str) -> set[str]:
    """Return stripped stems/roots using derivational suffix rules.
    Enforces minimum length constraints to avoid false positives (e.g. moth/mother)."""
    word = word.lower()
    roots = {word}
    for suf, reps in DERIVATIONAL_SUFFIX_RULES:
        if word.endswith(suf) and len(word) - len(suf) >= 3:
            base = word[:-len(suf)]
            roots.add(base)
            for rep in reps:
                roots.add(base + rep)
            # Consonant dedoubling: e.g. abett -> abet, runn -> run
            if len(base) >= 4 and base[-1] == base[-2] and base[-1] in "bdfglmnprt":
                roots.add(base[:-1])
                for rep in reps:
                    roots.add(base[:-1] + rep)
    # Secondary pass for plurals/stems like whims -> whim
    extra = set()
    for r in roots:
        if len(r) >= 4 and r.endswith("s") and not r.endswith("ss"):
            extra.add(r[:-1])
    roots.update(extra)
    return {r for r in roots if len(r) >= 3}


def load_wordnet_family(wordnet_path: Path | str) -> dict[str, set[str]]:
    """Parse WordNet 2024 XML to extract derivation and pertainym links."""
    p = Path(wordnet_path)
    if not p.is_file():
        return {}
    
    opener = gzip.open(p, "rt", encoding="utf-8") if p.suffix == ".gz" else open(p, "r", encoding="utf-8")
    with opener as f:
        tree = ET.parse(f)
    
    root = tree.getroot()
    id_to_lemma: dict[str, str] = {}
    for le in root.iter("LexicalEntry"):
        lemma_el = le.find("Lemma")
        if lemma_el is None or "writtenForm" not in lemma_el.attrib:
            continue
        lemma = lemma_el.attrib["writtenForm"].lower()
        for s in le.findall("Sense"):
            sid = s.get("id")
            if sid:
                id_to_lemma[sid] = lemma

    wn_family: dict[str, set[str]] = collections.defaultdict(set)
    for le in root.iter("LexicalEntry"):
        lemma_el = le.find("Lemma")
        if lemma_el is None or "writtenForm" not in lemma_el.attrib:
            continue
        lemma = lemma_el.attrib["writtenForm"].lower()
        for s in le.findall("Sense"):
            for sr in s.findall("SenseRelation"):
                rel = sr.get("relType")
                # Morphological derivations only (excluding semantic cross-POS pertainyms like canine -> dog)
                if rel == "derivation":
                    target = sr.get("target")
                    if target and target in id_to_lemma:
                        tgt_lemma = id_to_lemma[target]
                        if tgt_lemma != lemma:
                            wn_family[lemma].add(tgt_lemma)
                            wn_family[tgt_lemma].add(lemma)
    return wn_family


class QAChecker:
    def __init__(
        self,
        db_path: Path | str,
        wordnet_path: Path | str | None = None,
        top_n_frequency: int = DEFAULT_TOP_N_FREQUENCY,
        short_def_max_words: int = DEFAULT_SHORT_DEF_MAX_WORDS,
        full_def_max_words: int = DEFAULT_FULL_DEF_MAX_WORDS,
        allowlist: set[str] | None = None,
    ):
        self.db_path = Path(db_path)
        self.top_n_frequency = top_n_frequency
        self.short_def_max_words = short_def_max_words
        self.full_def_max_words = full_def_max_words
        self.allowlist = set(allowlist) if allowlist is not None else set(DEFAULT_ALLOWLIST)
        self.allowlist_hits: collections.Counter[str] = collections.Counter()

        # Load WordNet relations if available
        self.wn_family: dict[str, set[str]] = {}
        if wordnet_path and Path(wordnet_path).is_file():
            self.wn_family = load_wordnet_family(wordnet_path)

        # Cache database structures
        self.hw_ranks: dict[str, int] = {}
        self.alias_ranks: dict[str, int] = {}
        self.aliases_by_wk: dict[str, set[str]] = collections.defaultdict(set)
        self.lemmas_by_alias: dict[str, set[str]] = collections.defaultdict(set)
        self.synonyms_by_wk: dict[str, list[str]] = collections.defaultdict(list)
        
        self._load_db_cache()

    def _load_db_cache(self) -> None:
        con = sqlite3.connect(self.db_path)
        cur = con.cursor()

        # 1. Headword ranks
        for r, hn in cur.execute("SELECT freq_rank, headword_norm FROM words"):
            if hn not in self.hw_ranks or r < self.hw_ranks[hn]:
                self.hw_ranks[hn] = r

        # 2. Aliases
        for an, wk, kind in cur.execute("SELECT alias_norm, word_key, kind FROM aliases"):
            self.aliases_by_wk[wk].add(an)
            hn = wk.split("|")[0]
            self.lemmas_by_alias[an].add(hn)
            r = self.hw_ranks.get(hn, 999999)
            if an not in self.alias_ranks or r < self.alias_ranks[an]:
                self.alias_ranks[an] = r

        # 3. Synonyms
        for wk, syn in cur.execute("SELECT word_key, synonym FROM synonyms"):
            self.synonyms_by_wk[wk].append(syn)

        con.close()

    def get_token_rank(self, token: str) -> int:
        """Get best frequency rank for a token from headword ranks or alias ranks."""
        t = token.lower()
        if t.endswith("'s") and len(t) > 2:
            t = t[:-2]
        if t in self.hw_ranks:
            return self.hw_ranks[t]
        if t in self.alias_ranks:
            return self.alias_ranks[t]
        # Suffix stripping fallback for inflections not explicitly in aliases
        for suf in ("s", "es", "ed", "ing", "ly"):
            if t.endswith(suf) and len(t) - len(suf) >= 3:
                base = t[:-len(suf)]
                if base in self.hw_ranks:
                    return self.hw_ranks[base]
                if base in self.alias_ranks:
                    return self.alias_ranks[base]
                # Suffix stripping with silent e (e.g. hop -> hope, car -> care)
                base_e = base + "e"
                if base_e in self.hw_ranks:
                    return self.hw_ranks[base_e]
                if base_e in self.alias_ranks:
                    return self.alias_ranks[base_e]
                # Suffix stripping with consonant dedoubling (e.g. stopp -> stop, runn -> run)
                if len(base) >= 3 and base[-1] == base[-2] and base[-1] in "bdfglmnprt":
                    dedup = base[:-1]
                    if dedup in self.hw_ranks:
                        return self.hw_ranks[dedup]
                    if dedup in self.alias_ranks:
                        return self.alias_ranks[dedup]
        return 999999

    def get_family_words(self, headword: str, word_key: str) -> set[str]:
        """Compute all family words for a headword: inflections, WordNet relations, and stripped roots."""
        hn = headword.lower()
        family = {hn}

        # 1. Inflections and aliases of this word
        family.update(self.aliases_by_wk.get(word_key, set()))

        # 2. If headword itself is an alias of other lemmas
        for lem in self.lemmas_by_alias.get(hn, set()):
            family.add(lem)

        # 3. WordNet derivation and pertainym links
        wn_related = set(self.wn_family.get(hn, set()))
        for r in list(wn_related):
            wn_related.update(self.wn_family.get(r, set()))
        family.update(wn_related)

        # 4. Roots from derivational suffix stripping
        roots = get_roots(hn)
        for r in wn_related:
            roots.update(get_roots(r))
        family.update(roots)

        return family

    def check_r2_plain_words(self, short_def: str, hw_norm: str, hw_rank: int) -> list[str]:
        """R2. Every content word in short definition must be within top N and more common than headword."""
        failures = []
        tokens = tokenize(short_def)
        for tok in tokens:
            if tok in FUNCTION_WORDS:
                continue
            if tok in self.allowlist:
                self.allowlist_hits[tok] += 1
                continue
            
            rank = self.get_token_rank(tok)
            # Check top N
            if rank > self.top_n_frequency:
                failures.append(f"content word '{tok}' (rank {rank}) outside top {self.top_n_frequency}")
            # Check more common than headword
            elif hw_rank > self.top_n_frequency and rank > hw_rank:
                failures.append(f"content word '{tok}' (rank {rank}) is harder than headword (rank {hw_rank})")
        return failures

    def check_r3_circular(
        self,
        short_def: str,
        full_def: str,
        headword: str,
        family: set[str],
        hw_rank: int,
    ) -> list[str]:
        """R3. Not circular: definition must not contain headword, inflections, family words, or circular patterns."""
        failures = []
        hn = headword.lower()

        # Avoid double-checking if short_def was copied from full_def
        texts = [full_def] if short_def == full_def else [short_def, full_def]
        combined = " ".join(texts)
        tokens = set(tokenize(combined))
        hw_roots = get_roots(hn)

        # 1. Whole-token family check
        for tok in sorted(tokens):
            if tok == hn:
                failures.append(f"definition contains the headword '{tok}'")
            elif tok in family:
                failures.append(f"definition contains family word '{tok}'")
            else:
                # Check root intersection for derivations not explicitly linked
                tok_roots = get_roots(tok)
                shared = (hw_roots & tok_roots) - FUNCTION_WORDS
                # Minimum root length >= 4 to prevent 3-letter false coincidences (e.g. pan/panic, cat/cattle)
                shared_valid = {s for s in shared if len(s) >= 4}
                if shared_valid:
                    failures.append(f"definition contains family word '{tok}' (shared root '{next(iter(shared_valid))}')")

        # 2. Formulaic circular patterns
        seen_patterns = set()
        for text in texts:
            if not text:
                continue
            for pat, pat_name in CIRCULAR_PATTERNS:
                for match in pat.finditer(text):
                    target_phrase = match.group(0).strip()
                    target_word = match.group(1).lower()
                    if (target_phrase, target_word) in seen_patterns:
                        continue
                    seen_patterns.add((target_phrase, target_word))

                    target_roots = get_roots(target_word)
                    is_family = (target_word in family) or bool((hw_roots & target_roots) - FUNCTION_WORDS)
                    target_rank = self.get_token_rank(target_word)
                    is_harder = target_rank > hw_rank  # strictly harder (rarer) than the headword being defined

                    if is_family:
                        failures.append(f"circular pattern '{target_phrase}': target '{target_word}' is a family word")
                    elif is_harder:
                        failures.append(f"circular pattern '{target_phrase}': target '{target_word}' (rank {target_rank}) is harder than headword (rank {hw_rank})")

        return failures

    def check_r4_length(self, short_def: str, full_def: str) -> list[str]:
        """R4. Short: definition_short <= short_def_max_words, definition_full <= full_def_max_words."""
        failures = []
        short_words = short_def.split()
        if len(short_words) > self.short_def_max_words:
            failures.append(f"definition_short has {len(short_words)} words (max {self.short_def_max_words})")

        full_words = full_def.split()
        if len(full_words) > self.full_def_max_words:
            failures.append(f"definition_full has {len(full_words)} words (max {self.full_def_max_words})")
        return failures

    def check_r6_synonyms(self, synonyms: list[str], headword: str, family: set[str]) -> list[str]:
        """R6. Clean synonyms: no synonym may be the headword, an inflection, or a family word."""
        failures = []
        hn = headword.lower()
        hw_roots = get_roots(hn)

        for syn in synonyms:
            sn = syn.lower().strip()
            if not sn:
                continue
            if sn == hn:
                failures.append(f"synonym '{syn}' is the headword")
            elif sn in family:
                failures.append(f"synonym '{syn}' is a family word")
            else:
                syn_roots = get_roots(sn)
                shared = {s for s in (hw_roots & syn_roots) if len(s) >= 4}
                if shared:
                    failures.append(f"synonym '{syn}' is a family word (shared root '{next(iter(shared))}')")
        return failures

    def check_row(self, row: tuple) -> list[dict]:
        """Evaluate a single words table row against R2, R3, R4, R6."""
        (
            id_val,
            word_key,
            headword,
            headword_norm,
            pos,
            sense_index,
            def_short_raw,
            def_full_raw,
            freq_rank,
            in_learning_set,
        ) = row

        short_def = def_short_raw if def_short_raw else def_full_raw
        full_def = def_full_raw or ""
        hw_norm = headword_norm or headword.lower()
        rank = freq_rank or 999999

        family = self.get_family_words(headword, word_key)
        synonyms = self.synonyms_by_wk.get(word_key, [])

        flags = []

        # R2: Plain words (evaluated on short definition)
        for r2_fail in self.check_r2_plain_words(short_def, hw_norm, rank):
            flags.append({
                "word_key": word_key,
                "headword": headword,
                "in_learning_set": in_learning_set,
                "rule": "R2",
                "detail": r2_fail,
            })

        # R3: Not circular
        for r3_fail in self.check_r3_circular(short_def, full_def, headword, family, rank):
            flags.append({
                "word_key": word_key,
                "headword": headword,
                "in_learning_set": in_learning_set,
                "rule": "R3",
                "detail": r3_fail,
            })

        # R4: Length
        for r4_fail in self.check_r4_length(short_def, full_def):
            flags.append({
                "word_key": word_key,
                "headword": headword,
                "in_learning_set": in_learning_set,
                "rule": "R4",
                "detail": r4_fail,
            })

        # R6: Synonyms
        for r6_fail in self.check_r6_synonyms(synonyms, headword, family):
            flags.append({
                "word_key": word_key,
                "headword": headword,
                "in_learning_set": in_learning_set,
                "rule": "R6",
                "detail": r6_fail,
            })

        return flags

    def run_all(
        self,
        flags_out_path: Path | str | None = None,
        report_out_path: Path | str | None = None,
        scope: str = "all",
    ) -> dict:
        """Run checks across all rows in dictionary.db and write flags and report."""
        con = sqlite3.connect(self.db_path)
        cur = con.cursor()
        query = (
            "SELECT id, word_key, headword, headword_norm, pos, sense_index, "
            "definition_short, definition_full, freq_rank, in_learning_set FROM words"
        )
        if scope == "learning":
            query += " WHERE in_learning_set = 1"
        rows = cur.execute(query).fetchall()
        con.close()

        total_rows = len(rows)
        learning_rows = sum(1 for r in rows if r[9] == 1)
        lookup_rows = total_rows - learning_rows

        all_flags: list[dict] = []
        flags_by_rule_learning = collections.defaultdict(list)
        flags_by_rule_lookup = collections.defaultdict(list)

        t0 = time.time()
        for row in rows:
            row_flags = self.check_row(row)
            for f in row_flags:
                all_flags.append(f)
                if f["in_learning_set"] == 1:
                    flags_by_rule_learning[f["rule"]].append(f)
                else:
                    flags_by_rule_lookup[f["rule"]].append(f)

        elapsed = time.time() - t0

        # Write qa_flags.jsonl
        if flags_out_path:
            out_p = Path(flags_out_path)
            out_p.parent.mkdir(parents=True, exist_ok=True)
            with open(out_p, "w", encoding="utf-8") as f:
                for fl in all_flags:
                    f.write(json.dumps(fl, ensure_ascii=False) + "\n")

        # Compile report
        if report_out_path:
            self._write_report(
                report_out_path,
                total_rows,
                learning_rows,
                lookup_rows,
                flags_by_rule_learning,
                flags_by_rule_lookup,
                all_flags,
                elapsed,
            )

        return {
            "total_rows": total_rows,
            "learning_rows": learning_rows,
            "lookup_rows": lookup_rows,
            "all_flags_count": len(all_flags),
            "flags_by_rule_learning": {k: len(v) for k, v in flags_by_rule_learning.items()},
            "flags_by_rule_lookup": {k: len(v) for k, v in flags_by_rule_lookup.items()},
            "elapsed_seconds": elapsed,
            "flags": all_flags,
            "summary": {
                "total_checked": total_rows,
                "learning_words_checked": learning_rows,
                "lookup_words_checked": lookup_rows,
                "total_flags": len(all_flags),
            },
        }

    def _write_report(
        self,
        report_path: Path | str,
        total_rows: int,
        learning_rows: int,
        lookup_rows: int,
        flags_by_rule_learning: dict[str, list[dict]],
        flags_by_rule_lookup: dict[str, list[dict]],
        all_flags: list[dict],
        elapsed: float,
    ) -> None:
        p = Path(report_path)
        p.parent.mkdir(parents=True, exist_ok=True)

        lines = [
            "# Stage 1 QA Definitions Report",
            "",
            f"- **Database**: `{self.db_path}`",
            f"- **Total Rows Checked**: {total_rows:,} ({learning_rows:,} learning set, {lookup_rows:,} lookup set)",
            f"- **Execution Time**: {elapsed:.2f} seconds",
            f"- **Config**: `TOP_N_FREQUENCY`={self.top_n_frequency}, `SHORT_DEF_MAX_WORDS`={self.short_def_max_words}, `FULL_DEF_MAX_WORDS`={self.full_def_max_words}",
            "",
            "## Summary of Rule Violations",
            "",
            "| Rule | Description | Learning Set Flags | Lookup Set Flags | Total Flags |",
            "|---|---|---|---|---|",
        ]

        rules = ["R2", "R3", "R4", "R6"]
        rule_desc = {
            "R2": "Plain words (outside top 3k or harder than headword)",
            "R3": "Circular definition / family word",
            "R4": "Definition exceeds length cap",
            "R6": "Synonym is headword or family word",
        }

        for r in rules:
            l_cnt = len(flags_by_rule_learning.get(r, []))
            u_cnt = len(flags_by_rule_lookup.get(r, []))
            lines.append(f"| **{r}** | {rule_desc[r]} | {l_cnt:,} | {u_cnt:,} | {l_cnt + u_cnt:,} |")

        total_l = sum(len(v) for v in flags_by_rule_learning.values())
        total_u = sum(len(v) for v in flags_by_rule_lookup.values())
        lines.append(f"| **TOTAL** | All rules combined | {total_l:,} | {total_u:,} | {total_l + total_u:,} |")
        lines.append("")

        # Allowlist hits
        lines.extend([
            "## Allowlist Hits",
            "",
            f"Configured allowlist words: `{', '.join(sorted(self.allowlist))}`",
            "",
        ])
        if self.allowlist_hits:
            lines.append("| Word | Hits in Short Definitions |")
            lines.append("|---|---|")
            for w, cnt in self.allowlist_hits.most_common():
                lines.append(f"| `{w}` | {cnt:,} |")
        else:
            lines.append("No allowlist hits recorded.")
        lines.append("")

        # 20 Samples per rule
        lines.append("## 20 Samples per Rule")
        lines.append("")
        for r in rules:
            lines.append(f"### Rule {r}: {rule_desc[r]}")
            combined_rule_flags = flags_by_rule_learning.get(r, []) + flags_by_rule_lookup.get(r, [])
            sample_count = min(20, len(combined_rule_flags))
            sample = combined_rule_flags[:sample_count]
            if sample:
                lines.append("| Word Key | Set | Detail |")
                lines.append("|---|---|---|")
                for s in sample:
                    set_label = "learning" if s["in_learning_set"] == 1 else "lookup"
                    lines.append(f"| `{s['word_key']}` | {set_label} | {s['detail']} |")
            else:
                lines.append("*(No flags)*")
            lines.append("")

        # 100 Random flags sample for false-positive estimation
        lines.extend([
            "## Hand-Checkable Sample of 100 Random Flags",
            "",
            "Random sample across all flags to evaluate the false-positive rate:",
            "",
            "| # | Word Key | Headword | Set | Rule | Detail |",
            "|---|---|---|---|---|---|",
        ])

        rnd = random.Random(42)  # Deterministic seed for reproducible hand check
        sample_100 = rnd.sample(all_flags, min(100, len(all_flags)))
        for i, f in enumerate(sample_100, start=1):
            set_label = "learning" if f["in_learning_set"] == 1 else "lookup"
            lines.append(f"| {i} | `{f['word_key']}` | {f['headword']} | {set_label} | **{f['rule']}** | {f['detail']} |")

        lines.append("")
        p.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    base_dir = Path(__file__).resolve().parent
    default_work = base_dir / "work"
    default_raw = base_dir / "raw"

    parser = argparse.ArgumentParser(description="Deterministic quality checks for Mull dictionary definitions.")
    parser.add_argument("--db", type=Path, default=default_work / "dictionary.db", help="Path to dictionary.db")
    parser.add_argument("--wordnet", type=Path, default=default_raw / "english-wordnet-2024.xml.gz", help="Path to english-wordnet XML")
    parser.add_argument("--flags-out", type=Path, default=default_work / "qa_flags.jsonl", help="Output path for qa_flags.jsonl")
    parser.add_argument("--report-out", type=Path, default=default_work / "qa_report.md", help="Output path for qa_report.md")
    parser.add_argument("--top-n", type=int, default=DEFAULT_TOP_N_FREQUENCY, help="Max frequency rank for content words (R2)")
    parser.add_argument("--short-max", type=int, default=DEFAULT_SHORT_DEF_MAX_WORDS, help="Max words in definition_short (R4)")
    parser.add_argument("--full-max", type=int, default=DEFAULT_FULL_DEF_MAX_WORDS, help="Max words in definition_full (R4)")

    args = parser.parse_args()

    print(f"Running Stage 1 QA checks on {args.db}...")
    checker = QAChecker(
        db_path=args.db,
        wordnet_path=args.wordnet,
        top_n_frequency=args.top_n,
        short_def_max_words=args.short_max,
        full_def_max_words=args.full_max,
    )
    res = checker.run_all(flags_out_path=args.flags_out, report_out_path=args.report_out)

    print(f"Done in {res['elapsed_seconds']:.2f}s!")
    print(f"Total rows: {res['total_rows']:,}")
    print(f"Flags in learning set: {sum(res['flags_by_rule_learning'].values()):,} (by rule: {res['flags_by_rule_learning']})")
    print(f"Flags in lookup set:   {sum(res['flags_by_rule_lookup'].values()):,} (by rule: {res['flags_by_rule_lookup']})")
    print(f"Reports written to {args.flags_out} and {args.report_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
