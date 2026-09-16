# Dictionary build pipeline (v2)

Builds `assets/db/dictionary.db.gz`, the read-only dictionary Mull ships. This
is run by hand, not by the app and not by the Flutter build (rule D6). Its
output is committed as a binary asset: update it deliberately, never casually,
and bump `--version` when you do so the app knows to reinstall.

Two datasets share the `words` table and follow different rules:

| | Lookup dictionary | Learning set |
|---|---|---|
| Purpose | "what does this mean?" | "what should I show you?" |
| Size | ~136,000 headwords | ~7,000 words (`in_learning_set = 1`) |
| Curation | none; completeness is the requirement | heavy; quality is the requirement |
| Definitions | Wiktionary, lightly cleaned | LLM-rewritten from the Wiktionary material, QA-gated |

A word missing from lookup is a bug of the highest severity: `curation/coverage.txt`
lists 544 common-but-not-trivial words and the build fails if any does not resolve.

## Inputs

Download these yourself into `raw/` (gitignored). The script never fetches.

| file | source | provides |
|---|---|---|
| `kaikki.org-dictionary-English.jsonl.gz` (~500 MB) | https://kaikki.org/dictionary/English/ (CC BY-SA 4.0) | definitions, POS, IPA (RP preferred), examples, British/US spellings, tags, idioms and their etymologies |
| `SUBTLEX-UK_all.xlsx` (~32 MB) | van Heuven et al. 2014; Wayback: `http://web.archive.org/web/2022id_/http://crr.ugent.be/papers/SUBTLEX-UK_all.xlsx` | spoken frequency (`zipf_spoken`, `freq_rank`) |
| `bnc-written.num.gz` (~5 MB) | https://www.kilgarriff.co.uk/BNClists/written.num.gz | written frequency (`zipf_written`) |
| `english-wordnet-2024.xml.gz` (~13 MB) | https://en-word.net/static/english-wordnet-2024.xml.gz (CC BY 4.0) | synonyms, and synset glosses as LLM source material only |
| `WordprevalencesSupplementaryfilefirstsubmission.xlsx` (~8 MB) | Brysbaert, Mandera, McCormick & Keuleers 2019; Wayback: `http://web.archive.org/web/2022id_/http://crr.ugent.be/papers/WordprevalencesSupplementaryfilefirstsubmission.xlsx` | `prevalence` (UK respondents, converted from probit to share known) |
| `AoA_ratings_Kuperman_et_al_BRM.xlsx` (~2 MB) | Kuperman, Stadthagen-Gonzalez & Brysbaert 2012; Wayback: `http://web.archive.org/web/20210507002434id_/http://crr.ugent.be/papers/AoA_ratings_Kuperman_et_al_BRM.zip` (unzip) | `aoa` |
| `Concreteness_ratings_Brysbaert_et_al_BRM.txt` (~2 MB) | Brysbaert, Warriner & Kuperman 2014; Wayback: `http://web.archive.org/web/2022id_/http://crr.ugent.be/papers/Concreteness_ratings_Brysbaert_et_al_BRM.txt` | `concreteness` |
| `Ratings_Warriner_et_al.csv` (~4 MB) | Warriner, Kuperman & Brysbaert 2013; Wayback: `http://web.archive.org/web/2022id_/http://crr.ugent.be/papers/Ratings_Warriner_et_al.csv` | valence, for Politely Damning |

The norms are American-spelled; the pipeline looks a headword up by its US
spelling when the British one is absent.

## Setup

