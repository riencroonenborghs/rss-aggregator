# 02: Keyword results stay correct as Entries change

**What to build:** Narrowed feeds always reflect the Entries currently stored. An Entry whose title or text is updated by its Source matches its new wording and not its old wording. Entries deleted by the 30-day retention purge or by removing a Source disappear from Keyword results. A Duplicate promoted to Original when its Source's Original is removed becomes matchable. This is done with SQLite update and delete triggers on Entries, so the Entry pruner and Source removal need no code changes (see ADR 0002).

**Blocked by:** 01 (Tracer bullet: one Keyword narrows the Aggregate Feed)

**Status:** done

- [x] After an Entry's title changes, a Keyword matching only the old title no longer returns it, and a Keyword matching the new title does
- [x] The same holds when content or summary changes
- [x] After the Entry pruner runs, expired Entries never appear in Keyword results
- [x] After a Source is removed, its Entries never appear in Keyword results
- [x] After a Source is removed, a Duplicate promoted to Original appears in Keyword results matching its text
- [x] A new Entry created after another was deleted doesn't inherit the deleted Entry's index entry (rowid reuse)
- [x] Neither the Entry pruner nor the Source remover changes
- [x] Tests go through the Aggregate Feed request spec, setting up data via Entry updates, the Entry pruner and the Source remover
