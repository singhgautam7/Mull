"""Self-checks for the pipeline's decision logic. Run with:

    .venv/bin/python test_build.py

No framework: plain asserts, so it needs nothing beyond requirements.txt.
"""
from build_dictionary import (
    BAND_CUTS,
    LEARNING_MIN_PREVALENCE,
    NON_DOMINANT_POS_DISCOUNT,
    NON_PRIMARY_SENSE_DISCOUNT,
    TOPICS,
    band_of,
    british_headword,
    build_collections,
    clean_etymology,
    clean_gloss,
    contains_headword,
    is_uk_spelling_of,
    keep_sense,
    norm,
    make_slot_pattern,
    build_phrases,
    phrase_collections,
    qa_check,
    select_learning_set,
    short_definition,
)


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


def test_clean_etymology_keeps_prose_after_the_tree_and_a_colon():
    assert clean_etymology("Etymology tree\nLatin x\nEnglish y\nFrom Latin.\nMore.") == "From Latin."
    assert clean_etymology("The OED suggests the following:\nA bucket was a beam.\nIgnored.") == \
        "The OED suggests the following: A bucket was a beam."


def test_british_headword_is_the_spelling_britons_use():
    color = {"word": "color", "forms": [{"form": "colour", "tags": ["alternative", "Commonwealth"]}]}
    hello = {"word": "hello", "forms": [{"form": "hullo", "tags": ["alternative", "UK"]}]}
    subtlex = {"color": 100, "colour": 5000, "hello": 20000, "hullo": 30}
    assert british_headword(color, subtlex) == ("colour", "color", [])
    assert british_headword(hello, subtlex) == ("hello", None, ["hullo"])


def test_uk_spelling_stubs_are_recognised_three_ways():
    assert is_uk_spelling_of("endeavour", "endeavor", set(), "British standard ")
    assert is_uk_spelling_of("randomisation", "randomization", {"alt-of"}, "Alternative spelling of randomization")
    assert is_uk_spelling_of("organise", "organize", {"UK"}, "")
    assert not is_uk_spelling_of("randomize", "randomise", set(), "US and Oxford British English standard ")
    assert not is_uk_spelling_of("color", "colour", set(), "")


def test_keep_sense_drops_stubs_but_keeps_labelled_senses():
    stub = {"glosses": ["Non-Oxford British standard spelling of organize."], "tags": [], "categories": []}
    old = {"glosses": ["Foolish; silly."], "tags": ["obsolete"], "categories": []}
    place = {"glosses": ["A town in Kent."], "tags": [], "categories": ["Places in England"]}
    assert not keep_sense(stub)
    assert keep_sense(old)
    assert not keep_sense(place)


def test_band_is_by_prevalence_then_rank():
    assert band_of(0.99, 50_000) == "core"
    assert band_of(BAND_CUTS[2], 1) == "well_read"
    assert band_of(0.5, 1) == "uncommon"
    assert band_of(None, 100) == "core"
    assert band_of(None, 100_000) == "uncommon"


def row(headword, pos="adj", prevalence=0.9, aoa=13.0, zs=3.0, zw=3.3, conc=2.0, tags=(), topics=()):
    hn = norm(headword)
    return {
        "word_key": f"{hn}|{pos}|1", "headword": headword, "headword_norm": hn, "pos": pos,
        "prevalence": prevalence, "aoa": aoa, "zipf_spoken": zs, "zipf_written": zw, "concreteness": conc,
        "valence": None, "tags": list(tags), "topics": list(topics), "llm_topics": [], "llm_register": None,
        "learning_kind": None, "band": band_of(prevalence, 1000),
    }


class FakeEntry:
    def __init__(self, senses):
        self.senses = senses