```bash
cd tools/build_dictionary
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

## Build

```bash
export ANTHROPIC_API_KEY=...          # stage C only
.venv/bin/python build_dictionary.py --llm --version 2026.10.1
```

The first run streams the whole Wiktionary extract once (a few minutes) and
caches the slimmed entries in `work/stage1.jsonl.gz`; pass `--rescan` after
downloading a newer extract. Stage C appends every model output to
`work/llm_cache.jsonl`, so a killed run resumes, and a rebuild without `--llm`
re-gates the cached outputs without touching the API. `--llm-limit 40` sends a
handful of words to check the prompt before spending on all of them.

Dev build without an API key (learning words keep their Wiktionary definition,
loudly reported; never ship this):

```bash
.venv/bin/python build_dictionary.py --wiktionary-fallback
```

`--sample N` keeps the whole learning set, the coverage words and the pairs,
plus N random lookup headwords. `--out-dir` defaults to `../../assets/db`.

Self-checks: `.venv/bin/python test_build.py`. The Flutter tests in
`test/database/` read `schema.sql` and the committed asset.

## Stages

**A. Lookup.** Every English entry that is a single lowercase token with a
vocabulary POS. Kept if attested: one appearance in SUBTLEX-UK or the BNC, a
place in any of the norms or WordNet, or a recorded pronunciation. That is not
a frequency cap; it drops the chemistry and taxonomy stubs nobody will look up
(826k Wiktionary headwords become 136k). Redirect stubs (`ran`, `endeavour`,
`organise`) resolve into `aliases`, and a lemma is renamed to its British
spelling when a stub says so or the -ise twin exists. Senses tagged obsolete,
archaic, dated, slang and so on are kept for lookup with the label in the text,
ordered after plain senses, and never lead a learning card. Up to 4 senses per
POS, 1 Wiktionary example per sense. `freq_rank` covers every headword.

**B. Learning set.** Pure arithmetic, tuned against `curation/holdout.yaml`
(100 words that belong, 100 that do not); the report prints precision and
recall. The prevalence norm saturates at 0.995 for ordinary adult vocabulary
("mundane" and "water" score the same), so prevalence only has a floor and the
work is done by the other signals:

| criterion | rule |
|---|---|
| prevalence | >= 0.65 |
| frequency | max(spoken, written) Zipf >= 2.7, spoken Zipf <= 4.0 |
| age of acquisition | >= 11, or unrated and prevalence < 0.97 |
| concreteness | nouns <= 3.5 (things you can point at are not vocabulary to teach) |
| form | a lemma: not an inflection of another headword, not a -ly/-ness derivative |
| topics | not technical in every sense |
| tags | lead sense not old, slang, vulgar, dialect, abbreviation; old-only rejects with prevalence >= 0.65 are kept as `revival` for Old and Worth Reviving |

**C. LLM pass** (`llm_rewrite.py`). Batches of 20 to `--llm-model` (default
`claude-haiku-4-5`), structured JSON output. Every request carries the
Wiktionary senses, WordNet gloss and synonyms, examples and corpus figures; the
model rewrites and is forbidden to invent. Topics come from the closed list in
`build_dictionary.TOPICS`; register from `REGISTERS`. A failed batch is retried
one word at a time. `work/learning_set.jsonl` is the exact input.

**D. QA gates** (`qa_check`). Short definition <= 14 words, no headword or
inflection in it, example 8 to 18 words containing the headword, no em dash or
semicolon, no US spelling (against the `us_spelling` aliases stage A produced),
topics and register from the closed lists, every synonym a lookup headword, and
content-word overlap with the source >= 0.15. A rejected record is regenerated
once with the reasons attached; rejected twice, the word is dropped. Passing
rewrites replace sense 1 (`definition_source = 'llm_rewrite'`), the example goes
first, the synonyms replace WordNet's, and `word_tags` gains `topic:*` and
`register:*`.

**E. Collections.** Bands split the learning set by prevalence (`BAND_CUTS`).
Topic collections are defined in `topic_collections()`: each has a `pick` rule
over the LLM topics and the norms, and a `rank` for when more than 200 qualify
(default: prevalence nearest the middle of the learning band). 80 to 200
members; under 60 is a warning and the collection is not shipped. Idioms:
Everyday is the 150 highest-frequency idioms; Idioms: Odd Origins is the
hand-picked list in `curation/idioms.yaml`, each carrying its Wiktionary
etymology as `origin`. Almost the Same is `curation/pairs.yaml`, stored in
`pairs` with a collection of `kind = 'pairs'` that the app hides until Design
ships a two-word card.

## Report

Printed at the end of every build: lookup counts and coverage; the learning
pool after each filter with holdout precision and recall; the LLM pass with
failure reasons ranked and the 30 lowest-overlap passes; every collection's
size and prevalence distribution; and 40 random cards as the Mull tab would
show them. Read the 40 before shipping. The automated gates catch shape
problems, not taste problems.

## Curating

- `curation/coverage.txt`: words that must resolve. Add to it freely.
- `curation/holdout.yaml`: the filter's yardstick. If it rejects a word that
  belongs, adjust the bounds in `build_dictionary.py`, not the word.
- `curation/idioms.yaml`: `include`, `exclude`, `odd_origins`, spelled as
  Wiktionary spells them (British; the pipeline swaps `color` and friends).
- `curation/pairs.yaml`: Almost the Same.
- Collections themselves live in code (`topic_collections()`), because their
  rules are heterogeneous: a tag, an arithmetic gap, a length.
