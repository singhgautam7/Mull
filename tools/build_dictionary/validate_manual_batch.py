"""Helper script to validate and cache manually crafted entries through QAChecker."""
import json
import os
import sqlite3
import sys
from pathlib import Path

# Ensure build_dictionary package directory is in sys.path
_pkg_dir = str(Path(__file__).resolve().parent)
if _pkg_dir not in sys.path:
    sys.path.insert(0, _pkg_dir)

from qa_definitions import QAChecker
from llm_rewrite_v2 import validate_rewrite, RULES_VERSION

def validate_and_cache(entries: list[dict], db_path: Path, cache_path: Path) -> tuple[int, list[tuple[str, list[str]]]]:
    checker = QAChecker(db_path)
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    us_spellings = {
        row[0] for row in cur.execute("SELECT alias_norm FROM aliases WHERE kind = 'us_spelling'")
    }
    con.close()

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    passed_count = 0
    failures = []

    with open(cache_path, "a", encoding="utf-8") as out_f:
        for item in entries:
            output = item["output"]
            entry = item["entry"]
            passed, reasons = validate_rewrite(output, entry, checker, us_spellings)
            if passed:
                rec = {
                    "word_key": entry["word_key"],
                    "rules_version": RULES_VERSION,
                    "model": "chat-assisted-v2",
                    "generated_at": "2026-11-19T14:30:00+00:00",
                    "attempt": 1,
                    "qa_passed": True,
                    "qa_reasons": [],
                    "output": output,
                }
                out_f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                out_f.flush()
                passed_count += 1
            else:
                failures.append((entry["headword"], reasons))

    return passed_count, failures

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python validate_manual_batch.py <batch_json_path>")
        sys.exit(1)

    batch_path = Path(sys.argv[1])
    data = json.loads(batch_path.read_text(encoding="utf-8"))
    db_p = Path(__file__).resolve().parent / "work/dictionary.db"
    cache_p = Path(__file__).resolve().parent / "work/llm_cache.jsonl"
    p_cnt, fails = validate_and_cache(data, db_p, cache_p)
    print(f"Validated and cached: {p_cnt}/{len(data)} passed.")
    if fails:
        print("Failures:")
        for hw, r in fails:
            print(f"  {hw}: {r}")
