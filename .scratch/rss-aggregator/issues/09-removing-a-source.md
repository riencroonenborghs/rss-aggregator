# 09: Removing a Source

**What to build:** The operator runs `sources:remove[URL]` to stop following a Source. This deletes the Source and all its Entries. When one of its Originals had Duplicates from other Sources, the story stays in the Aggregate Feed. The earliest-seen Duplicate becomes the new Original, and any remaining Duplicates are re-pointed to it.

**Blocked by:** 06 (Duplicates by normalised link)

**Status:** done

- [x] `sources:remove[URL]` deletes the Source and its Entries, and prints a clear message for an unknown URL.
- [x] An Original from the removed Source with Duplicates from Sources B and C: the earliest-seen Duplicate becomes an Original, and the other Duplicate now points to it.
- [x] After removal, `/feed.rss` shows the promoted Entry in place of the removed one, and nothing from the removed Source.
- [x] Removing a Source whose Entries have no Duplicates leaves all other Entries untouched.