def test_learning_filter_keeps_adamant_and_rejects_noodles():
    rows = [
        row("adamant", prevalence=0.94, aoa=14.3, zs=3.5),
        row("noodles", pos="noun", prevalence=0.995, aoa=5.3, zs=3.7, conc=4.9),   # childhood word
        row("water", pos="noun", prevalence=0.995, aoa=2.4, zs=5.5, conc=4.9),     # too common
        row("download", pos="noun", prevalence=0.98, aoa=13.6, zs=3.9, conc=3.6),  # concrete noun
        row("whilom", prevalence=0.07, aoa=None),                                   # nobody knows it
        row("cheapo", prevalence=0.65, aoa=None, tags=["slang"]),
        row("hitherto", pos="adv", prevalence=0.94, aoa=None, tags=["archaic"]),   # revival carve-out
        row("cheerfully", pos="adv", prevalence=0.99, aoa=None),                   # -ly of a headword
        row("cheerful"),
        row("gregarious", prevalence=0.95, aoa=None, zs=2.5, zw=3.1),             # unrated AoA, unsaturated prevalence
        row("ohm", pos="noun", prevalence=0.7, aoa=12.0, topics=["physics"]),
    ]
    primary = {r["headword_norm"]: r for r in rows}
    ent_of = {hn: FakeEntry([{"topics": r["topics"]}]) for hn, r in primary.items()}
    holdout = {"belongs": ["adamant", "gregarious"], "does_not": ["noodles", "water", "download", "whilom", "cheapo"]}
    out, stages = select_learning_set(primary, ent_of, alias_norms=set(), holdout=holdout)
    assert out == {"adamant": "learning", "cheerful": "learning", "gregarious": "learning", "hitherto": "revival"}, out
    assert stages["headwords"] == len(rows)


def test_qa_gates():
    src = {"headword": "adamant", "headword_norm": "adamant", "inflections": [],
           "senses": [{"gloss": "Firm; unshakeable; unyielding; determined."}], "wordnet_gloss": None,
           "wordnet_synonyms": ["unyielding"], "examples": []}
    lookup = {"adamant", "unyielding", "resolute", "firm"}
    good = {"definition_short": "Refusing to be persuaded or to change your mind.",
            "definition_full": "Firm and unyielding in an opinion; refusing to be persuaded or to change your mind.",
            "example": "She was adamant that she would not sell the house to them.",
            "synonyms": ["unyielding", "resolute"], "register": "neutral", "topics": ["describing_people"], "note": None}
    reasons, overlap = qa_check(good, src, lookup, us_spellings={"color"})
    assert reasons == [], reasons
    assert overlap > 0.15
    bad = dict(good, definition_short="Adamantly refusing to change; one who has color in their honor, and more, and more, and more, and more words",
               example="Adamant.", synonyms=["nonsuchword"], topics=["daily_use"], register="posh")
    reasons, _ = qa_check(bad, src, lookup, us_spellings={"color"})
    for expected in ("over 14 words", "contains the headword", "example not 8-18 words", "US spelling: color",
                     "unknown topic: daily_use", "unknown register: posh", "synonym not a headword: nonsuchword"):
        assert any(expected in r for r in reasons), (expected, reasons)
    assert qa_check({"note": "insufficient source"}, src, lookup, set())[0] == ["insufficient source"]


def test_contains_headword_sees_inflections_and_derivatives():
    assert contains_headword("She was adamantly opposed.", "adamant", set())
    assert contains_headword("They ran home.", "run", {"ran", "runs", "running"})
    assert not contains_headword("The cat sat.", "catch", set())


def test_collections_make_their_promise_and_respect_size_bounds():
    rows = [row(f"intense{i}", pos="adj", prevalence=0.7 + i / 1000) for i in range(250)]
    for r in rows:
        r["llm_topics"] = ["intensity"]
    small = [row(f"feel{i}") for i in range(10)]
    for r in small:
        r["llm_topics"] = ["feelings"]
    defs, members = build_collections(rows + small)
    slugs = [d["slug"] for d in defs]
    assert "better_than_very" in slugs and "feelings_without_names" not in slugs, slugs
    assert len(members["better_than_very"]) == 200
    # Ranked by teaching value (prevalence vs written Zipf gap), so the
    # highest teaching value items are kept and lowest are what the cap removed.
    kept = {w["headword"] for w, _ in members["better_than_very"]}
    assert "intense249" in kept and "intense0" not in kept
    assert all(d["kind"] == "band" for d in defs[:4])
    assert all(t.replace("_", "").isalpha() for t in TOPICS)


