"""Stage 3 & 4: LLM Rewrite under Rules v2.

Rewrites definitions, examples, and synonyms for words failing QA checks
or judged weak/wrong, enforcing Rules R1-R6 with automated verification
and up to 2 retry attempts.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import gzip
import json
import os
import random
import re
import sqlite3
import sys
import threading
import time
from pathlib import Path

# Ensure build_dictionary package directory is in sys.path
_pkg_dir = str(Path(__file__).resolve().parent)
if _pkg_dir not in sys.path:
    sys.path.insert(0, _pkg_dir)

from build_dictionary import REGISTERS, TOPICS, clean_gloss, norm
from qa_definitions import (
    QAChecker,
    tokenize,
    DEFAULT_TOP_N_FREQUENCY,
    DEFAULT_SHORT_DEF_MAX_WORDS,
    DEFAULT_FULL_DEF_MAX_WORDS,
)

# ---------------------------------------------------------------- Configuration

BATCH_SIZE = 100
RULES_VERSION = "v2"
DEFAULT_MODEL = "gemini-3.1-flash-lite"


class DailyQuotaExhaustedError(Exception):
    """Raised when the daily quota is exhausted."""
    pass


class Sustained429Error(Exception):
    """Raised when sustained 429 rate limits persist after retries."""
    pass


def load_env_file() -> None:
    """Load key-value pairs from .env into os.environ if not already set."""
    candidates = [
        Path.cwd() / ".env",
        Path(__file__).resolve().parent / ".env",
        Path(__file__).resolve().parent.parent.parent / ".env",
    ]
    for p in candidates:
        if p.is_file():
            try:
                for line in p.read_text(encoding="utf-8-sig").splitlines():
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    k = k.strip().lstrip("\ufeff")
                    v = v.strip().strip("'\"")
                    if k and k not in os.environ:
                        os.environ[k] = v
            except Exception:
                pass


class RateLimiter:
    """Enforces request rate limits (RPM and RPD)."""
    def __init__(self, rpm: int = 15, rpd: int = 1500):
        self.rpm = max(1, rpm)
        self.rpd = max(1, rpd)
        self.min_interval = 60.0 / self.rpm
        self.lock = threading.Lock()
        self.last_request_time = 0.0
        self.daily_requests = 0

    def acquire(self) -> None:
        with self.lock:
            if self.daily_requests >= self.rpd:
                raise DailyQuotaExhaustedError(
                    f"Configured daily limit ({self.rpd} requests/day) reached."
                )
            now = time.time()
            elapsed = now - self.last_request_time
            if elapsed < self.min_interval:
                time.sleep(self.min_interval - elapsed)
            self.last_request_time = time.time()
            self.daily_requests += 1


# ---------------------------------------------------------------- Prompt & Schema

SYSTEM_V2 = f"""You rewrite dictionary entries for a UK English vocabulary app according to strict quality rules (Rules v2).
You are given the word, its grammatical part of speech, source material (Wiktionary senses with register tags, WordNet gloss/synonyms, corpus stats, source examples), its current text, and why its current entry failed quality checks (meaning judge verdict, circularity flags, hard words).

Your task is to write a corrected, plain-language, non-circular entry that resolves every reported problem.

RULES V2:
R1. True to common modern use: Lead with the meaning most adult readers have in mind today. Include the connotation when it is part of the meaning (childish, disapproving, humorous, formal, literary).
R2. Plain words: Every content word in definition_short must be MORE COMMON than the headword and within the top 3,000 everyday English vocabulary. Never define a word using words that are harder, rarer, or more obscure than the headword itself. Function words (pronouns, prepositions, conjunctions, auxiliary verbs) don't count.
R3. Not circular: The definitions (both short and full) must NEVER contain:
    - the headword or any inflection of it.
    - any word from its family: the same lemma, the same root after suffix stripping, or a derivation.
      * "whimsical" can NEVER use "whim" or "whimsy".
      * "insolently" can NEVER use "insolent" or "insolence".
    - formulaic circular patterns: "in a ___ manner/way", "the quality/state of being ___", "the act of ___ing", or "relating to ___", where ___ is a family word or harder than the headword.
    * Derived forms get their own self-contained definitions: "insolently" means "in a rude way that shows no respect".
R4. Short:
    - definition_short: at most 14 words, plain language, one sentence, no semicolons, no em dashes.
    - definition_full: one to two sentences, at most 25 words. Plain and clear.
R5. The example fits:
    - Exactly one natural modern sentence, 8 to 18 words, making the meaning inferable from context.
    - Must contain the headword or an inflection of it.
    - No proper nouns as filler; no em dashes.
