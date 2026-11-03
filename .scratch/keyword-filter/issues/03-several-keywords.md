# 03: Several Keywords

**What to build:** A feed reader subscribes to `/feed.rss?keyword=ruby%20on%20rails,elixir` and gets Originals matching *any* of the Keywords. Each comma-separated item is trimmed and matched as a literal phrase. Blank and repeated items are dropped, and at most 20 Keywords are applied. The channel title names the applied Keywords, e.g. `RSS Aggregator: ruby on rails, elixir`, so several narrowed subscriptions can be told apart (see ADR 0002 and the **Keyword** glossary entry).

**Blocked by:** 01 (Tracer bullet: one Keyword narrows the Aggregate Feed)

**Status:** ready-for-agent

- [ ] `keyword=ruby,elixir` returns Originals matching "ruby" and Originals matching "elixir", newest first, each once
- [ ] `keyword=ruby on rails` matches the phrase, not an Original that only has "ruby" and "rails" apart
- [ ] Whitespace around items is trimmed; blank items (`ruby,,elixir`, trailing comma) and repeats (`ruby,Ruby`) are ignored
- [ ] Only the first 20 Keywords after removing blanks and repeats are applied
- [ ] If none of the Keywords has any searchable words, the feed is unfiltered
- [ ] FTS syntax in any item is treated as plain text and never causes an error
- [ ] With Keywords applied, the channel title is the configured title, then `: `, then the applied Keywords joined with `, `; without Keywords it's unchanged
- [ ] Paging links keep the `keyword` parameter
- [ ] Tests go through the Aggregate Feed request spec only
