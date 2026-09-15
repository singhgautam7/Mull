# Dictionary build pipeline

Builds `assets/db/dictionary.db.gz`, the read-only dictionary Mull ships. This
is run by hand, not by the app and not by the Flutter build (rule D6). Its
output is committed as a binary asset: update it deliberately, never casually,
and bump `--version` when you do so the app knows to reinstall.

## Inputs

Download these yourself into `raw/` (gitignored). The script never fetches.

| file | source | licence | provides |
|---|---|---|---|
| `kaikki.org-dictionary-English.jsonl.gz` (~500 MB) | https://kaikki.org/dictionary/English/ | CC BY-SA 4.0 | definitions, POS, IPA (RP preferred), examples, British/US spellings, topic categories, register tags, idioms |
| `SUBTLEX-UK_all.xlsx` (~32 MB) | van Heuven et al. 2014. The CRR site is offline; the Wayback Machine holds it: `http://web.archive.org/web/2022id_/http://crr.ugent.be/papers/SUBTLEX-UK_all.xlsx` | research use | `freq_rank` and the spoken side of the spoken/written ratio |
| `bnc-written.num.gz` (~5 MB) | https://www.kilgarriff.co.uk/BNClists/written.num.gz | BNC | the written side of the ratio |
| `english-wordnet-2024.xml.gz` (~13 MB) | https://en-word.net/static/english-wordnet-2024.xml.gz | CC BY 4.0 | synonyms only. WordNet glosses are never used as definition text. |

## Setup

```bash
cd tools/build_dictionary
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
```

## Build

Sample (what is committed today; ~5,000 headwords, 200 idioms, 4 MB):

```bash
.venv/bin/python build_dictionary.py --sample 5000 --min-collection-size 10
```

Full build:

```bash
.venv/bin/python build_dictionary.py --version 2026.10.1
```

The first run streams the whole Wiktionary extract once (a few minutes) and
caches the slimmed entries in `work/stage1.jsonl.gz`; later runs reuse it.
Pass `--rescan` after downloading a newer extract. `--out-dir` defaults to
`../../assets/db` and writes both `dictionary.db.gz` and `dictionary.version`.

Expect the full build at roughly 40,000 headwords, 100 MB uncompressed and
35 MB gzipped; the 3 s install budget on a mid-range phone should be checked
against the real number when it lands.

Self-checks: `.venv/bin/python test_build.py`.

## Stages

1. Parse the extract, English entries only, single-token words with a
   vocabulary POS plus multi-word entries tagged idiomatic.
2. Drop senses tagged obsolete, archaic, rare, historical, dated, form-of,
   alt-of, abbreviations, misspellings, vulgar, offensive; drop proper nouns,
   taxonomic names and place-name categories; drop entries with no usable
   definition. Words with no frequency rank, or ranked below `--max-rank`
   (40,000), are dropped.
3. British spelling as the headword: of the entry word and its UK-tagged
   alternatives, the one SUBTLEX-UK counts most often wins. The US spelling
   becomes an `aliases` row of kind `us_spelling`; inflections become
   `inflection` rows; other variants `variant`.
4. Up to 4 senses per (headword, POS). `definition_short` is capped at 15
   words, cut at a clause boundary, never mid-word; `definition_full` keeps
   the whole gloss.
5. Up to 2 examples per sense that contain the headword (or an inflection),
   are modern text (no long-s, no ellipses), 20 to 160 characters. Usage
   examples beat quotations.
6. `freq_rank` is the headword's rank by SUBTLEX-UK count aggregated over
   headword + US spelling + inflections. `band`: core < 5k, everyday 5k to
   10k, well_read 10k to 20k, uncommon 20k to 40k.
7. Idioms: Wiktionary's idiomatic multi-word entries, 2 to 8 words, every
   content word ranked, an example present, no vulgar or dated tag. Scored by
   the rarest word's rank; capped by `curation/idioms.yaml` (1,500) and forced
   in or out from the same file.
8. Emit `dictionary.db` from `schema.sql`, rebuild `words_fts` (unicode61)
   and `words_trigram` (trigram), `VACUUM`, gzip.
9. Print the build report.

## Collections

Two axes, two code paths (never merged):

- **Band** collections are derived from `freq_rank`. No curation.
- **Topic** collections are assembled in `build_topic_collections` from four
  signals, applied in order, with the producing signal written to
  `collection_words.source`:
  1. `wiktionary_topic`: kaikki `topics` and `categories` on the sense
  2. `register`: kaikki sense tags such as formal, informal, colloquial
  3. `freq_ratio`: `log10(spoken per million) - log10(written per million)`
     per headword, SUBTLEX-UK against BNC written. Thresholds: Daily Use
     >= +0.35 within core/everyday; Professional Words <= -0.50 within
     everyday/well_read. The report prints the distribution.
  4. `manual`: `curation/collections.yaml` include/exclude, which always win.

`curation/collections.yaml` is the explicit mapping file for signals 1 and 2
and the last-mile curation for signal 4. Every collection is capped
(default 400, most frequent members win) and rejected below `min_size`
(default 40; the sample build lowers it to 10). One sense per headword per
collection: the sense that carried the tag, or the primary sense for the
frequency signal.

`word_tags` retains every raw tag, topic and category on every shipped sense.
Nothing reads it in v1; it is what lets a new themed collection be added
later without reprocessing the source.

## Curating

Edit `curation/collections.yaml` or `curation/idioms.yaml`, rebuild, read the
per-signal breakdown in the report. If signal 1 produced 5% of a collection,
the topic/category mapping for it is wrong: fix the mapping, not the include
list. Forced idioms must be spelled exactly as Wiktionary spells them
("sit on the fence", not "on the fence"); the report lists any it cannot find.
