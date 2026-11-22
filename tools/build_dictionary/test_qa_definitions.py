"""Pytest suite for qa_definitions.py (Stage 1 deterministic checks)."""
from pathlib import Path
import pytest

from qa_definitions import (
    QAChecker,
    get_roots,
    tokenize,
    DEFAULT_TOP_N_FREQUENCY,
    DEFAULT_SHORT_DEF_MAX_WORDS,
    DEFAULT_FULL_DEF_MAX_WORDS,
)

DB_PATH = Path(__file__).resolve().parent / "work" / "dictionary.db"
WORDNET_PATH = Path(__file__).resolve().parent / "raw" / "english-wordnet-2024.xml.gz"


@pytest.fixture(scope="module")
def checker():
    """Initialise QAChecker instance against dictionary.db and WordNet."""
    return QAChecker(
        db_path=DB_PATH,
        wordnet_path=WORDNET_PATH,
        top_n_frequency=DEFAULT_TOP_N_FREQUENCY,
        short_def_max_words=DEFAULT_SHORT_DEF_MAX_WORDS,
        full_def_max_words=DEFAULT_FULL_DEF_MAX_WORDS,
    )


# Fixtures that MUST be flagged as circular (R3)
MUST_BE_FLAGGED_CIRCULAR = [
    ("whimsical", "Given to whimsy.", "Given to whimsy."),
    ("whimsically", "In a whimsical manner", "In a whimsical manner"),
    ("insolently", "In an insolent manner.", "In an insolent manner."),
    ("transcription", "The process of converting spoken words into written text.", "The act or process of transcribing, or converting spoken or signed language to a written form."),
    ("candidacy", "The state of being a candidate running for an elected position.", "The period during which a person campaigns and competes against others for a political office."),
    ("captaincy", "The position of a leader or captain.", "The status or role of being a captain, often in a team or on a ship."),
    # 20 real circular cases from data
    ("abasedly", "In an abased manner; abjectly.", "In an abased manner; abjectly."),
    ("abasement", "The act of abasing, humbling, or bringing low.", "The act of abasing, humbling, or bringing low."),
    ("abashedly", "In an abashed manner.", "In an abashed manner."),
    ("abashlessly", "In an abashless, unabashed manner: unabashedly.", "In an abashless, unabashed manner: unabashedly."),
    ("abatement", "The act of abating, or the state of being abated; a lessening.", "The act of abating, or the state of being abated; a lessening."),
    ("abdication", "The act of abdicating; the renunciation of high office.", "The act of abdicating; the renunciation of high office."),
    ("abduction", "The act of abducing or abducting; a drawing apart.", "The act of abducing or abducting; a drawing apart."),
    ("aberrance", "State of being aberrant; a wandering from the right way.", "State of being aberrant; a wandering from the right way."),
    ("aberrantly", "In an aberrant manner; abnormally.", "In an aberrant manner; abnormally."),
    ("abetment", "The act of abetting or assisting in a crime.", "The act of abetting or assisting in a crime."),
    ("abetting", "The act of one who abets.", "The act of one who abets."),
    ("abhorrency", "Quality of being abhorrent; feeling of abhorrence.", "Quality of being abhorrent; feeling of abhorrence."),
    ("abidance", "The act of abiding or continuing; abode; stay.", "The act of abiding or continuing; abode; stay."),
    ("abidingly", "In an abiding manner; permanently.", "In an abiding manner; permanently."),
    ("ability", "The quality or state of being able; capacity to do.", "The quality or state of being able; capacity to do."),
    ("abjectness", "The state of being abject; abasement; meanness.", "The state of being abject; abasement; meanness."),
    ("abjugation", "The act of abjugating. An unyoking, freeing, or uncoupling.", "The act of abjugating. An unyoking, freeing, or uncoupling."),
    ("abjuration", "The act of abjuring.", "The act of abjuring."),
    ("abnormality", "The state or quality of being abnormal; variation.", "The state or quality of being abnormal; variation."),
    ("abnormally", "In an abnormal manner; in a way that deviates.", "In an abnormal manner; in a way that deviates."),
]


@pytest.mark.parametrize("headword,short_def,full_def", MUST_BE_FLAGGED_CIRCULAR)
def test_must_be_flagged_circular(checker, headword, short_def, full_def):
    """Verify that circular fixtures from the prompt and real data are strictly flagged under R3."""
    family = checker.get_family_words(headword, f"{headword}|noun|1")
    rank = checker.hw_ranks.get(headword, 50000)
    failures = checker.check_r3_circular(short_def, full_def, headword, family, rank)
    assert len(failures) > 0, f"Expected circular failures for '{headword}', but got none"


