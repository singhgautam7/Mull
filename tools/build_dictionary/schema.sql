-- dictionary.db schema. The single source of truth: build_dictionary.py
-- executes this file, and test/database/fake_dictionary.dart reads it to
-- build the fake dictionaries the tests swap between.
--
-- The app opens this database read-only and never writes to it (rule D3).
-- User data references rows by word_key, never by id (rule D4).
--
-- Two datasets share the words table. The lookup dictionary is every attested
-- English word from Wiktionary, lightly cleaned. The learning set
-- (in_learning_set = 1) is the ~5,000-word curated subset the Mull tab plays,
-- whose sense 1 has an LLM-rewritten, QA-gated definition.

CREATE TABLE meta(
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE words(
  id                INTEGER PRIMARY KEY,
  word_key          TEXT NOT NULL UNIQUE,   -- {headword_norm}|{pos}|{sense_index}
  headword          TEXT NOT NULL,          -- British spelling
  headword_norm     TEXT NOT NULL,          -- lowercased, diacritics stripped, no punctuation
  pos               TEXT NOT NULL,
  sense_index       INTEGER NOT NULL,
  definition_short  TEXT NOT NULL,          -- under 15 words, clause-boundary cut; '' when it would equal definition_full
  definition_full   TEXT NOT NULL,
  ipa               TEXT,                   -- RP preferred, null when none recorded
  freq_rank         INTEGER NOT NULL,       -- by SUBTLEX-UK count; unattested words rank last
  band              TEXT NOT NULL,          -- core | everyday | well_read | uncommon, by prevalence
  in_learning_set   INTEGER NOT NULL DEFAULT 0,
  -- Norms are per headword and stored on sense 1 (and learning-set rows) only.
  prevalence        REAL,                   -- share of UK adults who know the word, 0..1
  aoa               REAL,                   -- age of acquisition, years
  zipf_spoken       REAL,                   -- SUBTLEX-UK
  zipf_written      REAL,                   -- BNC written
  concreteness      REAL,                   -- 1..5
  definition_source TEXT,                  -- 'llm_rewrite', or null for Wiktionary text (2.7 MB cheaper than spelling it out)
  generated_at      TEXT                    -- when definition_source = llm_rewrite
);
CREATE INDEX words_headword_norm ON words(headword_norm);

CREATE TABLE examples(
  id       INTEGER PRIMARY KEY,
  word_key TEXT NOT NULL REFERENCES words(word_key),
  text     TEXT NOT NULL
);
CREATE INDEX examples_word_key ON examples(word_key);

CREATE TABLE synonyms(
  id       INTEGER PRIMARY KEY,
  word_key TEXT NOT NULL REFERENCES words(word_key),
  synonym  TEXT NOT NULL
);
CREATE INDEX synonyms_word_key ON synonyms(word_key);

-- US spellings, plurals, inflections and variants, all resolving to a word.
-- WITHOUT ROWID: the primary key is the table, so the 220k rows are stored
-- once rather than as a heap plus a covering index (7 MB). There is no rowid to
-- order by; the app orders inflections by alias_norm.
CREATE TABLE aliases(
  alias_norm TEXT NOT NULL,
  word_key   TEXT NOT NULL REFERENCES words(word_key),
  kind       TEXT NOT NULL,                -- us_spelling | inflection | variant
  PRIMARY KEY(alias_norm, word_key)
) WITHOUT ROWID;
-- usSpelling() and inflections() look aliases up by word; without this they
-- scan the table (8 ms on a laptop, tens on a phone, on every word sheet build).
CREATE INDEX aliases_word_key ON aliases(word_key);

CREATE TABLE phrases(
  id                INTEGER PRIMARY KEY,
  phrase_key        TEXT NOT NULL UNIQUE,
  phrase            TEXT NOT NULL,
  phrase_norm       TEXT NOT NULL,
  type              TEXT NOT NULL,          -- idiom | proverb | simile | phrasal_verb | binomial | aphorism
  meaning           TEXT NOT NULL,
  usage_note        TEXT,                   -- mandatory for proverb, simile, aphorism; optional for others
  example           TEXT,
  register          TEXT NOT NULL,          -- everyday | formal | literary | informal | slang | archaic | pretentious
  origin            TEXT,
  attribution       TEXT,                   -- author / source for aphorisms; null for folklore
  source_language   TEXT,                   -- fr | la | de | it | el | etc.
  slot_pattern      TEXT,                   -- for phrasal verbs: '[verb] [someone] [prep]'
  freq_rank         INTEGER NOT NULL,
  in_learning_set   INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX phrases_phrase_norm ON phrases(phrase_norm);

CREATE VIRTUAL TABLE phrases_fts USING fts5(
  phrase, meaning,
  content='phrases', content_rowid='id',
  tokenize='unicode61'
);

-- Backward compatibility view so existing idiom queries and joins resolve seamlessly.
CREATE VIEW idioms AS
  SELECT
    id,
    phrase_key AS idiom_key,
    phrase,
    phrase_norm,
    meaning,
    example,
    register,
    origin
  FROM phrases;

CREATE TABLE collections(
  id          INTEGER PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  kind        TEXT NOT NULL,               -- band | topic | idiom | pairs
  band        TEXT,                        -- set when kind = band
  icon        TEXT,                        -- glyph name from the 1.75-stroke set
  sort_order  INTEGER NOT NULL
);

-- Members of a collection. word_key is a words.word_key for band and topic
-- collections and an idioms.idiom_key for idiom collections, so there is no
-- foreign key; the app joins on the table the kind implies.
CREATE TABLE collection_words(
  collection_id INTEGER NOT NULL REFERENCES collections(id),
  word_key      TEXT NOT NULL,
  position      INTEGER NOT NULL,
  source        TEXT NOT NULL,             -- band | topic | arithmetic | idiom | manual
  PRIMARY KEY(collection_id, word_key)
);
CREATE INDEX collection_words_word_key ON collection_words(word_key);

-- "Almost the Same": two words and the sentence that separates them. Needs a
-- card variant the app does not have yet; the collection of kind pairs is
-- hidden until it does.
CREATE TABLE pairs(
  id       INTEGER PRIMARY KEY,
  word_a   TEXT NOT NULL REFERENCES words(word_key),
  word_b   TEXT NOT NULL REFERENCES words(word_key),
  note     TEXT NOT NULL
);

-- Full-text search over headword and definition. External content so the
-- text is stored once; rebuilt by the pipeline, never by the app.
-- detail=none drops term positions (no phrase or NEAR queries; the app only
-- ever issues AND-ed prefix tokens) and columnsize=0 drops the per-row size
-- table bm25 reads: together 14 MB. Ranking keeps the same top hits; the tail
-- of the FTS rung can reorder.
CREATE VIRTUAL TABLE words_fts USING fts5(
  headword, definition_full,
  content='words', content_rowid='id',
  tokenize='unicode61', detail=none, columnsize=0
);

-- Trigram index for typo tolerance: the last rung of the search ladder. The
-- pipeline fills it with one row per headword (its first sense), not one per
-- sense, since the fuzzy query only ever keeps sense 1: 7 MB smaller.
CREATE VIRTUAL TABLE words_trigram USING fts5(
  headword_norm,
  content='words', content_rowid='id',
  tokenize='trigram', detail=none, columnsize=0
);
