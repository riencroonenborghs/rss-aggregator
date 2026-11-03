CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "sources" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "url" varchar NOT NULL, "name" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "last_fetched_at" datetime(6) /*application='RssAggregator'*/, "last_error" text /*application='RssAggregator'*/, "last_error_at" datetime(6) /*application='RssAggregator'*/, "etag" varchar /*application='RssAggregator'*/, "last_modified" varchar /*application='RssAggregator'*/);
CREATE UNIQUE INDEX "index_sources_on_url" ON "sources" ("url") /*application='RssAggregator'*/;
CREATE TABLE IF NOT EXISTS "entries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "source_id" integer NOT NULL, "identifier" varchar NOT NULL, "title" varchar, "link" varchar, "author" varchar, "published_at" datetime(6) NOT NULL, "first_seen_at" datetime(6) NOT NULL, "summary" text, "content" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "normalised_link" varchar, "duplicate_of_id" integer, "normalised_title" varchar /*application='RssAggregator'*/, "plain_text" text /*application='RssAggregator'*/, CONSTRAINT "fk_rails_950b6b299d"
FOREIGN KEY ("source_id")
  REFERENCES "sources" ("id")
, CONSTRAINT "fk_rails_e5da441707"
FOREIGN KEY ("duplicate_of_id")
  REFERENCES "entries" ("id")
);
CREATE INDEX "index_entries_on_source_id" ON "entries" ("source_id") /*application='RssAggregator'*/;
CREATE UNIQUE INDEX "index_entries_on_source_id_and_identifier" ON "entries" ("source_id", "identifier") /*application='RssAggregator'*/;
CREATE INDEX "index_entries_on_published_at" ON "entries" ("published_at") /*application='RssAggregator'*/;
CREATE INDEX "index_entries_on_duplicate_of_id" ON "entries" ("duplicate_of_id") /*application='RssAggregator'*/;
CREATE INDEX "index_entries_on_normalised_link" ON "entries" ("normalised_link") /*application='RssAggregator'*/;
CREATE VIRTUAL TABLE entries_fts USING fts5 (title, plain_text, content='entries', content_rowid='id', tokenize='unicode61 remove_diacritics 2')
/* entries_fts(title,plain_text) */;
CREATE TABLE IF NOT EXISTS 'entries_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'entries_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'entries_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'entries_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TRIGGER entries_fts_after_insert AFTER INSERT ON entries BEGIN
  INSERT INTO entries_fts (rowid, title, plain_text) VALUES (new.id, new.title, new.plain_text);
END;
INSERT INTO "schema_migrations" (version) VALUES
('20261103090000'),
('20261103004235'),
('20261103003347'),
('20261103002503'),
('20261102235737'),
('20261102235736');

