# RSS Aggregator

Pulls Entries from many Sources and republishes them, unfiltered, as a single Aggregate Feed.

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
The one RSS 2.0 feed the aggregator exposes, made of Entries from all Sources, newest first.
_Avoid_: Feed, output, combined feed
