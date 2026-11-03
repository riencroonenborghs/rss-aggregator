# 01: Tracer bullet: one Keyword narrows the Aggregate Feed

**What to build:** A feed reader subscribes to `/feed.rss?keyword=rails` and gets only the Originals whose title, or whose text as the reader sees it (content, falling back to summary, HTML stripped), contains "rails" as a whole word, ignoring case and accents. Results are newest first and paged like the unfiltered feed, and the paging links keep the Keyword. Without a Keyword the feed is unchanged. Entries already stored are matchable as soon as this is deployed. See ADR 0002 and the spec in `.scratch/keyword-filter/spec.md`.

Scope for this slice: the plain-text column on Entry, the FTS5 external-content table with the `unicode61` tokenizer, the **insert** trigger only, the backfill in the migration, and a single Keyword quoted as a literal phrase. Update and delete triggers are ticket 02. Several Keywords and the channel title are ticket 03.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] `?keyword=rails` returns Originals whose title contains "Rails", "rails" or "RAILS"
- [x] It returns Originals whose content contains the word, and Originals without content whose summary contains it
- [x] An Original with content isn't matched on its summary alone
- [x] Matching is whole-word and without stemming: `ai` doesn't match "said"; `rails` doesn't match "rail"
- [x] Matching ignores accents: `cafe` matches "café"
- [x] HTML is ignored: `href` and `strong` don't match an Original whose markup contains them; entities are decoded before matching
- [x] A Duplicate whose title matches doesn't appear, and doesn't pull in its Original when the Original itself doesn't match
- [x] Results are newest first and paged at the existing page size; `self`, `next` and `previous` links keep `keyword=`
- [x] FTS syntax in the Keyword (`"`, `*`, `-`, `NEAR`, `OR`) is treated as plain text and never causes an error
- [x] A blank or missing `keyword`, or one with no searchable words (`++`), returns the unfiltered feed
- [x] The FTS virtual table appears in the schema file
- [x] The migration fills the plain-text column for existing Entries and rebuilds the index; checked by hand against a development database with Entries
- [x] Tests go through the Aggregate Feed request spec only
