# Keyword matching with SQLite FTS5

The Aggregate Feed can be narrowed by Keywords (`/feed.rss?keyword=ruby%20on%20rails,elixir`). Matching uses an SQLite FTS5 external-content table over each Entry's title and a stored plain-text copy of the text a reader sees (content, falling back to summary) with HTML stripped and entities decoded in Ruby. SQLite triggers on `entries` keep the index in sync. Every Entry is indexed, Duplicates included; the feed query applies the FTS match together with the `originals` scope. The tokenizer is `unicode61`, without stemming, so matching is case- and accent-insensitive and whole-word. Each comma-separated Keyword is trimmed and quoted as a literal phrase, Keywords are combined with OR, and results stay newest first, not ranked by relevance.

## Considered Options

- **`LIKE '%keyword%'`**: rejected. It matches substrings, so short Keywords ("AI", "Go") match inside other words, and it matches HTML markup.
- **An FTS table written from Ruby callbacks**: rejected. `EntryPruner` and `Source has_many :entries, dependent: :delete_all` delete with `delete_all`, which skips callbacks, so deleted Entries would stay in the index. Triggers fire regardless.
- **Indexing raw HTML content**: rejected. Tag names, attributes and URLs would be indexed as words. SQLite can't strip HTML in a trigger, which is why the plain-text column exists.
- **The `porter` tokenizer**: rejected. Stemming merges terms the reader may want to keep apart and makes matches less predictable.
- **Passing Keywords through as FTS5 query syntax**: rejected. Text in a URL shouldn't be able to change the query or cause a syntax error.

## Consequences

- The primary database's schema is kept in `structure.sql`, not `schema.rb`, because `schema.rb` can't hold triggers. Without them a database built from the schema (test, or a fresh `db:prepare`) would have an index that never fills. Loading and dumping `structure.sql` needs the `sqlite3` command-line tool. The queue, cache and cable databases stay on their own `schema.rb` files.
- Each Entry stores its text twice: as HTML and as plain text. With 30-day retention the cost is small.
- Indexing Duplicates means a Duplicate that `SourceRemover` promotes to Original is searchable without touching the index.
- Any new code path that writes `title`, `content` or `summary` must go through the model so the plain-text column is refreshed. The triggers only copy what's in the row.
