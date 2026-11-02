Status: ready-for-agent

# Spec: RSS Aggregator

## Problem Statement

I follow many blogs and news sites that each publish their own RSS or Atom feed. Subscribing to all of them individually in a feed reader is tedious, the same story often shows up several times when multiple Sources cover it, and I have no single URL I can point any reader at to get everything I follow. I want one place that pulls all my Sources, keeps a short rolling history, and republishes it as a single feed, without me curating or filtering content.

## Solution

A small Rails app that:

- Keeps a list of Sources, managed from the command line with rake tasks.
- Every 30 minutes fetches each Source politely (conditional GET), parses RSS or Atom, and stores the Entries it finds.
- Detects when an Entry from one Source is the same story as an Entry already seen from another Source, stores it as a Duplicate of that Original, and keeps it out of the output.
- Keeps Entries for 30 days (by published date) and discards older ones.
- Exposes one public, paginated RSS 2.0 Aggregate Feed at `/feed.rss`, newest first, with each item attributed to its Source.

There is no filtering: every Original from every Source appears in the Aggregate Feed.

## User Stories

### Managing Sources

1. As the operator, I want to add a Source by URL with a rake task, so that its Entries start appearing in the Aggregate Feed.
2. As the operator, I want to optionally give a Source a name when adding it, so that I control how it's attributed.
3. As the operator, I want a Source's name to default to the Source's own feed title when I don't give one, so that I don't have to type names for every Source.
4. As the operator, I want a newly added Source to be fetched immediately, so that I can see straight away whether the URL works.
5. As the operator, I want adding a Source whose URL is already registered to be rejected with a clear message, so that I don't end up with the same Source twice.
6. As the operator, I want to remove a Source by URL with a rake task, so that it stops contributing to the Aggregate Feed.
7. As the operator, I want removing a Source to delete its Entries, so that its content disappears from the Aggregate Feed.
8. As the operator, I want a story that was an Original from a removed Source, but also had a Duplicate from another Source, to stay in the Aggregate Feed via that other Source, so that removing one Source doesn't hide stories still covered elsewhere.
9. As the operator, I want to list all Sources with their name, URL, last fetch time, last error and Entry count, so that I can see at a glance which Sources are healthy.

### Fetching

10. As the operator, I want every Source fetched automatically every 30 minutes, so that the Aggregate Feed stays current without manual effort.
11. As the operator, I want each Source fetched independently, so that one slow or broken Source doesn't delay or break the others.
12. As the operator, I want Sources in RSS (0.9x/1.0/2.0) and Atom formats to be accepted, so that I can follow sites that only publish Atom.
13. As the operator, I want the aggregator to send conditional GET headers (ETag / Last-Modified) from the previous fetch, so that unchanged Sources cost almost nothing and I'm a well-behaved client.
14. As the operator, I want a 304 Not Modified response to be treated as a successful fetch with no new Entries, so that unchanged Sources don't look broken.
15. As the operator, I want the aggregator to identify itself with a clear User-Agent, so that Source owners can tell who is fetching.
16. As the operator, I want a failed fetch (timeout, 4xx/5xx, unparseable content) to record the error and when it happened on the Source, so that I can diagnose it later.
17. As the operator, I want a failed fetch to leave that Source's existing Entries untouched, so that a temporary outage doesn't remove content.
18. As the operator, I want a failed Source to be retried on the next regular cycle, so that transient failures heal themselves.
19. As the operator, I want a successful fetch to clear the previous error, so that the Source list reflects the current state.

### Entries

20. As the operator, I want each Entry to keep its title, link, author, published date, first-seen time, summary and full content, so that the Aggregate Feed can republish it faithfully.
21. As the operator, I want an Entry to be identified within its Source by the Source's guid / Atom id, so that re-fetching the same Source doesn't create repeats.
22. As the operator, I want a Source item without a guid to be identified by its link, and failing that by a hash of title and published date, so that badly formed Sources still don't create repeats.
23. As the operator, I want an Entry whose title or content changes at the Source to be updated in place, so that corrections show up.
24. As a reader, I want an updated Entry to keep its original position in the Aggregate Feed, so that edits don't resurface old stories at the top.
25. As the operator, I want Entries published more than 30 days ago to be skipped at ingest, so that adding a Source with a long backlog doesn't flood the database.
26. As the operator, I want an Entry with no published date, or a published date in the future, to be treated as published when it was first seen, so that ordering and retention stay sensible.

### Duplicates

27. As a reader, I want the same story from two different Sources to appear only once in the Aggregate Feed, so that I don't read it twice.
28. As the operator, I want two Entries from different Sources to count as the same story when their normalised links are equal, so that tracking parameters, scheme, `www.` and trailing slashes don't defeat detection.
29. As the operator, I want two Entries from different Sources to count as the same story when their normalised titles are at least 90% similar, are at least about four words long, and were published within three days of each other, so that the same story under slightly different headlines is caught without merging generic titles like "Weekly links".
30. As the operator, I want a Duplicate to be stored and to point to its Original, so that a wrong merge can be inspected and undone.
31. As the operator, I want a Duplicate always to point to the root Original, never to another Duplicate, so that there are no chains.
32. As the operator, I want incoming Entries compared only with Originals, so that detection stays simple and predictable.
33. As the operator, I want Entries within the same Source never to be treated as Duplicates of each other, so that the publisher's own guid stays authoritative.
34. As a reader, I want the Original (the first-seen Entry) to be the one shown in the Aggregate Feed, so that the story keeps its first position.

