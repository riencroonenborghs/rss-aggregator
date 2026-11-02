# RSS Aggregator

Pulls Entries from many Sources (RSS and Atom feeds) and republishes them, unfiltered, as a single RSS 2.0 Aggregate Feed at `/feed.rss`. Domain vocabulary is in `GLOSSARY.md`; architectural decisions are in `docs/adr/`.

## Requirements

- Ruby (see `.ruby-version`)
- SQLite 3
- Node, yarn and bun (for asset builds)

## Setup

```sh
bin/setup
```

## Development

```sh
bin/dev
```

This starts the web server, the JS and CSS watchers, and the Solid Queue job worker (`bin/jobs`) from `Procfile.dev`.

## Tests

```sh
bundle exec rspec
```

Real HTTP is blocked in tests by WebMock; stub every request a spec makes.

## Production

Deployment is managed manually by the operator.

Fetching Sources and pruning old Entries run as Solid Queue jobs, so production needs **two long-running processes**:

1. The web server (`bin/rails server`)
2. The job worker (`bin/jobs`), e.g. as a systemd unit

If `bin/jobs` isn't running, nothing will be fetched and the Aggregate Feed will never update.