def test_rare_senses_excluded():
    """Bug 1: Homographs and rare senses take discounts (non-dominant POS discount: 0.70,
    non-primary sense discount: 0.80). Assert that imp|verb|1, citrate|verb|1, and
    outsize|noun|1 are excluded from the learning set."""
    # 1. Prevalence discount arithmetic
    # imp: verb is non-dominant POS (SUBTLEX: noun 37, verb 4), sense 2 in Kaikki
    imp_prev = 0.9508
    imp_verb_eff = imp_prev * NON_DOMINANT_POS_DISCOUNT * NON_PRIMARY_SENSE_DISCOUNT
    assert imp_verb_eff < LEARNING_MIN_PREVALENCE, f"imp verb eff {imp_verb_eff} >= {LEARNING_MIN_PREVALENCE}"

    # citrate: verb is non-dominant POS (SUBTLEX: noun 7, verb 1)
    citrate_prev = 0.793
    citrate_verb_eff = citrate_prev * NON_DOMINANT_POS_DISCOUNT
    assert citrate_verb_eff < LEARNING_MIN_PREVALENCE, f"citrate verb eff {citrate_verb_eff} >= {LEARNING_MIN_PREVALENCE}"

    # outsize: noun is non-dominant POS (SUBTLEX: adj 16, verb 3, noun 2), non-primary
    outsize_prev = 0.970
    outsize_noun_eff = outsize_prev * NON_DOMINANT_POS_DISCOUNT * NON_PRIMARY_SENSE_DISCOUNT
    assert outsize_noun_eff < LEARNING_MIN_PREVALENCE, f"outsize noun eff {outsize_noun_eff} >= {LEARNING_MIN_PREVALENCE}"

    # 2. Verify through select_learning_set
    rows = [
        dict(row("imp", pos="verb", prevalence=imp_prev), prevalence_effective=imp_verb_eff),
        dict(row("citrate", pos="verb", prevalence=citrate_prev), prevalence_effective=citrate_verb_eff),
        dict(row("outsize", pos="noun", prevalence=outsize_prev), prevalence_effective=outsize_noun_eff),
        row("adamant", pos="adj", prevalence=0.94, aoa=14.3, zs=3.5),
    ]
    primary = {r["headword_norm"]: r for r in rows}
    ent_of = {hn: FakeEntry([{"topics": r["topics"]}]) for hn, r in primary.items()}
    holdout = {
        "belongs": ["adamant"],
        "does_not": ["imp (verb)", "citrate (verb)", "outsize (noun)"],
    }
    out, _ = select_learning_set(primary, ent_of, alias_norms=set(), holdout=holdout)
    assert "imp" not in out, f"imp should be excluded: {out}"
    assert "citrate" not in out, f"citrate should be excluded: {out}"
    assert "outsize" not in out, f"outsize should be excluded: {out}"
    assert "adamant" in out, f"adamant should be kept: {out}"