### Retention

35. As the operator, I want Entries whose published date is more than 30 days ago to be deleted automatically, so that the database stays small.
36. As the operator, I want Duplicates deleted together with their Original, so that a story doesn't reappear a month later through a late Duplicate.

### Aggregate Feed

37. As a reader, I want a single RSS 2.0 feed at `/feed.rss`, so that I can subscribe to everything with one URL in any reader.
38. As a reader, I want the Aggregate Feed to be public with no authentication, so that every feed reader can subscribe.
39. As a reader, I want Entries ordered newest first by published date, so that recent stories are on top.
40. As a reader, I want the Aggregate Feed to show only Originals, so that Duplicates never appear.
41. As a reader, I want 100 Entries per page, with later pages at `/feed.rss?page=N`, so that the feed stays a reasonable size.
42. As a reader whose feed reader supports it, I want RFC 5005 next/prev paging links on each page, so that my reader can walk the whole history.
43. As a reader, I want a page number beyond the last page to return a valid, empty feed, so that readers don't error.
44. As a reader, I want each item's title and link to be the Entry's original title and link, so that I land on the publisher's site.
45. As a reader, I want each item to name its Source in the RSS `<source>` element, so that I know where it came from.
46. As a reader, I want each item's description to be the Entry's full content, falling back to its summary, so that I can read as much as the Source offers.
47. As a reader, I want the Source's HTML passed through unchanged, so that formatting and images are preserved.
48. As a reader, I want each item's guid to be stable across fetches and updates, so that my reader doesn't show the same item as new again.
49. As the operator, I want the Aggregate Feed's channel title, link and description to come from app config with sensible defaults, so that I can brand it without database setup.

### Operations

50. As a developer, I want the job worker to start with the rest of the dev processes, so that fetching works locally without extra steps.
51. As the operator, I want the README to document that production needs a separate long-running jobs process (managed via systemd), so that I don't forget it and end up with a feed that never updates.
52. As the operator, I want Kamal-related files and gems removed, so that the repo reflects how it is actually deployed.

## Implementation Decisions

### Domain model

