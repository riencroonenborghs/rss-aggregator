# 03: Atom Sources, identity fallbacks, in-place updates and date rules

**What to build:** Make ingestion robust to real-world Sources:
- **Atom:** Atom Sources work just like RSS.
- **Identity:** an item with no guid is identified by its link, and failing that by a hash of its title and published date.
- **Updates:** when a Source changes an existing item's title or content, the stored Entry is updated in place. It keeps its published date, first-seen time and position in the Aggregate Feed.
- **Dates:** an item with no published date, or one in the future, is treated as published at the moment it was first seen.
- **Backlog:** items published more than 30 days ago are skipped at ingest, so adding a Source with a long backlog doesn't flood the database.

**Blocked by:** 02 (Tracer bullet: add a Source and see its Entries in /feed.rss)

**Status:** ready-for-agent

- [ ] An Atom fixture is ingested into Entries with the same fields as RSS.
- [ ] Identity is used in this order: guid / Atom id, then link, then a hash of title + date. Re-fetching a guid-less fixture creates no repeats.
- [ ] When an item is re-fetched with a changed title or content, the existing Entry is updated. Its published date, first-seen time and order in `/feed.rss` stay the same.
- [ ] Items with a missing or future published date are stored with the published date set to the first-seen time.
- [ ] Items published more than 30 days before the fetch are not stored.
- [ ] All of the above are covered by specs at the fetch-a-Source seam.
