"""Stage C: rewrite learning-set definitions from their source material.

Run through build_dictionary.py --llm. Every request carries the Wiktionary
senses, WordNet gloss and examples for its words; the model rewrites, it never
invents. Output is appended to work/llm_cache.jsonl, one line per attempt, so
a killed run resumes where it stopped and the build can re-gate old attempts
without calling the API again.

Supports Anthropic (claude-haiku-4-5) and Gemini (Flash / Flash-Lite).
"""
from __future__ import annotations

import concurrent.futures
import datetime as dt
import json
import os
import random
import re
import threading
import time
from pathlib import Path

from build_dictionary import REGISTERS, TOPICS

BATCH = 20
WORKERS = 4

SYSTEM = f"""You rewrite dictionary entries for a UK English vocabulary app. You are given the source
material for each word: its Wiktionary senses (with register tags), a WordNet gloss and synonyms
where matched, existing usage examples, and corpus statistics. You rewrite; you never invent.
Never introduce a sense that is not present in the source material.

For each word return one object:
- word_key: copied from the input.
- definition_short: at most 14 words, plain language, one sentence, no semicolons, no "see also".
  Define the word as it is used today. Ignore senses tagged obsolete, archaic, dated or historical
  unless every sense is. Cover the main modern sense only.
- definition_full: one to three sentences, still plain, may mention a secondary modern sense.
- example: one natural modern sentence, 8 to 18 words, that makes the meaning inferable from
  context even to someone who does not know the word. Must contain the headword or an inflection
  of it. No proper nouns unless the word requires one; no invented people or places named in a way
  that reads as filler.
- synonyms: two to four single common English words with close meaning, lowercase, no phrases.
- register: exactly one of {", ".join(REGISTERS)}. "technical" means jargon of a field.
- topics: zero to three from this closed list only, never anything else: {", ".join(TOPICS)}.
  Assign a topic only when the word clearly belongs. borrowed_word is for words English still
  treats as foreign (schadenfreude, de facto, ennui). intensity is for words that replace
  "very + adjective" or "very much" (excruciating, devour). society_and_news is vocabulary of
  headlines and public life. Leave topics empty rather than guess.
- note: null, or the string "insufficient source" if the material is too thin to write a
  confident definition, in which case leave the other fields null. Do not guess.

Rules that apply to every field: UK English and British spelling (colour, realise, centre,
programme, travelling). No em dashes anywhere. Never use the headword, or any inflection or
derivative of it, inside definition_short or definition_full. Do not start definition_short
with "The act of" or "The state of" when a plainer phrasing exists.

If the input carries previous_attempt and rejected_because, fix exactly those problems.
"""

SCHEMA = {
    "type": "object",
    "properties": {
        "words": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "word_key": {"type": "string"},
                    "definition_short": {"type": ["string", "null"]},
                    "definition_full": {"type": ["string", "null"]},
                    "example": {"type": ["string", "null"]},
                    "synonyms": {"type": ["array", "null"], "items": {"type": "string"}},
                    "register": {"anyOf": [{"type": "string", "enum": list(REGISTERS)}, {"type": "null"}]},
                    "topics": {"type": ["array", "null"], "items": {"type": "string", "enum": list(TOPICS)}},
                    "note": {"type": ["string", "null"]},
                },
                "required": ["word_key", "definition_short", "definition_full", "example", "synonyms", "register", "topics", "note"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["words"],
    "additionalProperties": False,
}

GEMINI_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "words": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "word_key": {"type": "STRING"},
                    "definition_short": {"type": "STRING", "nullable": True},
                    "definition_full": {"type": "STRING", "nullable": True},
                    "example": {"type": "STRING", "nullable": True},
                    "synonyms": {"type": "ARRAY", "items": {"type": "STRING"}, "nullable": True},
                    "register": {"type": "STRING", "enum": list(REGISTERS), "nullable": True},
                    "topics": {"type": "ARRAY", "items": {"type": "STRING", "enum": list(TOPICS)}, "nullable": True},
                    "note": {"type": "STRING", "nullable": True},
                },
                "required": ["word_key", "definition_short", "definition_full", "example", "synonyms", "register", "topics", "note"],
            },
        }
    },
    "required": ["words"],
}