# Negative cases: must NOT be flagged as circular (whole-token matching & non-family letter sharing)
MUST_NOT_BE_FLAGGED_CIRCULAR = [
    # "the" is not a match inside "theatre"
    ("the", "A grand theatre with many actors on stage.", "A grand theatre with many actors on stage."),
    # "moth" is not a match inside "mother"
    ("moth", "A loving mother cares for a young child.", "A loving mother cares for a young child."),
    # "broth" is not a match inside "brother"
    ("broth", "My brother visited the local market.", "My brother visited the local market."),
    # "sing" is not a match inside "single"
    ("sing", "A single tree stood in the vast open field.", "A single tree stood in the vast open field."),
    # "cat" is not a match inside "cattle"
    ("cat", "Healthy cattle grazed along the wide river valley.", "Healthy cattle grazed along the wide river valley."),
    # "pan" is not a match inside "panic"
    ("pan", "Sudden panic spread through the crowded room.", "Sudden panic spread through the crowded room."),
    # "bar" is not a match inside "bark"
    ("bar", "The rough bark protected the ancient oak.", "The rough bark protected the ancient oak."),
    # "arm" is not a match inside "army"
    ("arm", "A strong army protected the border regions.", "A strong army protected the border regions."),
    # Non-circular patterns where target is simpler and not a family word
    ("abseil", "To descend a vertical drop in a controlled manner.", "To descend a vertical drop in a controlled manner."),
    ("ocular", "Relating to the eye and vision.", "Relating to the eye and vision."),
]


@pytest.mark.parametrize("headword,short_def,full_def", MUST_NOT_BE_FLAGGED_CIRCULAR)
def test_must_not_be_flagged_circular(checker, headword, short_def, full_def):
    """Verify whole-token matching: substring letter sharing must never flag non-family words."""
    family = checker.get_family_words(headword, f"{headword}|noun|1")
    rank = checker.hw_ranks.get(headword, 1000)
    failures = checker.check_r3_circular(short_def, full_def, headword, family, rank)
    assert len(failures) == 0, f"False positive circular flag for '{headword}': {failures}"


def test_tokenization_boundaries():
    """Verify tokenization respects word boundaries."""
    tokens = tokenize("The moth flew into mother's theatre!")
    assert "the" in tokens
    assert "moth" in tokens
    assert "theatre" in tokens
    assert "mother's" in tokens or "mother" in tokens


def test_get_roots_preserves_non_family_distinctions():
    """Ensure suffix stripping never confuses words that merely share letters."""
    assert "moth" not in get_roots("mother")
    assert "mother" not in get_roots("moth")
    assert "the" not in get_roots("theatre")
    assert "theatre" not in get_roots("the")
    assert "broth" not in get_roots("brother")
    assert "sing" not in get_roots("single")
    assert "cat" not in get_roots("cattle")


def test_r2_plain_words_flags_harder_words(checker):
    """Test R2 flags content words outside top 3000 and harder than headword."""
    # "petulant" current definition has hard words: "childishly", "irritable", "petty"
    short_def = "Childishly irritable or prone to petty complaints."
    rank = checker.hw_ranks.get("petulant", 25894)
    failures = checker.check_r2_plain_words(short_def, "petulant", rank)
    assert any("irritable" in f for f in failures)
    assert any("petty" in f for f in failures)


def test_r4_length_caps(checker):
    """Test R4 flags definitions exceeding short and full length caps."""
    # 15 words > 14 max
    long_short = "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen."
    # 26 words > 25 max
    long_full = " ".join([f"word{i}" for i in range(26)])

    failures = checker.check_r4_length(long_short, long_full)
    assert any("definition_short" in f for f in failures)
    assert any("definition_full" in f for f in failures)

    # Within bounds
    ok_short = "A valid short definition."
    ok_full = "A completely valid full definition under twenty five words."
    assert len(checker.check_r4_length(ok_short, ok_full)) == 0


def test_r6_clean_synonyms(checker):
    """Test R6 flags synonyms that are the headword or family words."""
    family = checker.get_family_words("whimsical", "whimsical|adj|1")
    # Synonyms including the headword itself and a family word
    synonyms = ["playful", "whimsical", "whimsy", "quirky"]
    failures = checker.check_r6_synonyms(synonyms, "whimsical", family)
    assert any("headword" in f for f in failures)
    assert any("whimsy" in f for f in failures)
    assert not any("playful" in f for f in failures)
    assert not any("quirky" in f for f in failures)
