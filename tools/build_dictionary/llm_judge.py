"""Stage 2: LLM Meaning Check / Judge.

Evaluates definition accuracy, missing connotation, hard words, circularity,
and example fit for learning-set words.

Run with:
    .venv/bin/python llm_judge.py --trial 40
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import random
import re
import sqlite3
import sys
import threading
import time
from pathlib import Path

# ---------------------------------------------------------------- Rate Limiting

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

SYSTEM_INSTRUCTION = """You are a rigorous, highly discerning lexicographical judge evaluating vocabulary definitions for a modern UK English learning app.
Users depend on these entries to master the living meaning, tone, and exact connotation of words.

For each word, you receive the source material (Wiktionary senses, WordNet gloss/synonyms, source examples) and Mull's current entry (definition_short, definition_full, current_example).

Evaluate each entry against these standards:
1. accuracy:
   - "ok": Accurately captures the primary modern meaning as educated adult readers in the UK understand and use it today.
   - "weak": Technically defensible from a source gloss but misses what most adult readers mean by the word, dilutes its core meaning, or misses a vital connotation (e.g. defining "petulant" primarily around generic irritability or "easily angered", rather than moody, sulky bad temper in a childish way; or defining a word around an archaic/fringe sense).
   - "wrong": Factually incorrect, contradictory, defines a homograph, or unrecognisable.
