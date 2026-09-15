"""Self-checks for the pipeline's decision logic. Run with:

    .venv/bin/python test_build.py

No framework: plain asserts, so it needs nothing beyond requirements.txt.
"""
from build_dictionary import (
    british_headword,
    build_topic_collections,
    clean_gloss,
    norm,
    short_definition,
)


def word(headword, band="core", rank=100, tags=(), topics=(), categories=()):
    hn = norm(headword)
    return {
        "word_key": f"{hn}|noun|1", "headword": headword, "headword_norm": hn, "pos": "noun",
        "band": band, "freq_rank": rank, "tags": list(tags), "topics": list(topics),
        "categories": list(categories),
    }


def test_norm():
    assert norm("Café-au-Lait!") == "cafe au lait"
    assert norm("naïve") == "naive"
    assert norm("  well-read ") == "well read"


def test_short_definition_cuts_at_a_clause_boundary_never_mid_word():
    long = "To reduce something in amount or size, especially when it is large, and to keep on reducing it over time"
    s = short_definition(long)
    assert len(s.split()) <= 15, s
    assert s.endswith("."), s
    assert "size" in s and "keep" not in s, s
    assert short_definition("Short gloss.") == "Short gloss."
    no_boundary = " ".join(f"w{i}" for i in range(20))
    assert short_definition(no_boundary) == " ".join(f"w{i}" for i in range(15)) + "…"


def test_clean_gloss_strips_leading_labels():
    assert clean_gloss("(transitive, of a storm) to lessen") == "To lessen"


def test_british_headword_is_the_spelling_britons_use():
    color = {"word": "color", "forms": [{"form": "colour", "tags": ["alternative", "Commonwealth"]}]}
    hello = {"word": "hello", "forms": [{"form": "hullo", "tags": ["alternative", "UK"]}]}
    subtlex = {"color": 100, "colour": 5000, "hello": 20000, "hullo": 30}
    assert british_headword(color, subtlex) == ("colour", "color", [])
    assert british_headword(hello, subtlex) == ("hello", None, ["hullo"])


def test_curation_forced_include_and_exclude_win_over_signals():
    words = [
        word("ledger", topics=["finance"]),            # admitted by signal 1
        word("aforementioned", topics=["finance"]),    # excluded by hand
        word("expedite"),                              # no signal at all; forced in
        word("swearword", topics=["finance"], tags=["vulgar"]),  # vetoed tag
        word("rarity", topics=["finance"], band="uncommon"),      # outside bands
    ]
    primary = {w["headword_norm"]: w for w in words}
    cur = {
        "defaults": {"max_size": 400, "min_size": 1, "veto_tags": ["vulgar"]},
        "collections": {
            "money_work": {
                "title": "Money & Work", "description": "", "topics": ["finance"],
                "bands": ["core"], "include": ["expedite"], "exclude": ["aforementioned"],
            }
        },
    }
    defs, members, report = build_topic_collections(cur, words, primary, ratio={}, min_size_override=None)
    got = {w["headword"]: src for w, src in members["money_work"]}
    assert got == {"ledger": "wiktionary_topic", "expedite": "manual"}, got
    assert report["money_work"] == {"wiktionary_topic": 1, "manual": 1}, report


def test_curation_rejects_thin_collections():
    words = [word("ledger", topics=["finance"])]
    cur = {"defaults": {"min_size": 40}, "collections": {
        "money_work": {"title": "t", "description": "", "topics": ["finance"]}}}
    defs, members, report = build_topic_collections(cur, words, {"ledger": words[0]}, ratio={}, min_size_override=None)
    assert defs == [] and "money_work" not in members


def test_freq_ratio_signal_respects_bands_and_thresholds():
    words = [word("chatty", band="core"), word("erudite", band="well_read"), word("meh", band="uncommon")]
    primary = {w["headword_norm"]: w for w in words}
    ratio = {"chatty": 0.9, "erudite": -0.8, "meh": 1.5}
    cur = {"defaults": {"min_size": 1}, "collections": {
        "daily_use": {"title": "d", "description": "", "freq_ratio": {"min": 0.35}, "bands": ["core", "everyday"]},
        "professional_words": {"title": "p", "description": "", "freq_ratio": {"max": -0.5}, "bands": ["everyday", "well_read"]},
    }}
    _, members, _ = build_topic_collections(cur, words, primary, ratio, None)
    assert [w["headword"] for w, _ in members["daily_use"]] == ["chatty"]
    assert [w["headword"] for w, _ in members["professional_words"]] == ["erudite"]


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok", name)
