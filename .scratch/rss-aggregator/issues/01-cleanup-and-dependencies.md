# 01: Remove Kamal, add feedjira and WebMock, document the jobs worker

**What to build:** Clean the generated Rails app so that it matches how it will actually be developed and deployed. Kamal and Thruster go. The feed parser and the HTTP stubbing library are added. In development the job worker starts along with the other processes. The README explains that production needs a separate long-running jobs process, managed by the operator under systemd. Capistrano is not added, because deployment is the operator's job.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] The `kamal` and `thruster` gems are removed, along with the Kamal deploy config, its secrets directory, `Dockerfile` and `.dockerignore`. Nothing else still refers to them, including binstubs and CI.
- [x] `feedjira` is in the app dependencies, and `webmock` is in the test group. WebMock is enabled in the RSpec setup so that real HTTP is blocked in tests.
- [x] The dev Procfile runs `bin/jobs` along with web, js and css.
- [x] The README says that production needs `bin/jobs` running as its own process (for example under systemd), or the Aggregate Feed will never update.
- [x] The app boots, and `bundle exec rspec` runs green with no specs.
