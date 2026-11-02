# 02: Tracer bullet: add a Source and see its Entries in /feed.rss

**What to build:** The thinnest complete path from a Source to the Aggregate Feed. The operator runs `sources:add[URL,NAME]`. This creates the Source and fetches it immediately. Each item in an RSS 2.0 Source is stored as an Entry, identified within its Source by the item's guid. `GET /feed.rss` returns a valid RSS 2.0 Aggregate Feed of all Entries, newest first by published date. Each item carries:
- the Entry's original title and link
- a stable guid that is not a permalink
- a pubDate
- the author, when present
- `<source url="…">` with the Source's name
- the Entry's content as the description, with HTML passed through unchanged

Entries store their title, link, author, published date, first-seen time, summary and content. This ticket establishes both test seams from the spec: fetching a Source with HTTP stubbed by WebMock and fixture feeds, and request specs on `/feed.rss`.

Glossary terms (Source, Entry, Aggregate Feed) are used for models and modules. See the spec: `.scratch/rss-aggregator/spec.md`.

**Blocked by:** 01 (Remove Kamal, add feedjira and WebMock, document the jobs worker)

**Status:** ready-for-agent

- [ ] A Source has a unique URL and an optional name. `sources:add` rejects a URL that is already registered and prints a clear message.
- [ ] `sources:add` fetches the new Source synchronously and prints how many Entries were stored.
- [ ] Fetching an RSS 2.0 fixture stores one Entry per item, with title, link, author, published date, first-seen time, summary and content.
- [ ] Entries are unique per (Source, guid), so fetching the same fixture twice doesn't create repeats.
- [ ] `GET /feed.rss` responds with an RSS content type and well-formed RSS 2.0, with Entries ordered newest first by published date.
- [ ] Each item has the original title and link, a guid that stays the same across requests, pubDate, `<source url>` with the Source's name, and the content in the description with HTML preserved.
- [ ] The Aggregate Feed needs no authentication.
- [ ] Specs exist at both seams: fetching a Source, with WebMock and a fixture, and a `/feed.rss` request spec that parses the XML.
