# 06: Duplicates by normalised link

**What to build:** The same story from two different Sources appears only once in the Aggregate Feed. When a new Entry's normalised link equals the normalised link of an Original from a *different* Source, the new Entry is stored as a Duplicate that points to that Original. The Aggregate Feed shows only Originals.

To normalise a link: lowercase the host, ignore http/https and a leading `www.`, and strip the trailing slash, `utm_*` query parameters and the fragment.

Duplicates always point to the root Original, so there are no chains. Incoming Entries are compared only with Originals. Entries within the same Source are never Duplicates of each other. See `docs/adr/0001-cross-source-duplicate-detection.md` and the Duplicate and Original entries in `GLOSSARY.md`.

**Blocked by:** 02 (Tracer bullet: add a Source and see its Entries in /feed.rss)

**Status:** ready-for-agent

- [ ] An Entry from Source B whose link differs from an Original from Source A only by scheme, `www.`, trailing slash, `utm_*` params or fragment is stored as a Duplicate of that Original.
- [ ] A Duplicate always points to an Original. An Entry that matches a Duplicate's link is attached to the Duplicate's Original.
- [ ] Two Entries in the same Source with the same normalised link are both Originals.
- [ ] Updating an existing Entry in place never changes whether it is a Duplicate.
- [ ] `/feed.rss` lists only Originals, and the Duplicate never appears.
- [ ] Covered at both seams: fetching a Source for detection, and `/feed.rss` for hiding Duplicates.