def test_llm_stage_batches_caches_and_retries_individually(tmp=None):
    import json
    import tempfile
    from pathlib import Path
    from types import SimpleNamespace

    import llm_rewrite

    calls = []

    class FakeMessages:
        def create(self, **kw):
            batch = json.loads(kw["messages"][0]["content"])
            calls.append(len(batch))
            if len(batch) > 1 and any(w["word_key"].startswith("bad") for w in batch):
                raise json.JSONDecodeError("boom", "", 0)
            out = [{"word_key": w["word_key"], "definition_short": "x", "definition_full": "y", "example": "z",
                    "synonyms": [], "register": "neutral", "topics": [], "note": None} for w in batch]
            return SimpleNamespace(content=[SimpleNamespace(type="text", text=json.dumps({"words": out}))])

    client = SimpleNamespace(messages=FakeMessages())
    inputs = [{"word_key": f"w{i}|noun|1", "headword": f"w{i}"} for i in range(25)] + [{"word_key": "bad|noun|1", "headword": "bad"}]
    with tempfile.TemporaryDirectory() as d:
        cache = Path(d) / "llm_cache.jsonl"
        recs = llm_rewrite.generate(inputs, "fake-model", cache, client=client)
        assert len(recs) == 26, len(recs)
        # Two batches of 20 and 6; the second fails as a batch and is retried one word at a time.
        assert sorted(calls) == [1] * 6 + [6, 20], calls
        assert len(cache.read_text().splitlines()) == 26
        assert json.loads(cache.read_text().splitlines()[0])["output"]["definition_short"] == "x"
    assert "borrowed_word" in llm_rewrite.SYSTEM and "—" not in llm_rewrite.SYSTEM


def test_score_definition_need_prioritises_worst_entries():
    from build_dictionary import score_definition_need

    clean = {
        "headword": "lucid",
        "senses": [{"gloss": "Clear and easy to understand."}],
        "inflections": ["lucidly"],
    }
    webster = {
        "headword": "betoken",
        "senses": [{"gloss": "To betoken or signify; being an inordinate manifestation of preferment whereof hitherto none spake."}],
        "inflections": ["betokened", "betokens"],
    }
    semicolons = {
        "headword": "abate",
        "senses": [{"gloss": "To lessen; to reduce in amount; to diminish; as, to abate pain."}],
        "inflections": ["abates", "abated"],
    }
    long_def = {
        "headword": "virtue",
        "senses": [{"gloss": "The idea of all that is good or excellent in a human being collectively viewed as a power that makes for righteousness in the world at large."}],
        "inflections": ["virtues"],
    }
    us_spelling = {
        "headword": "candour",
        "senses": [{"gloss": "The state of speaking with real candor and open honesty."}],
        "inflections": [],
    }

    s_clean = score_definition_need(clean)
    s_webster = score_definition_need(webster)
    s_semicolons = score_definition_need(semicolons)
    s_long = score_definition_need(long_def)
    s_us = score_definition_need(us_spelling, us_spellings={"candor"})

    assert s_clean == 0.0, s_clean
    assert s_webster > 20.0, s_webster
    assert s_semicolons > 10.0, s_semicolons
    assert s_long > 1.0, s_long
    assert s_us > 4.0, s_us

    # Test sorting orders highest need first without skipping any
    queue = [clean, webster, semicolons, long_def, us_spelling]
    ordered = sorted(queue, key=lambda w: score_definition_need(w, us_spellings={"candor"}), reverse=True)
    assert len(ordered) == len(queue)
    assert ordered[0]["headword"] == "betoken"
    assert ordered[-1]["headword"] == "lucid"


def test_gemini_stage_batches_caches_and_retries_individually():
    import json
    import tempfile
    from pathlib import Path
    from types import SimpleNamespace

    import llm_rewrite

    calls = []

    class FakeModels:
        def generate_content(self, **kw):
            batch = json.loads(kw["contents"])
            calls.append(len(batch))
            if len(batch) > 1 and any(w["word_key"].startswith("bad") for w in batch):
                raise json.JSONDecodeError("boom", "", 0)
            out = [{"word_key": w["word_key"], "definition_short": "x", "definition_full": "y", "example": "z",
                    "synonyms": [], "register": "neutral", "topics": [], "note": None} for w in batch]
            return SimpleNamespace(text=json.dumps({"words": out}))

    client = SimpleNamespace(models=FakeModels())
    inputs = [{"word_key": f"w{i}|noun|1", "headword": f"w{i}"} for i in range(25)] + [{"word_key": "bad|noun|1", "headword": "bad"}]
    with tempfile.TemporaryDirectory() as d:
        cache = Path(d) / "llm_cache.jsonl"
        recs = llm_rewrite.generate(inputs, "gemini-3.5-flash-lite", cache, client=client, provider="gemini", rpm=120)
        assert len(recs) == 26, len(recs)
        # Two batches of 20 and 6; the second fails as a batch and is retried one word at a time.
        assert sorted(calls) == [1] * 6 + [6, 20], calls
        assert len(cache.read_text().splitlines()) == 26
        assert json.loads(cache.read_text().splitlines()[0])["output"]["definition_short"] == "x"