2. missing_connotation: string or null. If accuracy is "weak" or "wrong", or if the definition lacks the essential emotional tone, state the missing nuance (e.g. "childish, sulky ill-temper", "disapproving / formal", "humorous / playful"). Null if accurate.
3. too_hard_words: list of words in definition_short that are noticeably harder, rarer, or more academic than the headword, or outside top 3,000 everyday vocabulary. Empty list or null if clean.
4. circular: boolean. true if definition_short or definition_full uses the headword, an inflection, a family word (e.g. "whimsical" using "whimsy", "insolently" using "insolent"), or circular formulaic patterns ("in a ___ manner", "the state of being ___"). false otherwise.
5. example_fits: boolean. true if current_example naturally illustrates the correct modern meaning and contains the headword. false otherwise.
6. reason: one concise sentence explaining your overall verdict.
"""

GEMINI_JUDGE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "verdicts": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "word_key": {"type": "STRING"},
                    "accuracy": {"type": "STRING", "enum": ["ok", "weak", "wrong"]},
                    "missing_connotation": {"type": "STRING", "nullable": True},
                    "too_hard_words": {"type": "ARRAY", "items": {"type": "STRING"}, "nullable": True},
                    "circular": {"type": "BOOLEAN"},
                    "example_fits": {"type": "BOOLEAN"},
                    "reason": {"type": "STRING"},
                },
                "required": ["word_key", "accuracy", "circular", "example_fits", "reason"],
            },
        }
    },
    "required": ["verdicts"],
}

BATCH_SIZE = 20


# ---------------------------------------------------------------- Core Execution

def load_data(
    learning_set_path: Path,
    db_path: Path,
) -> list[dict]:
    """Load learning-set source data and join with current definitions and examples from dictionary.db."""
    con = sqlite3.connect(db_path)
    cur = con.cursor()

    words_current = {}
    for wk, hw, pos, short, full in cur.execute(
        "SELECT word_key, headword, pos, definition_short, definition_full FROM words WHERE in_learning_set = 1"
    ):
        words_current[wk] = {
            "headword": hw,
            "pos": pos,
            "definition_short": short or full,
            "definition_full": full,
        }

    examples_current = collections.defaultdict(list)
    for wk, text in cur.execute(
        "SELECT word_key, text FROM examples WHERE word_key IN (SELECT word_key FROM words WHERE in_learning_set = 1)"
    ):
        examples_current[wk].append(text)
    con.close()

    items = []
    with open(learning_set_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            src = json.loads(line)
            wk = src["word_key"]
            if wk not in words_current:
                continue
            cur_w = words_current[wk]
            exs = examples_current.get(wk, [])
            items.append({
                "word_key": wk,
                "headword": cur_w["headword"],
                "pos": cur_w["pos"],
                "source_senses": src.get("senses", []),
                "source_wordnet_gloss": src.get("wordnet_gloss"),
                "source_wordnet_synonyms": src.get("wordnet_synonyms", []),
                "source_examples": src.get("examples", []),
                "current_definition_short": cur_w["definition_short"],
                "current_definition_full": cur_w["definition_full"],
                "current_example": exs[0] if exs else None,
            })
    return items


def judge_batch(
    client,
    model: str,
    batch: list[dict],
    rate_limiter: RateLimiter | None = None,
) -> list[dict]:
    """Send a batch of items to Gemini structured judge endpoint."""
    from google.genai import types
    from google.genai import errors

    contents = json.dumps(batch, ensure_ascii=False)
    max_retries = 5

    for attempt in range(max_retries + 1):
        if rate_limiter:
            rate_limiter.acquire()
        try:
            config = types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION,
                response_mime_type="application/json",
                response_schema=GEMINI_JUDGE_SCHEMA,
            )
            response = client.models.generate_content(
                model=model,
                contents=contents,
                config=config,
            )
            text = getattr(response, "text", "") or ""
            data = json.loads(text)
            verdicts = data.get("verdicts", [])
            wanted = {item["word_key"] for item in batch}
            return [v for v in verdicts if v.get("word_key") in wanted]
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


def run_judge(
    items: list[dict],
    model: str = "gemini-3.5-flash-lite",
    cache_path: Path = Path("work/judge_cache.jsonl"),
    rpm: int | None = None,
    rpd: int | None = None,
) -> list[dict]:
    """Evaluate items, appending to judge_cache.jsonl, resuming across runs."""
    load_env_file()
    from google import genai

    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("No Gemini API key found. Set GEMINI_API_KEY in .env.")
    client = genai.Client(api_key=api_key)

    effective_rpm = rpm or int(os.environ.get("GEMINI_RPM", 15))
    effective_rpd = rpd or int(os.environ.get("GEMINI_RPD", 1500))
    rate_limiter = RateLimiter(rpm=effective_rpm, rpd=effective_rpd)

    # Load existing cache
    cached: dict[str, dict] = {}
    if cache_path.is_file():
        for line in cache_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    rec = json.loads(line)
                    cached[rec["word_key"]] = rec["verdict"]
                except Exception:
                    pass

    # Filter pending
    pending = [it for it in items if it["word_key"] not in cached]
    print(f"Stage 2 Judge: {len(cached):,} already judged in cache, {len(pending):,} pending.")

    batches = [pending[i: i + BATCH_SIZE] for i in range(0, len(pending), BATCH_SIZE)]
    cache_path.parent.mkdir(parents=True, exist_ok=True)

    results: list[dict] = [cached[it["word_key"]] for it in items if it["word_key"] in cached]

    with open(cache_path, "a", encoding="utf-8") as out_f:
        for b_idx, batch in enumerate(batches, start=1):
            try:
                verdicts = judge_batch(client, model, batch, rate_limiter)
            except (DailyQuotaExhaustedError, Sustained429Error) as e:
                remaining = len(pending) - (b_idx - 1) * BATCH_SIZE
                print(f"\n[QUOTA STOPPED] {e}")
                print(f"Clean exit: {len(results):,} words judged so far, {remaining:,} words remaining.")
                print(f"Progress saved to {cache_path}. Re-run once quota resets.")
                raise

            for v in verdicts:
                rec = {
                    "word_key": v["word_key"],
                    "model": model,
                    "evaluated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
                    "verdict": v,
                }
                out_f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                cached[v["word_key"]] = v
                results.append(v)
            out_f.flush()
            print(f"  [judge progress] batch {b_idx}/{len(batches)} ({len(verdicts)} words)", flush=True)

    return results


def print_verdict_table(items: list[dict], verdicts: list[dict]) -> None:
    """Print an aligned markdown table of judge results."""
    v_map = {v["word_key"]: v for v in verdicts}
    print("\n### Stage 2: Meaning Check (LLM Judge Trial Results)\n")
    print("| # | Word | Acc | Connotation Missing | Hard Words | Circ | Ex Fits | Reason |")
    print("|---|---|:---:|---|---|:---:|:---:|---|")
    for i, it in enumerate(items, start=1):
        wk = it["word_key"]
        v = v_map.get(wk)
        if not v:
            continue
        hw = it["headword"]
        acc = v["accuracy"]
        acc_badge = f"**{acc.upper()}**" if acc != "ok" else "ok"
        conn = v.get("missing_connotation") or "-"
        hard = ", ".join(v.get("too_hard_words") or []) or "-"
        circ = "YES" if v.get("circular") else "no"
        ex = "yes" if v.get("example_fits") else "NO"
        reason = v.get("reason", "")
        print(f"| {i} | `{hw}` | {acc_badge} | {conn} | {hard} | {circ} | {ex} | {reason} |")
    print("")


def main() -> int:
    base_dir = Path(__file__).resolve().parent
    default_work = base_dir / "work"
    default_ls = default_work / "learning_set.jsonl"
    default_db = default_work / "dictionary.db"
    default_cache = default_work / "judge_cache.jsonl"

    parser = argparse.ArgumentParser(description="Stage 2 LLM Judge for Mull definitions.")
    parser.add_argument("--learning-set", type=Path, default=default_ls)
    parser.add_argument("--db", type=Path, default=default_db)
    parser.add_argument("--cache", type=Path, default=default_cache)
    parser.add_argument("--trial", type=int, default=0, help="Trial mode: run on N words only (must include petulant)")
    parser.add_argument("--rpm", type=int, default=None)
    parser.add_argument("--rpd", type=int, default=None)
    parser.add_argument("--all", action="store_true", help="Run across the whole learning set")

    args = parser.parse_args()

    items = load_data(args.learning_set, args.db)
    print(f"Loaded {len(items):,} learning-set words from {args.learning_set} & {args.db}")

    if args.trial > 0:
        # Build trial set of N words, strictly ensuring 'petulant|adj|1' is included
        target_wk = "petulant|adj|1"
        target_item = next((it for it in items if it["word_key"] == target_wk), None)
        if not target_item:
            print(f"ERROR: {target_wk} not found in learning set!")
            return 1

        # Pick diverse sample: some with Stage 1 flags, some clean
        rnd = random.Random(123)
        other_items = [it for it in items if it["word_key"] != target_wk]
        selected = [target_item] + rnd.sample(other_items, args.trial - 1)
        # Sort so petulant is visible near the top or alphabetical
        selected.sort(key=lambda it: (0 if it["word_key"] == target_wk else 1, it["headword"]))
        
        verdicts = run_judge(selected, cache_path=args.cache, rpm=args.rpm, rpd=args.rpd)
        print_verdict_table(selected, verdicts)
        return 0

    elif args.all:
        verdicts = run_judge(items, cache_path=args.cache, rpm=args.rpm, rpd=args.rpd)
        print(f"\nCompleted judging {len(verdicts):,} words. Cache at {args.cache}")
        return 0

    else:
        print("Specify either --trial 40 or --all")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
