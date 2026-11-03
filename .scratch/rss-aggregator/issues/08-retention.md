# 08: Retention

**What to build:** The database keeps a rolling 30-day window. A daily recurring task deletes every Entry whose published date is more than 30 days ago. Duplicates are deleted with their Original, so a story can't reappear a month later through a late Duplicate.

**Blocked by:** 06 (Duplicates by normalised link)

**Status:** done

- [x] The recurring config schedules retention daily (smoke test).
- [x] Running retention deletes Entries published more than 30 days ago and keeps newer ones.
- [x] An Original older than 30 days is deleted together with its Duplicates, even when a Duplicate is newer.
- [x] After retention, `/feed.rss` no longer lists the deleted Entries.
