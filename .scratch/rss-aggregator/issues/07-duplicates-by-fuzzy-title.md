# 07: Duplicates by fuzzy title

**What to build:** Catch the same story when it appears under a slightly different headline in another Source. A new Entry is a Duplicate of an Original from a different Source when all of these hold:
- Their normalised titles (lowercased, punctuation and extra whitespace removed) are at least 90% similar by Levenshtein distance relative to length.
- Both titles are at least about four words long.
- They were published within 3 days of each other.

Generic short titles such as "Weekly links" must not be merged. Descriptions are not compared. The link rule from ticket 06 still applies, and either rule matching is enough. See `docs/adr/0001-cross-source-duplicate-detection.md`.

**Blocked by:** 06 (Duplicates by normalised link)

**Status:** ready-for-agent

- [ ] Two Entries from different Sources with near-identical long titles (for example, differing by one word or punctuation) published a day apart: the later one becomes a Duplicate of the earlier Original.
- [ ] The same titles published more than 3 days apart: both are Originals.
- [ ] Identical short generic titles (fewer than ~4 words) from different Sources: both are Originals.
- [ ] Similar titles within the same Source: both are Originals.
- [ ] Candidate Originals are limited to the ±3-day published window, so the comparison doesn't scan every Entry.
- [ ] Covered by specs at the fetch-a-Source seam, and the Duplicate is absent from `/feed.rss`.
