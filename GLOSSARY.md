# RSS Aggregator

Pulls Entries from many Sources and republishes them as a single Aggregate Feed, optionally narrowed by Keywords.

## Language

**Source**:
An external RSS or Atom feed that the aggregator pulls Entries from.
_Avoid_: Feed, input, subscription

**Entry**:
A single piece of content pulled from a Source and stored by the aggregator.
_Avoid_: Item, post, article

**Duplicate**:
An Entry from one Source judged to be the same content as an Entry already seen from a different Source. Duplicates are kept but never appear in the Aggregate Feed.
_Avoid_: Dupe, copy, repeat

**Original**:
The first-seen Entry that one or more Duplicates point to. Every Entry that isn't a Duplicate is an Original.
_Avoid_: Canonical, master, primary

**Aggregate Feed**:
The one RSS 2.0 feed the aggregator exposes, made of Originals from all Sources, newest first. It can be narrowed by one or more Keywords; narrowed or not, it is still the Aggregate Feed.
_Avoid_: Feed, output, combined feed, filtered feed

**Keyword**:
A word or phrase that narrows the Aggregate Feed to Originals whose title or text contains it as whole words, ignoring case. When several Keywords are given, an Original matching any one of them is included.
_Avoid_: Filter, search term, query, tag
