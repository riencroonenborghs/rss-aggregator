Status: ready-for-agent

# Spec: Keywords

## Problem Statement

The Aggregate Feed carries every Original from every Source. When I only care about one topic, say Rails or Elixir, I have to scroll through everything to find it, and I can't point a feed reader at a URL that only carries that topic.

## Solution

The Aggregate Feed can be narrowed by one or more Keywords given in the URL: `/feed.rss?keyword=ruby%20on%20rails,elixir`. Only Originals whose title, or whose text as the reader sees it (content, falling back to summary), contains any of the Keywords as whole words are returned. They are still newest first and paged the same way. The channel title names the Keywords, so several narrowed subscriptions can be told apart in a feed reader. Without a Keyword the feed is unchanged.

## User Stories

1. As a feed reader user, I want to add `?keyword=rails` to the Aggregate Feed URL, so that I only see Originals about Rails.
2. As a feed reader user, I want a Keyword to match an Original's title, so that headlines about the topic are included.
3. As a feed reader user, I want a Keyword to match an Original's content, so that stories that mention the topic in the body are included.
4. As a feed reader user, I want a Keyword to match an Original's summary when it has no content, so that the text I can actually read is what's searched.
5. As a feed reader user, I want a summary that is hidden because content is present to be ignored, so that every match shows up in what I can read.
6. As a feed reader user, I want matching to ignore case, so that `rails` matches "Rails" and "RAILS".
7. As a feed reader user, I want matching to ignore accents, so that `cafe` matches "café".
8. As a feed reader user, I want matching to be whole-word, so that `ai` doesn't match "said" or "rain".
9. As a feed reader user, I want no stemming, so that `rails` doesn't match "rail" or "railing".
10. As a feed reader user, I want HTML markup ignored, so that `href` or `div` doesn't match every Original, and a word that only appears in a link's URL doesn't count.
11. As a feed reader user, I want HTML entities decoded before matching, so that `AT&amp;T` in the markup matches the text "AT&T".
12. As a feed reader user, I want only Originals in a narrowed feed, so that the same story isn't shown twice.
13. As a feed reader user, I want a Duplicate's text never to pull its Original into the results, so that what matches is what I see.
14. As a feed reader user, I want narrowed results newest first, so that the feed reads in time order like the unfiltered one.
15. As a feed reader user, I want narrowed results paged like the unfiltered feed, so that my reader can walk the history.
16. As a feed reader user, I want the `self`, `next` and `previous` links to keep the Keywords, so that page 2 is still narrowed.
17. As a feed reader user, I want to give several Keywords separated by commas, so that one subscription covers related topics.
18. As a feed reader user, I want an Original matching any one of several Keywords to be included, so that a list reads as "any of these".
19. As a feed reader user, I want a Keyword with spaces to match as a phrase, so that `ruby on rails` matches that phrase, not each word anywhere.
20. As a feed reader user, I want whitespace around each Keyword trimmed, so that `ruby, elixir` works like `ruby,elixir`.
21. As a feed reader user, I want empty and repeated Keywords ignored, so that `ruby,,ruby` works like `ruby`.
22. As a feed reader user, I want FTS syntax characters (`*`, `"`, `-`, `NEAR`, `OR`) treated as plain text, so that an odd Keyword never breaks the feed.
23. As a feed reader user, I want a blank or missing `keyword` to give the full Aggregate Feed, so that existing subscriptions keep working.
24. As a feed reader user, I want Keywords with no searchable words (e.g. `++`) to give the full Aggregate Feed, so that I get a feed rather than an error.
25. As the operator, I want at most 20 Keywords applied, with any beyond that ignored, so that one URL can't produce an unbounded query.
26. As a feed reader user, I want the channel title to name the Keywords that were applied (`RSS Aggregator: ruby on rails, elixir`), so that I can tell my narrowed subscriptions apart.
27. As a feed reader user, I want an Entry whose title or text is updated by its Source to match its new wording and not its old wording, so that results reflect the current story.
28. As a feed reader user, I want Entries removed by retention to disappear from narrowed feeds, so that old stories don't linger.
29. As the operator, I want Entries of a removed Source to disappear from narrowed feeds, so that removing a Source is complete.
30. As a feed reader user, I want a Duplicate promoted to Original when its Source's Original is removed to be matchable, so that the story stays findable.
31. As the operator, I want Entries stored before this feature to be matchable as soon as it's deployed, so that narrowed feeds aren't empty for up to 30 days.

## Implementation Decisions

- See ADR 0002 (Keyword matching with SQLite FTS5) and the **Keyword** and **Aggregate Feed** entries in the glossary.
- **Plain-text column on Entry**: a new column holding the text the reader sees (content, falling back to summary), with HTML removed and entities decoded. It is kept up to date by Entry itself whenever content or summary is assigned, the same way the normalised title and link are.
- **FTS5 index**: an external-content FTS5 virtual table over Entry's title and the plain-text column, with the `unicode61` tokenizer (accents removed, no stemming). It is created through Rails' virtual-table support so it is dumped in the schema file.
- **Index sync by SQLite triggers** on insert, update and delete of Entries. They fire on `delete_all`, so retention pruning and Source removal need no code changes.
- **Every Entry is indexed**, Duplicates included. The feed query combines the FTS match with the existing Originals scope and keeps the existing newest-first ordering and offset paging.
- **Backfill**: the migration fills the plain-text column for existing Entries and runs FTS5's `rebuild`.
- **Keyword parsing** (from the `keyword` query parameter): split on commas, trim, drop blanks, drop repeats, keep the first 20. Each Keyword is escaped and quoted as a literal FTS5 phrase, and the phrases are joined with OR. If no Keyword has any searchable words, the feed is unfiltered.
- **Channel title**: when Keywords apply, the configured title is followed by `: ` and the applied Keywords joined with `, `.
- **Paging links** carry the `keyword` parameter as given.

## Testing Decisions

- A good test checks behaviour from the outside: request the feed and check which items, paging links and channel title come back. Tests do not inspect the FTS table, the triggers or the plain-text column directly.
- **One seam**: the Aggregate Feed request spec. Data is set up through Entry and the existing services (Entry updates, the Entry pruner, the Source remover), then the feed is requested with a `keyword`.
- **Prior art**: the existing Aggregate Feed request spec (Nokogiri item and paging-link helpers, Entry factories via `source.entries.create!`, `insert_all!` for paging volume), and the Entry pruner and Source remover specs for setting up Duplicates and expiry.
- **The migration's backfill** isn't tested automatically. It's checked by hand by running the migration against a development database that already has Entries and then making a keyword request.

## Out of Scope

- Ranking by relevance.
- Stemming, prefix or wildcard matching, and FTS query syntax supplied by users.
- AND or NOT combinations of Keywords.
- Matching on author or Source name.
- Matching Duplicates' text.
- Saved or named Keyword subscriptions, or any UI for them.
- Correct matching of symbol-heavy terms like `c++`: they match their word parts only, e.g. "c".

## Further Notes

- `unicode61` treats punctuation as a separator, so a Keyword like `c++` reduces to "c". This is an accepted limitation.