R6. Clean synonyms:
    - 2 to 4 common single English words with close meaning, lowercase.
    - Must match the headword's POS.
    - No synonym may be the headword or a family word (e.g. "whimsical" cannot have "whimsy" as a synonym).
General:
    - UK English / British spelling (colour, realise, centre, programme, towards NOT toward, maths NOT math, etc.).
    - In definition_short, keep vocabulary extremely simple (top 3,000 common words). Avoid words like 'unfair' (use 'not fair'), 'messy' (use 'untidy'), 'linked/connected' (use 'joined'), 'sadness' (use 'sorrow').
    - No em dashes anywhere.
    - Topics must come only from this closed list: {", ".join(TOPICS)}.
    - Register must be exactly one of: {", ".join(REGISTERS)}.
    - If base word definition is provided (for derived words), ensure your definition reads consistently with the base word.
    - If previous_attempt and rejected_because are present, strictly fix all listed reasons.
"""

GEMINI_REWRITE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "words": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "word_key": {"type": "STRING"},
                    "definition_short": {"type": "STRING"},
                    "definition_full": {"type": "STRING"},
                    "example": {"type": "STRING"},
                    "synonyms": {"type": "ARRAY", "items": {"type": "STRING"}},
                    "register": {"type": "STRING", "enum": list(REGISTERS)},
                    "topics": {"type": "ARRAY", "items": {"type": "STRING", "enum": list(TOPICS)}},
                },
                "required": [
                    "word_key",
                    "definition_short",
                    "definition_full",
                    "example",
                    "synonyms",
                    "register",
                    "topics",
                ],
            },
        }
    },
    "required": ["words"],
}


# ---------------------------------------------------------------- Validation

def validate_rewrite(
    output: dict,
    entry: dict,
    checker: QAChecker,
    us_spellings: set[str],
) -> tuple[bool, list[str]]:
    """Validate a rewritten output through QAChecker (R2, R3, R4, R6) and Stage D gates."""
    reasons: list[str] = []
    short = (output.get("definition_short") or "").strip()
    full = (output.get("definition_full") or "").strip()
    example = (output.get("example") or "").strip()
    synonyms = output.get("synonyms") or []

    if not short or not full or not example:
        return False, ["missing required text fields"]

    # Em dash check
    if "—" in short or "—" in full or "—" in example:
        reasons.append("contains em dash")
    if ";" in short:
        reasons.append("contains semicolon in definition_short")

    # US spelling check
    all_text = " ".join([short, full, example] + synonyms)
    us_found = sorted(set(re.findall(r"[a-z]+", all_text.lower())) & us_spellings)
    if us_found:
        reasons.append(f"US spelling: {', '.join(us_found)}")

    # Example checks (R5)
    hw = entry["headword"]
    infls = set(checker.aliases_by_wk.get(entry["word_key"], set()))
    hw_forms = {hw.lower()} | {f.lower() for f in infls}
    hl = hw.lower()
    hw_forms.update([hl + "s", hl + "es", hl + "ed", hl + "d", hl + "ing"])
    ex_tokens = set(re.findall(r"[a-zA-Z]+(?:'[a-zA-Z]+)?", example.lower()))
    if not (ex_tokens & hw_forms):
        reasons.append(f"example does not contain the headword '{hw}' or its inflections")

    ex_word_count = len(example.split())
    if not (8 <= ex_word_count <= 18):
        reasons.append(f"example has {ex_word_count} words (must be 8-18)")

    # Construct synthetic row for QAChecker
    synth_row = (
        0,
        entry["word_key"],
        entry["headword"],
        entry["headword"].lower(),
        entry["pos"],
        1,
        short,
        full,
        entry.get("freq_rank") or checker.hw_ranks.get(entry["headword"].lower(), 999999),
        entry.get("in_learning_set", 1),
    )

    # QAChecker R2, R3, R4 checks
    family = checker.get_family_words(entry["headword"], entry["word_key"])
    hw_rank = synth_row[8]

    # R2
    r2_fails = checker.check_r2_plain_words(short, entry["headword"].lower(), hw_rank)
    reasons.extend(r2_fails)

    # R3
    r3_fails = checker.check_r3_circular(short, full, entry["headword"], family, hw_rank)
    reasons.extend(r3_fails)

    # R4
    r4_fails = checker.check_r4_length(short, full)
    reasons.extend(r4_fails)

    # R6
    r6_fails = checker.check_r6_synonyms(synonyms, entry["headword"], family)
    reasons.extend(r6_fails)

    return len(reasons) == 0, reasons


# ---------------------------------------------------------------- Request Handler

def _request_rewrite_batch(
    client,
    model: str,
    batch_payload: list[dict],
    rate_limiter: RateLimiter | None = None,
) -> list[dict]:
    """Execute Gemini request with exponential backoff on 429."""
    from google.genai import types

    contents = json.dumps(batch_payload, ensure_ascii=False)
    max_retries = 5

    for attempt in range(max_retries + 1):
        if rate_limiter:
            rate_limiter.acquire()
        try:
            config = types.GenerateContentConfig(
                system_instruction=SYSTEM_V2,
                response_mime_type="application/json",
                response_schema=GEMINI_REWRITE_SCHEMA,
                max_output_tokens=16384,
            )
            response = client.models.generate_content(
                model=model,
                contents=contents,
                config=config,
            )
            text = getattr(response, "text", "") or ""
            data = json.loads(text)
            words = data.get("words", [])
            wanted = {item["word_key"] for item in batch_payload}
            return [w for w in words if w.get("word_key") in wanted]
        except Exception as e:
            msg = str(e)
            code = getattr(e, "code", None) or getattr(e, "status_code", None)
            is_429 = code == 429 or "RESOURCE_EXHAUSTED" in msg or "429" in msg or "quota" in msg.lower()
            is_transient = (
                code in (500, 502, 503, 504)
                or "UNAVAILABLE" in msg
                or "high demand" in msg.lower()
                or "try again later" in msg.lower()
                or "internal" in msg.lower()
            )

            if "per day" in msg.lower() or "daily" in msg.lower():
                raise DailyQuotaExhaustedError(f"Daily quota exhausted: {msg}")

            if is_429 or is_transient:
                if attempt >= max_retries:
                    if is_429:
                        raise Sustained429Error(f"Sustained 429 rate limit after {max_retries} retries: {msg}")
                    raise

                retry_after = None
                resp = getattr(e, "response", None)
                if resp and hasattr(resp, "headers"):
                    ra = resp.headers.get("retry-after")
                    if ra:
                        try:
                            retry_after = float(ra)
                        except ValueError:
                            pass
                if retry_after is None:
                    m = re.search(r"retry\s+(?:in|after)\s+([0-9.]+)\s*s?", msg, re.IGNORECASE)
                    if m:
                        try:
                            retry_after = float(m.group(1))
                        except ValueError:
                            pass

                tag = "429 rate limit" if is_429 else "503/server transient error"
                sleep_s = retry_after if retry_after is not None else min(60.0, (2.0 ** (attempt + 1))) + random.uniform(0.5, 2.0)
                print(f"  [{tag}] backing off for {sleep_s:.1f}s (retry {attempt + 1}/{max_retries})...", flush=True)
                time.sleep(sleep_s)
                continue
            else:
                raise


# ---------------------------------------------------------------- Pipeline Runner

class RewritePipeline:
    def __init__(
        self,
        checker: QAChecker,
        cache_path: Path,
        model: str = DEFAULT_MODEL,
        rpm: int | None = None,
        rpd: int | None = None,
    ):
        self.checker = checker
        self.cache_path = cache_path
        self.model = model
        load_env_file()
        from google import genai
        from google.genai import types

        keys = []
        for kn in ["GEMINI_API_KEY", "BACKUP_GEMINI_API_KEY", "GOOGLE_API_KEY"]:
            k = os.environ.get(kn)
            if k and k not in keys:
                keys.append(k)
        if not keys:
            raise ValueError("No Gemini API key found. Set GEMINI_API_KEY in .env.")
        self.keys = keys
        self.key_idx = 0
        print(f"Configured {len(self.keys)} Gemini API keys for automatic failover.")
        self.client = genai.Client(
            api_key=self.keys[self.key_idx],
            http_options=types.HttpOptions(timeout=60000),
        )

        effective_rpm = rpm or int(os.environ.get("GEMINI_RPM", 15))
        effective_rpd = rpd or int(os.environ.get("GEMINI_RPD", 1500))
        self.rate_limiter = RateLimiter(rpm=effective_rpm, rpd=effective_rpd)

        # US spellings lookup from aliases
        con = sqlite3.connect(checker.db_path)
        cur = con.cursor()
        self.us_spellings = {
            row[0] for row in cur.execute("SELECT alias_norm FROM aliases WHERE kind = 'us_spelling'")
        } - {"my", "our", "relative", "tireless", "story"}
        con.close()

        # Load existing v2 cache
        self.v2_cache: dict[str, dict] = {}
        if self.cache_path.is_file():
            for line in self.cache_path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line:
                    try:
                        rec = json.loads(line)
                        if rec.get("rules_version") == RULES_VERSION and rec.get("qa_passed"):
                            self.v2_cache[rec["word_key"]] = rec
                    except Exception:
                        pass
        print(f"Loaded {len(self.v2_cache):,} passing v2 entries from {self.cache_path.name}")

    def rotate_key(self) -> bool:
        """Rotate to next available API key on quota exhaustion."""
        if self.key_idx + 1 < len(self.keys):
            self.key_idx += 1
            print(f"\n[KEY ROTATION] Rotating to API key {self.key_idx + 1}/{len(self.keys)}...", flush=True)
            from google import genai
            from google.genai import types
            self.client = genai.Client(
                api_key=self.keys[self.key_idx],
                http_options=types.HttpOptions(timeout=60000),
            )
            self.rate_limiter = RateLimiter(rpm=self.rate_limiter.rpm, rpd=self.rate_limiter.rpd)
            return True
        return False

    def rewrite_entries(
        self,
        entries: list[dict],
        max_attempts: int = 3,
    ) -> tuple[dict[str, dict], list[str]]:
        """Rewrite entries with up to max_attempts on validation failure."""
        results: dict[str, dict] = {}
        unresolved: list[str] = []

        # Check existing passing cache
        pending = []
        for entry in entries:
            wk = entry["word_key"]
            if wk in self.v2_cache:
                results[wk] = self.v2_cache[wk]["output"]
            else:
                pending.append(entry)

        if not pending:
            return results, unresolved

        print(f"Rewriting {len(pending):,} pending entries under Rules v2 (batch size {BATCH_SIZE})...")
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)

        start_time = time.time()
        # Group into batches
        batches = [pending[i: i + BATCH_SIZE] for i in range(0, len(pending), BATCH_SIZE)]

        with open(self.cache_path, "a", encoding="utf-8") as out_f:
            for b_idx, batch in enumerate(batches, start=1):
                # Attempt 1 for batch
                payload = [
                    {
                        "word_key": it["word_key"],
                        "headword": it["headword"],
                        "pos": it["pos"],
                        "source_senses": it.get("source_senses", []),
                        "source_wordnet_gloss": it.get("source_wordnet_gloss"),
                        "source_wordnet_synonyms": it.get("source_wordnet_synonyms", []),
                        "source_examples": it.get("source_examples", []),
                        "current_definition_short": it.get("current_definition_short"),
                        "current_definition_full": it.get("current_definition_full"),
                        "current_example": it.get("current_example"),
                        "failed_checks": it.get("failed_checks", []),
                        "judge_reason": it.get("judge_reason"),
                        "base_word_definition": it.get("base_word_definition"),
                    }
                    for it in batch
                ]

                try:
                    outputs = _request_rewrite_batch(self.client, self.model, payload, self.rate_limiter)
                except (DailyQuotaExhaustedError, Sustained429Error) as e:
                    if self.rotate_key():
                        try:
                            outputs = _request_rewrite_batch(self.client, self.model, payload, self.rate_limiter)
                        except (DailyQuotaExhaustedError, Sustained429Error) as e2:
                            remaining = len(pending) - len(results)
                            print(f"\n[QUOTA STOPPED on all keys] {e2}")
                            return results, unresolved
                    else:
                        remaining = len(pending) - len(results)
                        print(f"\n[QUOTA STOPPED] {e}")
                        print(f"Clean exit: {len(results):,} words rewritten in this run, {remaining:,} words remaining.")
                        print(f"All progress saved to {self.cache_path}. Re-run once quota resets.")
                        return results, unresolved

                output_map = {o["word_key"]: o for o in outputs}

                # Validate attempt 1 outputs
                batch_status = {}
                for entry in batch:
                    wk = entry["word_key"]
                    out = output_map.get(wk)
                    passed = False
                    reasons = []
                    if out:
                        passed, reasons = validate_rewrite(out, entry, self.checker, self.us_spellings)
                    batch_status[wk] = {
                        "entry": entry,
                        "out": out,
                        "passed": passed,
                        "reasons": reasons,
                        "attempt": 1,
                    }

                # Batched retry for any failed words in this batch
                for attempt in range(2, max_attempts + 1):
                    failed_in_batch = [item for item in batch_status.values() if not item["passed"]]
                    if not failed_in_batch:
                        break

                    print(f"  [batch retry {attempt}/{max_attempts}] Retrying {len(failed_in_batch)} failed words together...", flush=True)
                    retry_payload = [
                        {
                            "word_key": item["entry"]["word_key"],
                            "headword": item["entry"]["headword"],
                            "pos": item["entry"]["pos"],
                            "source_senses": item["entry"].get("source_senses", []),
                            "source_wordnet_gloss": item["entry"].get("source_wordnet_gloss"),
                            "source_wordnet_synonyms": item["entry"].get("source_wordnet_synonyms", []),
                            "source_examples": item["entry"].get("source_examples", []),
                            "current_definition_short": item["entry"].get("current_definition_short"),
                            "current_definition_full": item["entry"].get("current_definition_full"),
                            "current_example": item["entry"].get("current_example"),
                            "failed_checks": item["entry"].get("failed_checks", []),
                            "previous_attempt": item["out"],
                            "rejected_because": item["reasons"],
                            "base_word_definition": item["entry"].get("base_word_definition"),
                        }
                        for item in failed_in_batch
                    ]

                    try:
                        retry_outputs = _request_rewrite_batch(self.client, self.model, retry_payload, self.rate_limiter)
                        retry_map = {o["word_key"]: o for o in retry_outputs}
                        for item in failed_in_batch:
                            wk = item["entry"]["word_key"]
                            new_out = retry_map.get(wk)
                            if new_out:
                                p, r = validate_rewrite(new_out, item["entry"], self.checker, self.us_spellings)
                                item["out"] = new_out
                                item["passed"] = p
                                item["reasons"] = r
                                item["attempt"] = attempt
                    except Exception as e:
                        print(f"    batched retry request failed: {e}", flush=True)

                # Record all items from the batch to cache
                for wk, item in batch_status.items():
                    passed = item["passed"]
                    out = item["out"]
                    reasons = item["reasons"]
                    attempt = item["attempt"]
                    entry = item["entry"]

                    rec = {
                        "word_key": wk,
                        "rules_version": RULES_VERSION,
                        "model": self.model,
                        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                        "attempt": attempt,
                        "qa_passed": passed,
                        "qa_reasons": reasons,
                        "output": out if passed else None,
                    }
                    out_f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    out_f.flush()

                    if passed and out:
                        results[wk] = out
                        self.v2_cache[wk] = rec
                    else:
                        unresolved.append(wk)
                        print(f"  [UNRESOLVED] {entry['headword']} ({wk}) after {attempt} attempts: {reasons}")

                elapsed = time.time() - start_time
                rate = ((b_idx * BATCH_SIZE) / elapsed) if elapsed > 0 else 0.0
                rem_b = len(batches) - b_idx
                eta_s = rem_b * (elapsed / b_idx) if b_idx > 0 else 0.0
                eta_str = str(dt.timedelta(seconds=int(eta_s)))
                print(f"  [batch {b_idx}/{len(batches)}] {len(results):,} resolved, {len(unresolved):,} unresolved | {rate*60:.1f} w/min | ETA: {eta_str}", flush=True)

        return results, unresolved


# ---------------------------------------------------------------- Candidate Loader & Base Word

FIXTURE_HEADWORDS = [
    "petulant", "whimsical", "whimsically", "insolently",
    "abasedly", "abasement", "abashedly", "abashlessly", "abatement",
    "abdication", "abduction", "aberrance", "aberrantly", "abetment",
    "abetting", "abhorrency", "abidance", "abidingly", "ability",
    "abjectness", "abjugation", "abjuration", "abnormality", "abnormally",
]


def find_base_word(hw: str, words_by_hw: dict[str, list[dict]]) -> tuple[str, str] | None:
    """Find base word and its definition if hw is a derived form."""
    suffixes = [
        ("lessly", ["", "less", "ful"]),
        ("ly", ["", "e", "ic", "ical", "al"]),
        ("ness", ["", "e", "y"]),
        ("ment", ["", "e"]),
        ("tion", ["te", "t", "", "e"]),
        ("ation", ["e", "", "ate"]),
        ("ity", ["", "e", "able", "al", "ous"]),
        ("ency", ["ent", "e", ""]),
        ("ance", ["e", "ant", ""]),
        ("ting", ["t", "te", ""]),
        ("ing", ["", "e"]),
    ]
    for suf, repls in suffixes:
        if hw.endswith(suf):
            base_stem = hw[:-len(suf)]
            for r in repls:
                cand = base_stem + r
                if cand in words_by_hw and cand != hw:
                    cand_entries = words_by_hw[cand]
                    if cand_entries:
                        best = cand_entries[0]
                        defn = best.get("definition_short") or best.get("definition_full") or ""
                        return cand, f"{cand} ({best.get('pos')}): {defn}"
    return None


def load_candidates(
    db_path: Path,
    learning_set_path: Path,
    qa_flags_path: Path,
    judge_cache_path: Path,
    scope: str = "learning",
    trial_count: int | None = None,
    frequency_cutoff: int = 30000,
    limit: int | None = None,
    cache_path: Path | None = None,
) -> list[dict]:
    """Load and prioritize rewrite candidates based on QA flags and judge verdicts."""
    con = sqlite3.connect(db_path)
    cur = con.cursor()

    words_by_key: dict[str, dict] = {}
    words_by_hw: dict[str, list[dict]] = collections.defaultdict(list)

    for row in cur.execute(
        """SELECT word_key, headword, headword_norm, pos, sense_index,
                  definition_short, definition_full, freq_rank, band,
                  in_learning_set, prevalence, zipf_spoken, zipf_written
           FROM words"""
    ):
        d = {
            "word_key": row[0],
            "headword": row[1],
            "headword_norm": row[2],
            "pos": row[3],
            "sense_index": row[4],
            "definition_short": row[5],
            "definition_full": row[6],
            "freq_rank": row[7],
            "band": row[8],
            "in_learning_set": row[9],
            "prevalence": row[10],
            "zipf_spoken": row[11],
            "zipf_written": row[12],
        }
        words_by_key[row[0]] = d
        words_by_hw[row[2]].append(d)

    examples_by_key = collections.defaultdict(list)
    for wk, text in cur.execute("SELECT word_key, text FROM examples"):
        examples_by_key[wk].append(text)

    synonyms_by_key = collections.defaultdict(list)
    for wk, syn in cur.execute("SELECT word_key, synonym FROM synonyms"):
        synonyms_by_key[wk].append(syn)
    con.close()

    # Load learning set
    learning_by_key: dict[str, dict] = {}
    if learning_set_path.is_file():
        for line in learning_set_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    data = json.loads(line)
                    learning_by_key[data["word_key"]] = data
                except Exception:
                    pass

    # Load QA flags
    qa_flags_by_key: dict[str, list[dict]] = collections.defaultdict(list)
    if qa_flags_path.is_file():
        for line in qa_flags_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    rec = json.loads(line)
                    qa_flags_by_key[rec["word_key"]].append(rec)
                except Exception:
                    pass

    # Load Judge cache
    judge_by_key: dict[str, dict] = {}
    if judge_cache_path.is_file():
        for line in judge_cache_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    rec = json.loads(line)
                    judge_by_key[rec["word_key"]] = rec.get("verdict", {})
                except Exception:
                    pass

    # Load passing v2 keys from cache to skip already resolved words
    cached_v2_keys = set()
    if cache_path and cache_path.is_file():
        for line in cache_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    rec = json.loads(line)
                    if rec.get("rules_version") == RULES_VERSION and rec.get("qa_passed"):
                        cached_v2_keys.add(rec["word_key"])
                except Exception:
                    pass

    # Candidate selection
    selected_keys: list[str] = []

    if trial_count:
        # 1. Mandatory fixture headwords first
        for hw in FIXTURE_HEADWORDS:
            norm_hw = hw.lower().strip()
            entries = words_by_hw.get(norm_hw, [])
            if entries:
                # Sense 1
                entries.sort(key=lambda x: x["sense_index"])
                wk = entries[0]["word_key"]
                if wk not in selected_keys:
                    selected_keys.append(wk)

        # 2. Add learning set words failing QA checks or judged weak/wrong
        learning_candidates = []
        for wk, w in words_by_key.items():
            if not w["in_learning_set"] or wk in selected_keys:
                continue
            flags = qa_flags_by_key.get(wk, [])
            flag_rules = {f["rule"] for f in flags}
            judge = judge_by_key.get(wk, {})
            acc = judge.get("accuracy")

            if acc == "wrong":
                prio = 0
            elif "R3" in flag_rules or judge.get("circular"):
                prio = 1
            elif acc == "weak":
                prio = 2
            elif "R2" in flag_rules or judge.get("too_hard_words"):
                prio = 3
            elif flag_rules & {"R4", "R6"}:
                prio = 4
            else:
                continue

            learning_candidates.append((prio, -len(flags), wk))

        learning_candidates.sort()
        needed = trial_count - len(selected_keys)
        for _, _, wk in learning_candidates[:needed]:
            selected_keys.append(wk)

    else:
        # Full scope run
        if scope in ("learning", "all"):
            learning_candidates = []
            for wk, w in words_by_key.items():
                if not w["in_learning_set"]:
                    continue
                flags = qa_flags_by_key.get(wk, [])
                flag_rules = {f["rule"] for f in flags}
                judge = judge_by_key.get(wk, {})
                acc = judge.get("accuracy")

                if acc == "wrong":
                    prio = 0
                elif "R3" in flag_rules or judge.get("circular"):
                    prio = 1
                elif acc == "weak":
                    prio = 2
                elif "R2" in flag_rules or judge.get("too_hard_words"):
                    prio = 3
                elif flag_rules & {"R4", "R6"}:
                    prio = 4
                else:
                    continue
                learning_candidates.append((prio, -len(flags), wk))

            learning_candidates.sort()
            selected_keys.extend([wk for _, _, wk in learning_candidates])

        if scope in ("lookup", "all"):
            # Option A: R3 circularity for all lookup words + R2 plain language for freq_rank <= cutoff
            lookup_candidates = []
            for wk, w in words_by_key.items():
                if w["in_learning_set"] or wk in selected_keys or wk in cached_v2_keys:
                    continue
                if (w["freq_rank"] and w["freq_rank"] < 500) or len(w["headword"]) < 3:
                    continue
                flags = qa_flags_by_key.get(wk, [])
                flag_rules = {f["rule"] for f in flags}

                is_r3 = "R3" in flag_rules
                is_r2 = "R2" in flag_rules and (w["freq_rank"] or 999999) <= frequency_cutoff

                if is_r3:
                    prio = 1
                elif is_r2:
                    prio = 3
                elif flag_rules & {"R4", "R6"}:
                    prio = 4
                else:
                    continue
                lookup_candidates.append((prio, w["freq_rank"] or 999999, -len(flags), wk))

            lookup_candidates.sort()
            selected_keys.extend([wk for _, _, _, wk in lookup_candidates])

    if limit is not None and limit > 0:
        selected_keys = selected_keys[:limit]

    # Build entry objects
    result_entries: list[dict] = []
    for wk in selected_keys:
        w = words_by_key[wk]
        hw = w["headword"]
        pos = w["pos"]
        cur_short = w["definition_short"] or w["definition_full"]
        cur_full = w["definition_full"]
        cur_exs = examples_by_key.get(wk, [])
        cur_syns = synonyms_by_key.get(wk, [])
        flags = qa_flags_by_key.get(wk, [])
        judge = judge_by_key.get(wk, {})

        failed_checks = [f"{f['rule']}: {f['detail']}" for f in flags]
        if judge.get("missing_connotation"):
            failed_checks.append(f"missing_connotation: {judge['missing_connotation']}")
        if judge.get("too_hard_words"):
            failed_checks.append(f"too_hard_words: {', '.join(judge['too_hard_words'])}")
        if judge.get("circular"):
            failed_checks.append("judge_circular: true")
        if judge.get("example_fits") is False:
            failed_checks.append("judge_example_fits: false")

        base_info = find_base_word(w["headword_norm"], words_by_hw)
        base_def = base_info[1] if base_info else None

        if wk in learning_by_key:
            l_src = learning_by_key[wk]
            src_senses = l_src.get("senses", [])
            wn_gloss = l_src.get("wordnet_gloss")
            wn_syns = l_src.get("wordnet_synonyms", [])
            src_exs = l_src.get("examples") or cur_exs
        else:
            src_senses = [{"gloss": cur_full, "tags": []}]
            wn_gloss = None
            wn_syns = cur_syns
            src_exs = cur_exs

        result_entries.append({
            "word_key": wk,
            "headword": hw,
            "pos": pos,
            "source_senses": src_senses,
            "source_wordnet_gloss": wn_gloss,
            "source_wordnet_synonyms": wn_syns,
            "source_examples": src_exs,
            "current_definition_short": cur_short,
            "current_definition_full": cur_full,
            "current_example": cur_exs[0] if cur_exs else None,
            "current_synonyms": cur_syns,
            "failed_checks": failed_checks,
            "judge_reason": judge.get("reason"),
            "base_word_definition": base_def,
            "freq_rank": w["freq_rank"],
            "in_learning_set": w["in_learning_set"],
        })

    return result_entries


def format_trial_table(
    entries: list[dict],
    results: dict[str, dict],
    unresolved: list[str],
) -> str:
    """Format before-and-after comparison table in Markdown."""
    lines = [
        "| Headword | POS | Set | Old Definition | New Definition (Short) | New Definition (Full) | New Example | Synonyms | Status |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for e in entries:
        wk = e["word_key"]
        hw = e["headword"]
        pos = e["pos"]
        l_set = "Learn" if e["in_learning_set"] else "Lookup"
        old_def = (e["current_definition_short"] or e["current_definition_full"] or "").replace("|", "/")
        if wk in results:
            out = results[wk]
            new_short = (out.get("definition_short") or "").replace("|", "/")
            new_full = (out.get("definition_full") or "").replace("|", "/")
            new_ex = (out.get("example") or "").replace("|", "/")
            syns = ", ".join(out.get("synonyms") or [])
            status = "PASSED"
        else:
            new_short = "-"
            new_full = "-"
            new_ex = "-"
            syns = "-"
            status = "UNRESOLVED"
        lines.append(f"| **{hw}** | {pos} | {l_set} | {old_def} | {new_short} | {new_full} | *{new_ex}* | {syns} | {status} |")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Rewrite definitions under Rules v2.")
    parser.add_argument("--trial", type=int, nargs="?", const=40, help="Run a trial on N words (default 40) and print comparison table")
    parser.add_argument("--all", action="store_true", help="Run full rewrite on candidate words")
    parser.add_argument("--scope", choices=["learning", "lookup", "all"], default="learning", help="Candidate scope (learning, lookup, all)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Gemini model (default: {DEFAULT_MODEL})")
    parser.add_argument("--cache", type=Path, default=Path("tools/build_dictionary/work/llm_cache.jsonl"), help="Cache path")
    parser.add_argument("--db", type=Path, default=Path("tools/build_dictionary/work/dictionary.db"), help="Database path")
    parser.add_argument("--learning-set", type=Path, default=Path("tools/build_dictionary/work/learning_set.jsonl"), help="Learning set path")
    parser.add_argument("--qa-flags", type=Path, default=Path("tools/build_dictionary/work/qa_flags.jsonl"), help="QA flags path")
    parser.add_argument("--judge-cache", type=Path, default=Path("tools/build_dictionary/work/judge_cache.jsonl"), help="Judge cache path")
    parser.add_argument("--frequency-cutoff", type=int, default=30000, help="Frequency rank cutoff for lookup set plain-language fixes")
    parser.add_argument("--limit", type=int, default=None, help="Maximum number of candidates to process")
    parser.add_argument("--rpm", type=int, default=None, help="Requests per minute")
    parser.add_argument("--rpd", type=int, default=None, help="Requests per day")

    args = parser.parse_args()

    # Resolve paths relative to script location if default or not found
    base_dir = Path(__file__).resolve().parent
    if not args.db.is_file():
        args.db = base_dir / "work/dictionary.db"
    if not args.cache.is_file() and not args.cache.parent.exists():
        args.cache = base_dir / "work/llm_cache.jsonl"
    if not args.learning_set.is_file():
        args.learning_set = base_dir / "work/learning_set.jsonl"
    if not args.qa_flags.is_file():
        args.qa_flags = base_dir / "work/qa_flags.jsonl"
    if not args.judge_cache.is_file():
        args.judge_cache = base_dir / "work/judge_cache.jsonl"

    checker = QAChecker(args.db)
    pipeline = RewritePipeline(
        checker=checker,
        cache_path=args.cache,
        model=args.model,
        rpm=args.rpm,
        rpd=args.rpd,
    )

    trial_n = args.trial
    candidates = load_candidates(
        db_path=args.db,
        learning_set_path=args.learning_set,
        qa_flags_path=args.qa_flags,
        judge_cache_path=args.judge_cache,
        scope=args.scope,
        trial_count=trial_n,
        frequency_cutoff=args.frequency_cutoff,
        limit=args.limit,
        cache_path=args.cache,
    )

    print(f"Loaded {len(candidates):,} rewrite candidates (trial={trial_n}, scope={args.scope}).")

    results, unresolved = pipeline.rewrite_entries(candidates)

    if trial_n:
        print("\n" + "=" * 80)
        print(f"REWRITE TRIAL ({len(candidates)} words) - BEFORE & AFTER")
        print("=" * 80 + "\n")
        table_md = format_trial_table(candidates, results, unresolved)
        print(table_md)
        print(f"\nTrial Summary: {len(results)}/{len(candidates)} resolved, {len(unresolved)} unresolved.")
    else:
        print(f"\nRewrite pass finished: {len(results):,} resolved, {len(unresolved)} unresolved.")


if __name__ == "__main__":
    main()