class DailyQuotaExhaustedError(Exception):
    """Raised when the daily quota (RPD or API quota) is exhausted."""
    pass


class Sustained429Error(Exception):
    """Raised when sustained 429 / rate limits persist after retries."""
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


def _request(client, model: str, batch: list[dict]) -> list[dict]:
    """Anthropic request handler (unchanged)."""
    payload = [{k: v for k, v in src.items() if k not in ("headword_norm", "inflections")} for src in batch]
    response = client.messages.create(
        model=model,
        max_tokens=16000,
        system=SYSTEM,
        messages=[{"role": "user", "content": json.dumps(payload, ensure_ascii=False)}],
        output_config={"format": {"type": "json_schema", "schema": SCHEMA}},
    )
    text = next(b.text for b in response.content if b.type == "text")
    wanted = {src["word_key"] for src in batch}
    return [o for o in json.loads(text)["words"] if o.get("word_key") in wanted]


def _request_gemini(client, model: str, batch: list[dict], rate_limiter: RateLimiter | None = None) -> list[dict]:
    """Gemini request handler with structured outputs and 429 exponential backoff."""
    from google.genai import types

    payload = [{k: v for k, v in src.items() if k not in ("headword_norm", "inflections")} for src in batch]
    contents = json.dumps(payload, ensure_ascii=False)

    max_retries = 5
    for attempt in range(max_retries + 1):
        if rate_limiter:
            rate_limiter.acquire()
        try:
            config = types.GenerateContentConfig(
                system_instruction=SYSTEM,
                response_mime_type="application/json",
                response_schema=GEMINI_SCHEMA,
            )
            response = client.models.generate_content(
                model=model,
                contents=contents,
                config=config,
            )
            text = getattr(response, "text", "") or ""
            wanted = {src["word_key"] for src in batch}
            return [o for o in json.loads(text)["words"] if o.get("word_key") in wanted]
        except Exception as e:
            msg = str(e)
            code = getattr(e, "code", None) or getattr(e, "status_code", None)
            is_429 = (code == 429 or "RESOURCE_EXHAUSTED" in msg or "429" in msg or "quota" in msg.lower())

            # Daily quota exhaustion check
            if "per day" in msg.lower() or "daily" in msg.lower():
                raise DailyQuotaExhaustedError(f"Daily quota exhausted: {msg}")

            if is_429:
                if attempt >= max_retries:
                    raise Sustained429Error(f"Sustained 429 rate limit after {max_retries} retries: {msg}")

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

                sleep_s = retry_after if retry_after is not None else min(60.0, (2.0 ** (attempt + 1))) + random.uniform(0.5, 2.0)
                print(f"  [429 rate limit] backing off for {sleep_s:.1f}s (retry {attempt + 1}/{max_retries})...", flush=True)
                time.sleep(sleep_s)
                continue
            else:
                raise


