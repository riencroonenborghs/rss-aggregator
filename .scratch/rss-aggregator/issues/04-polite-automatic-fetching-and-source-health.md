# 04: Polite automatic fetching and Source health

**What to build:** Sources are fetched automatically and politely, and the operator can see whether each one is healthy.
- **Schedule:** a recurring Solid Queue task runs every 30 minutes and enqueues one fetch job per Source, so a slow or broken Source can't block the others.
- **Conditional GET:** each fetch sends the ETag and Last-Modified values stored from the previous fetch. A 304 response counts as success with no changes.
- **User-Agent:** fetches identify themselves with a clear User-Agent.
- **Errors:** a timeout, a 4xx/5xx response or unparseable content is recorded on the Source, along with the time it happened. Existing Entries are left untouched, and the next cycle retries. A successful fetch clears the error.
- **Naming:** a Source added without a name takes the Source's own title on its first successful fetch.
- **Listing:** `sources:list` prints each Source's name, URL, last fetch time, last error and Entry count.

**Blocked by:** 02 (Tracer bullet: add a Source and see its Entries in /feed.rss)

**Status:** done

- [x] The recurring config schedules the fetch-all task every 30 minutes, and it enqueues one job per Source (smoke test).
- [x] A fetch sends `If-None-Match` / `If-Modified-Since` when values are stored, and stores the new ones from the response.
- [x] A 304 response updates the last fetch time and changes no Entries.
- [x] Every request sends the configured User-Agent.
- [x] A timeout, a 500 response or invalid XML records the error message and time on the Source, doesn't raise out of the job, and leaves existing Entries intact.
- [x] The next successful fetch clears the recorded error.
- [x] A Source with a blank name gets the Source's title after its first successful fetch.
- [x] `sources:list` prints name, URL, last fetch time, last error and Entry count for every Source.
