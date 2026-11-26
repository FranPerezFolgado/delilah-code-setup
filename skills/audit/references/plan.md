# /audit plan

Turns an audit report into work someone can start on. Default input: the newest
`$ROOT/.audit/*/` with a `REPORT.md`.

1. Read `REPORT.md` and `metrics.json` only (the area files when a package needs the
   evidence, one at a time).
2. **Group into work packages by root cause, not by finding:** a chain's cheapest link,
   a systemic theme, or a cluster of findings in the same module with the same fix. Each
   package: title, findings it closes (IDs), the change in 2–4 sentences, files likely
   touched, acceptance criteria (one per finding: what proves it's fixed — usually a
   test that fails today), effort S/M/L, risk of the change, dependencies on other
   packages, and which packages share files (can't run in parallel).
3. Order: CRITICAL and chains first; within a level, cheap and unblocking first.
   Mark packages that can run in parallel (no shared files, no dependency).
4. Write `<audit_dir>/plan.md` and show the user the ordered list (title · closes ·
   effort · parallel group).
5. Offer — and do only what the user picks:
   - a Spec Kit spec per package via `/feature` (pass the package text as the
     description), for the big ones;
   - a task per package in the project's own task tool if it has one (e.g. the Delilah
     CLI — check its `--help` for how to create tasks; never guess flags), for the
     small ones;
   - a separate session per independent package.
   Never create tasks, specs, issues or sessions without the user's yes, and never
   publish findings to external trackers without asking (they may be security
   sensitive).
6. After fixes land, `/audit --since <ref>` re-checks the affected areas; the report's
   "Fixed since" section closes the loop.