def generate(
    inputs: list[dict],
    model: str,
    cache_path: Path,
    client=None,
    provider: str = "anthropic",
    rpm: int | None = None,
    rpd: int | None = None,
) -> list[dict]:
    """Rewrite every word in `inputs`; append each result to the cache and return them.
    A failed batch is retried one word at a time, then given up on."""
    load_env_file()

    if provider == "anthropic":
        import anthropic

        client = client or anthropic.Anthropic()
        batches = [inputs[i: i + BATCH] for i in range(0, len(inputs), BATCH)]
        results: list[dict] = []

        def run(batch: list[dict]) -> list[dict]:
            try:
                return _request(client, model, batch)
            except (anthropic.APIError, json.JSONDecodeError, StopIteration, KeyError) as e:
                print(f"  batch of {len(batch)} failed ({type(e).__name__}); retrying individually", flush=True)
            out = []
            for src in batch if len(batch) > 1 else []:
                try:
                    out += _request(client, model, [src])
                except (anthropic.APIError, json.JSONDecodeError, StopIteration, KeyError) as e:
                    print(f"  {src['word_key']}: {type(e).__name__}: {e}", flush=True)
            return out

        cache_path.parent.mkdir(parents=True, exist_ok=True)
        with open(cache_path, "a", encoding="utf-8") as cache, concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
            done = 0
            for outputs in pool.map(run, batches):
                for o in outputs:
                    rec = {"word_key": o["word_key"], "model": model,
                           "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"), "output": o}
                    cache.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    results.append(rec)
                cache.flush()
                done += 1
                if done % 10 == 0 or done == len(batches):
                    print(f"  {done}/{len(batches)} batches, {len(results):,} records", flush=True)
        return results

    elif provider == "gemini":
        from google import genai
        from google.genai import errors

        api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        if client is None:
            if not api_key:
                raise ValueError("No Gemini API key found. Set GEMINI_API_KEY in .env or the environment.")
            client = genai.Client(api_key=api_key)

        effective_rpm = rpm or int(os.environ.get("GEMINI_RPM", 15))
        effective_rpd = rpd or int(os.environ.get("GEMINI_RPD", 1500))
        rate_limiter = RateLimiter(rpm=effective_rpm, rpd=effective_rpd)

        batches = [inputs[i: i + BATCH] for i in range(0, len(inputs), BATCH)]
        results: list[dict] = []
        cache_path.parent.mkdir(parents=True, exist_ok=True)

        start_time = time.time()
        words_done = 0
        total_words = len(inputs)

        def run_gemini_batch(batch: list[dict]) -> list[dict]:
            try:
                return _request_gemini(client, model, batch, rate_limiter)
            except (DailyQuotaExhaustedError, Sustained429Error):
                raise
            except (errors.APIError, json.JSONDecodeError, StopIteration, KeyError, ValueError) as e:
                print(f"  batch of {len(batch)} failed ({type(e).__name__}); retrying individually", flush=True)
            out = []
            for src in batch if len(batch) > 1 else []:
                try:
                    out += _request_gemini(client, model, [src], rate_limiter)
                except (DailyQuotaExhaustedError, Sustained429Error):
                    raise
                except (errors.APIError, json.JSONDecodeError, StopIteration, KeyError, ValueError) as e:
                    print(f"  {src['word_key']}: {type(e).__name__}: {e}", flush=True)
            return out

        with open(cache_path, "a", encoding="utf-8") as cache:
            for b_idx, batch in enumerate(batches, 1):
                try:
                    outputs = run_gemini_batch(batch)
                except (DailyQuotaExhaustedError, Sustained429Error) as e:
                    remaining_words = total_words - words_done
                    print(f"\n[QUOTA STOPPED] {e}")
                    print(f"Clean exit: {words_done:,} words processed in this run, {remaining_words:,} words remaining.")
                    print(f"All progress saved to {cache_path}. Re-run once quota resets.")
                    raise

                for o in outputs:
                    rec = {"word_key": o["word_key"], "model": model,
                           "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"), "output": o}
                    cache.write(json.dumps(rec, ensure_ascii=False) + "\n")
                    results.append(rec)
                    words_done += 1
                cache.flush()

                elapsed = time.time() - start_time
                remaining_words = total_words - words_done
                rate = (words_done / elapsed) if elapsed > 0 else 0.0
                eta_s = (remaining_words / rate) if rate > 0 else 0.0
                eta_str = str(dt.timedelta(seconds=int(eta_s)))
                print(f"  [progress] done: {words_done:,}/{total_words:,} | remaining: {remaining_words:,} | "
                      f"batch {b_idx}/{len(batches)} | rate: {rate*60:.1f} words/min | ETA: {eta_str}", flush=True)

        return results

    else:
        raise ValueError(f"Unknown provider: {provider}. Must be 'anthropic' or 'gemini'.")