def test_slot_pattern_and_phrase_collections():
    # 1. Slot patterns
    assert make_slot_pattern("take in", True) == "[take] [someone/something] [in]"
    assert make_slot_pattern("look forward to", True) == "[look] forward [to] [someone/something]"
    assert make_slot_pattern("give up", False) == "[give] up"

    # 2. Phrase collections and floor enforcement
    mock_phrases = []
    # 150 everyday idioms
    for i in range(160):
        mock_phrases.append({
            "phrase_key": f"idiom{i}|idiom|1", "phrase": f"idiom {i}", "phrase_norm": f"idiom {i}",
            "type": "idiom", "meaning": "def", "example": "ex", "register": "everyday",
            "_score": (1, i, 10), "in_learning_set": 1,
        })
    # 100 proverbs
    for i in range(105):
        mock_phrases.append({
            "phrase_key": f"proverb{i}|proverb|1", "phrase": f"proverb {i}", "phrase_norm": f"proverb {i}",
            "type": "proverb", "meaning": "def", "example": "ex", "register": "everyday",
            "usage_note": "note", "_score": (1, i, 10), "in_learning_set": 1,
        })
    # 80 odd origins
    odd_list = []
    for i in range(85):
        p = f"odd {i}"
        odd_list.append(p)
        mock_phrases.append({
            "phrase_key": f"odd{i}|idiom|1", "phrase": p, "phrase_norm": p,
            "type": "idiom", "meaning": "def", "example": "ex", "register": "everyday",
            "origin": "A long origin text explaining where this phrase came from.",
            "_score": (1, i, 10), "in_learning_set": 1,
        })
    # 75 binomials
    for i in range(75):
        mock_phrases.append({
            "phrase_key": f"binomial{i}|binomial|1", "phrase": f"binomial {i}", "phrase_norm": f"binomial {i}",
            "type": "binomial", "meaning": "def", "example": "ex", "register": "everyday",
            "usage_note": "Fixed order", "_score": (1, i, 10), "in_learning_set": 1,
        })
    # 75 borrowed
    for i in range(75):
        mock_phrases.append({
            "phrase_key": f"borrowed{i}|idiom|1", "phrase": f"borrowed {i}", "phrase_norm": f"borrowed {i}",
            "type": "idiom", "meaning": "def", "example": "ex", "register": "everyday",
            "source_language": "la", "_score": (1, i, 10), "in_learning_set": 1,
        })
    # 50 aphorisms
    for i in range(50):
        mock_phrases.append({
            "phrase_key": f"aphorism{i}|aphorism|1", "phrase": f"aphorism {i}", "phrase_norm": f"aphorism {i}",
            "type": "aphorism", "meaning": "def", "example": "ex", "register": "literary",
            "attribution": "Famous Author", "usage_note": "note", "_score": (1, i, 10), "in_learning_set": 1,
        })

    cur = {"idioms": {"odd_origins": odd_list}}
    defs, members = phrase_collections(mock_phrases, cur)
    assert len(defs) == 6
    assert len(members["idioms_everyday"]) >= 60
    assert len(members["sayings_worth_knowing"]) >= 60
    assert len(members["idioms_odd_origins"]) >= 60
    assert len(members["two_words_new_meaning"]) >= 60
    assert len(members["borrowed_whole"]) >= 60
    assert len(members["said_better_by_someone_else"]) >= 40

    # Shortfall raises ValueError
    bad_cur = {"idioms": {"odd_origins": []}}
    try:
        phrase_collections([p for p in mock_phrases if p["type"] != "binomial"], bad_cur)
        assert False, "Should have raised ValueError on shortfall"
    except ValueError as e:
        assert "CRITICAL SHORTFALL" in str(e)


