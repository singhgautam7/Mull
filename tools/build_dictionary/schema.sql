-- dictionary.db schema. The single source of truth: build_dictionary.py
-- executes this file, and test/database/dictionary_swap_test.dart reads it to
-- build the two fake dictionaries it swaps between.
--
-- The app opens this database read-only and never writes to it (rule D3).
-- User data references rows by word_key, never by id (rule D4).

CREATE TABLE meta(
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE words(
  id               INTEGER PRIMARY KEY,
  word_key         TEXT NOT NULL UNIQUE,   -- {headword_norm}|{pos}|{sense_index}
  headword         TEXT NOT NULL,          -- British spelling
  headword_norm    TEXT NOT NULL,          -- lowercased, diacritics stripped, no punctuation
  pos              TEXT NOT NULL,
  sense_index      INTEGER NOT NULL,
  definition_short TEXT NOT NULL,          -- under 15 words, clause-boundary cut
  definition_full  TEXT NOT NULL,
  ipa              TEXT,                   -- RP preferred, null when none recorded
  freq_rank        INTEGER NOT NULL,
  band             TEXT NOT NULL           -- core | everyday | well_read | uncommon
);
CREATE INDEX words_headword_norm ON words(headword_norm);
CREATE INDEX words_freq_rank ON words(freq_rank);
CREATE INDEX words_band ON words(band, freq_rank);

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
CREATE TABLE aliases(
  alias_norm TEXT NOT NULL,
  word_key   TEXT NOT NULL REFERENCES words(word_key),
  kind       TEXT NOT NULL,                -- us_spelling | inflection | variant
  PRIMARY KEY(alias_norm, word_key)
);

CREATE TABLE idioms(
  id         INTEGER PRIMARY KEY,
  idiom_key  TEXT NOT NULL UNIQUE,
  phrase     TEXT NOT NULL,
  phrase_norm TEXT NOT NULL,
  meaning    TEXT NOT NULL,
  example    TEXT,
  register   TEXT NOT NULL                 -- formal | informal | dated | neutral
);
CREATE INDEX idioms_phrase_norm ON idioms(phrase_norm);

CREATE TABLE collections(
  id          INTEGER PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  kind        TEXT NOT NULL,               -- band | topic | register | exam | idiom
  band        TEXT,                        -- set when kind = band
  icon        TEXT,                        -- glyph name from the 1.75-stroke set
  sort_order  INTEGER NOT NULL
);

CREATE TABLE collection_words(
  collection_id INTEGER NOT NULL REFERENCES collections(id),
  word_key      TEXT NOT NULL REFERENCES words(word_key),
  position      INTEGER NOT NULL,
  source        TEXT NOT NULL,             -- band | wiktionary_topic | register | freq_ratio | manual
  PRIMARY KEY(collection_id, word_key)
);
CREATE INDEX collection_words_word_key ON collection_words(word_key);

-- Raw tags retained for later re-slicing. Nothing reads this in v1; it is what
-- lets a new themed collection be added without reprocessing the source.
CREATE TABLE word_tags(
  word_key TEXT NOT NULL REFERENCES words(word_key),
  tag      TEXT NOT NULL,
  PRIMARY KEY(word_key, tag)
);

-- Full-text search over headword and short definition. External content so
-- the text is stored once; rebuilt by the pipeline, never by the app.
CREATE VIRTUAL TABLE words_fts USING fts5(
  headword, definition_short,
  content='words', content_rowid='id',
  tokenize='unicode61'
);

-- Trigram index for typo tolerance: the last rung of the search ladder.
CREATE VIRTUAL TABLE words_trigram USING fts5(
  headword_norm,
  content='words', content_rowid='id',
  tokenize='trigram'
);