- **Source**: URL (unique), name (optional at creation, filled from the Source's own title on first successful fetch if blank), ETag, Last-Modified, last fetched at, last error message, last error at.
- **Entry**: belongs to a Source. Stores the Source's identifier for the item (guid / Atom id, or link, or a title+date hash, in that order of preference), title, link, normalised link, normalised title, author, published at, first seen at, summary, content (HTML), and an optional reference to its Original (`duplicate_of`).
  - Unique on (Source, identifier).
  - `published_at` is always set: if the Source gives none or a future date, use first seen at.
  - An Entry with no `duplicate_of` is an Original; one with `duplicate_of` set is a Duplicate. A Duplicate's `duplicate_of` always points at an Original.
  - Indexes to support: ordering Originals by published at (the Aggregate Feed query), lookup by normalised link among Originals, and Originals within a published-at window (title similarity candidates).
- The glossary terms (Source, Entry, Duplicate, Original, Aggregate Feed) are used throughout for model, module and method names.

### Modules

- **Source fetcher** (deep module, primary inbound seam): given a Source, performs one fetch end to end.
  - Sends conditional GET headers and a User-Agent; uses sensible timeouts and follows redirects.
  - On 304: records the fetch time, leaves Entries alone.
  - On success: parses with **feedjira**, updates stored ETag/Last-Modified, fills the Source name if blank, and upserts each item via the Entry ingestor. Clears the last error.
  - On failure (network, HTTP error, parse error): records the error message and time on the Source; does not raise into the job; existing Entries untouched.
- **Entry ingestor**: given a Source and a parsed item, decides identity, skips items published more than 30 days ago, creates or updates the Entry in place (an update keeps published at, first seen at and Duplicate status as they were), and asks the duplicate detector about new Entries only.
- **Duplicate detector**: given a new Entry, finds a matching Original from a *different* Source, or none. The rules are in ADR 0001:
  - Link rule: normalised links equal. Normalisation lowercases the host, ignores the scheme and a leading `www.`, and strips the trailing slash, `utm_*` query params and the fragment.
  - Title rule: normalised titles (lowercased, punctuation and extra whitespace removed) of at least ~4 words, Levenshtein similarity relative to length ≥ 0.9, published within 3 days of each other.
  - Compares only against Originals. A Levenshtein implementation can be a small in-house function or a gem; either is fine as long as it's behind this module.
- **Retention**: deletes Entries whose published at is more than 30 days ago, and their Duplicates along with them.
- **Source removal**: deletes a Source and its Entries. For each of the Source's Originals that has Duplicates, the earliest-seen Duplicate becomes the new Original and the remaining Duplicates are re-pointed to it.
- **Aggregate Feed**: controller + RSS 2.0 builder at `GET /feed.rss`, optional `page` param (default 1, page size 100).
  - Lists Originals newest first by published at.
  - Channel metadata comes from app config (`config.x.aggregate_feed`: title, link, description) with defaults such as "RSS Aggregator".
  - Includes an `atom:link rel="self"` link, plus `rel="next"`/`rel="prev"` paging links (RFC 5005) when those pages exist.
  - Per item: title, link, guid (stable per Entry and not a permalink, e.g. derived from the Entry's id), pubDate, author when present, `<source url="…">name</source>`, and a description containing the content (falling back to the summary), passed through as HTML (CDATA/escaped as RSS requires).
  - A page beyond the last returns a valid empty channel.

### Jobs and scheduling

- A recurring Solid Queue task every 30 minutes enqueues one fetch job per Source.
- The fetch job calls the Source fetcher.
- A recurring retention task (e.g. daily) calls Retention.
- In development, a `jobs: bin/jobs` line is added to the dev Procfile. In production, the operator runs `bin/jobs` under systemd; the README documents this.

### Rake tasks

- `sources:add[URL,NAME]`: creates the Source and fetches it synchronously, printing the result or error. Rejects a duplicate URL.
- `sources:remove[URL]`: calls Source removal.
- `sources:list`: prints name, URL, last fetched at, last error and Entry count.

### Dependencies and cleanup

- Add `feedjira` (and an HTTP client if needed beyond Net::HTTP). Add `webmock` to the test group.
- Remove the `kamal` and `thruster` gems, the Kamal deploy config and secrets directory, `Dockerfile` and `.dockerignore`. Don't add Capistrano; the operator owns deployment.

## Testing Decisions

- Tests check external behaviour through the two seams only: what Entries exist after a fetch, and what `/feed.rss` returns. They don't check internal method calls, private helpers, or which module did the work. That way the Entry ingestor, duplicate detector and normaliser can be refactored freely.
- **Seam 1: fetch a Source.** Specs create a Source, stub HTTP with WebMock serving fixture RSS 2.0 and Atom files, run the Source fetcher, and assert on stored Entries and Source state. They cover:
  - RSS and Atom parsing
  - identity: guid, then link, then hash fallback
  - re-fetch idempotence
  - in-place update, keeping published at and position
  - skipping items older than 30 days
  - missing and future dates
  - Duplicates by normalised link (tracking params, scheme, `www.`, trailing slash)
  - Duplicates by fuzzy title, and non-matches: a short generic title, a gap of more than 3 days, the same Source
  - no chains
  - 304 handling and the conditional headers being sent
  - the User-Agent being sent
  - error recording for timeout, 500 and invalid XML, with existing Entries intact
  - error clearing on success
  - a blank name being filled from the Source title
- **Seam 2: `GET /feed.rss` request specs.** Seed Entries directly, request the feed, and parse the XML response. They cover:
  - valid RSS 2.0
  - content type
  - newest-first order
  - Duplicates excluded
  - 100 Entries per page, `page=N`, and an empty page past the end
  - self/next/prev links being present or absent correctly
  - the `<source>` element
  - description fallback from content to summary
  - HTML preserved
  - stable guids
  - channel metadata from config
- **Retention** and **Source removal** are tested by running the operation and then asserting through the seams, usually by checking `/feed.rss` and the remaining Entries. That covers Duplicates being deleted with their Original, and promotion of the earliest Duplicate with the others re-pointed.
- **Rake tasks and recurring jobs** get a smoke test at most: the task runs and calls through, and the recurring config contains the schedule.
- Prior art: none yet. The repo has only the generated `spec_helper` / `rails_helper`. These specs set the pattern: RSpec request specs for HTTP, and RSpec specs with WebMock and fixture files for fetching.

## Out of Scope

- Any content filtering, keyword rules, or per-Source inclusion rules.
- More than one Aggregate Feed, or per-Source feeds as output.
- Atom or JSON Feed output.
- A web UI for managing Sources, and any authentication.
- Per-Source fetch intervals, automatic disabling of broken Sources, and notifications or alerts.
- Detecting duplicates within a single Source, or comparing descriptions.
- Sanitising or rewriting Source HTML.
- Deployment configuration (Capistrano or systemd units); the operator handles these manually.
- Read/unread state or any per-reader features.

## Further Notes

- The domain vocabulary is in `GLOSSARY.md`; the duplicate rules and their rationale are in `docs/adr/0001-cross-source-duplicate-detection.md`.
- The database is SQLite. The duplicate detector's title rule needs only Originals within a ±3-day published window, so the candidate set per new Entry stays small and Levenshtein can run in Ruby.
- Most feed readers ignore RFC 5005 paging, so page 1 is what nearly every subscriber sees.