def test_new_shelves_and_four_signals():
    """Verify that the five new shelves:
    1. Are produced by build_collections and have >= 60 members (floor) and <= 200 (cap).
    2. Are NOT alphabetical in their first 10 members.
    3. Include all required seed words.
    4. Attribute each member to one of the 4 signals: wiktionary_category, pos_semantic_tag, stage_c_topic, manual.
    5. Overlap between qualities_and_flaws and describing_people is measured.
    """
    import sqlite3
    from pathlib import Path
    from build_dictionary import NEW_SHELVES, load_curation

    seeds = {
        "faces_and_gestures": ["frown", "wince", "grimace", "smirk", "scowl", "squint", "flinch", "recoil", "beam", "bristle", "slouch", "fidget"],
        "ways_of_saying": ["mutter", "retort", "concede", "quip", "drawl", "snap", "murmur", "insist", "chide", "muse", "stammer"],
        "qualities_and_flaws": ["pedantic", "gregarious", "meticulous", "aloof", "petty", "earnest", "dogged", "glib", "brittle"],
        "setting_a_scene": ["desolate", "cramped", "airy", "dingy", "sprawling", "cavernous", "stifling", "serene"],
        "ways_of_moving": ["amble", "trudge", "dart", "saunter", "lurch", "scurry", "stride", "shuffle"],
    }

    db_path = Path("work/dictionary.db")
    if not db_path.exists():
        return

    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    words = [dict(r) for r in con.execute("SELECT * FROM words WHERE sense_index = 1")]
    primary = {w["headword_norm"]: w for w in words}
    learning_rows = [w for w in words if w.get("in_learning_set") == 1]
    cur = load_curation()

    defs, members = build_collections(learning_rows, cur=cur, primary=primary, all_words=words)
    defs_by_slug = {d["slug"]: d for d in defs}

    valid_signals = {"wiktionary_category", "pos_semantic_tag", "stage_c_topic", "manual"}

    for sh in NEW_SHELVES:
        slug = sh["slug"]
        assert slug in defs_by_slug, f"Missing shelf definition for {slug}"
        assert slug in members, f"Missing members for {slug}"
        shelf_members = members[slug]
        count = len(shelf_members)

        # 1. Floor & Cap
        assert count >= 60, f"Shelf {slug} has {count} members, below floor of 60!"
        assert count <= 200, f"Shelf {slug} has {count} members, above cap of 200!"

        # 2. First 10 NOT alphabetical
        first_10 = [w["headword"] for w, _ in shelf_members[:10]]
        assert first_10 != sorted(first_10), f"Shelf {slug} first 10 members are alphabetical: {first_10}"

        # 3. Seed words present
        member_headwords = {w["headword_norm"] for w, _ in shelf_members}
        for seed in seeds[slug]:
            assert seed in member_headwords, f"Seed word '{seed}' missing from shelf {slug}"

        # 4. Valid signal attribution
        for w, sig in shelf_members:
            assert sig in valid_signals, f"Word {w['headword']} in {slug} has invalid signal: {sig}"

    # 5. Overlap between Qualities and Flaws and Describing People
    qual_words = {w["headword_norm"] for w, _ in members["qualities_and_flaws"]}
    desc_words = {w["headword_norm"] for w, _ in members.get("describing_people", [])}
    if not desc_words:
        desc_words = {r["headword_norm"] for r in con.execute("SELECT w.headword_norm FROM collection_words cw JOIN collections c ON cw.collection_id = c.id JOIN words w ON cw.word_key = w.word_key WHERE c.slug = 'describing_people'")}
    overlap = qual_words & desc_words
    overlap_ratio = len(overlap) / len(qual_words) if qual_words else 0
    assert overlap_ratio < 0.5, f"Overlap too high: {overlap_ratio:.1%}"


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("ok", name)
