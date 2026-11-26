# /audit trends

Shows how a project's audit results evolve over time.

1. `ROOT` as in a run. Collect every `$ROOT/.audit/*/metrics.json` (sorted by date). Fewer
   than 2 → say so and stop.
2. Write `$ROOT/.audit/trends.json`: one entry per audit (date, commit, incremental,
   totals, per-area counts, chains) plus, by matching findings across consecutive
   audits on `area + category + location file` (lines move; titles get reworded):
   - **fixed**: in the earlier audit, absent in the later one (and the file still
     exists or the code moved — check with `git log --follow` if unsure);
   - **new**: absent before, present now;
   - **persistent**: present in both — count how many audits each has survived.
   Incremental audits only cover part of the code: carry forward the last full audit's
   findings for areas/files they didn't touch instead of counting them as fixed.
3. Build the page: start from the Artifact tool's dashboard flow (`quickstart` with
   intent "other"), fed with `trends.json`. Show: totals by severity over time, per-area
   trend, fixed vs new per audit, oldest persistent CRITICAL/HIGH findings (with age in
   audits and days), themes that keep reappearing. If an audit-trends artifact already
   exists for this project (list artifacts), update it at its URL instead of creating a
   new one. Private by default; tell the user it holds security findings before they
   share it.
4. Reply with 3–5 lines: direction (better/worse), what got fixed, what's stuck longest,
   and the link.
