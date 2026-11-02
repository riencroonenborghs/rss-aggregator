# Cross-Source duplicate detection

The aggregator does no filtering, but the same story often appears in several Sources. Entries from different Sources are therefore treated as Duplicates when their normalised links are equal (host lowercased; scheme, `www.`, trailing slash, `utm_*` params and fragment ignored), or when their normalised titles are at least 90% similar by length-relative Levenshtein distance, are at least ~4 words long, and were published within 3 days of each other. Duplicates are stored and point to the first-seen Original; only Originals appear in the Aggregate Feed. Within a single Source, the publisher's guid is the only identity.

## Considered Options

- **Comparing descriptions with Levenshtein**: rejected. It is O(n²)-ish against recent Entries, and noisy, because excerpts of the same story differ a lot between Sources while unrelated short summaries can look close.
- **Exact title match**: rejected. Generic titles ("Weekly links") from unrelated Sources would collide.
- **Discarding Duplicates at ingest**: rejected. Keeping them makes wrong merges reversible and debuggable.

## Consequences

- Duplicates always point to the root Original (no chains), and incoming Entries are compared only against Originals.
- Retention deletes Duplicates together with their Original.
- Removing a Source promotes the earliest Duplicate of each affected Original to be the new Original.
