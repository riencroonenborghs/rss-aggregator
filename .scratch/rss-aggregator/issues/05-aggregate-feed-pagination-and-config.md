# 05: Aggregate Feed pagination, paging links and channel config

**What to build:** Make the Aggregate Feed complete.
- **Pagination:** `/feed.rss` serves 100 Entries per page, and later pages are at `/feed.rss?page=N`.
- **Paging links:** each page carries an `atom:link rel="self"`, plus RFC 5005 `rel="next"` / `rel="prev"` links when those pages exist. Readers that support paging can walk the whole history.
- **Past the end:** a page number beyond the last page returns a valid, empty channel.
- **Channel metadata:** the channel title, link and description come from app config (`config.x.aggregate_feed`), with defaults such as "RSS Aggregator".
- **Description:** each item's description is the Entry's content, falling back to its summary when there is no content. Source HTML is passed through unchanged.

**Blocked by:** 02 (Tracer bullet: add a Source and see its Entries in /feed.rss)

**Status:** done

- [x] With 250 Entries, page 1 has the 100 newest, `?page=3` has the last 50, and `?page=4` returns a valid, empty RSS 2.0 channel.
- [x] Page 1 has self and next links but no prev link. Middle pages have both. The last page has prev but no next.
- [x] The channel title, link and description come from config, and the defaults apply when the config is unset.
- [x] An Entry with no content uses its summary as the description. HTML in either is preserved and correctly escaped or wrapped in CDATA.
- [x] All of the above are covered by `/feed.rss` request specs.
