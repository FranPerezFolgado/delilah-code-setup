---
name: audit
description: Deep, whole-project audit with parallel specialist subagents — security, API/contracts, architecture/design, correctness, data, reliability/performance, tests (incl. mutation testing), frontend, supply chain, best practices/patterns, documentation, AI/agent safety, privacy, git history, fuzzing, end-to-end on a live preview — each finding adversarially verified, chained into attack/failure chains, merged into one ranked report. Also tracks audits over time (/audit trends) and turns findings into work (/audit plan). Use when the user wants to find everything wrong with a project ("audit this repo", "find all the security/design/API problems", "full review of the codebase"), not for reviewing a diff (that's /review).
argument: "[run|trends|plan] [path] [--only a,b] [--skip a,b] [--focus <subdir>] [--since <ref|last>] [--quick] [--deep] [--live] [--mutants] [--no-verify]"
---

# Audit

A whole-project audit, as hard as it gets. Specialist auditors attack the code in
parallel, a skeptic tries to disprove each finding, a chainer lines up the survivors into
attack and failure chains, and a reporter merges it all into one ranked report with a
fix plan.

> **RTK active** — Bash commands are rewritten by the PreToolUse hook.

The main thread only orchestrates. Every agent writes its output to files and returns a
few lines; never read findings files into the main thread. The only big text it
handles is the final report, which the reporter returns for the main thread to save.

## Modes

- `/audit [run] ...` — the audit (below). Default.
- `/audit trends [path]` — evolution across audits → read `references/trends.md` in this skill's folder and follow it.
- `/audit plan [audit_dir]` — turn a report into work → read `references/plan.md` and follow it.

## Arguments (run)

| Arg | Effect |
|---|---|
| `path` | Project root (default: the repo root of the cwd). |
| `--only` / `--skip` | Areas (below). |
| `--focus <subdir>` | Every agent concentrates on that subtree (still reads the rest for context). |
| `--since <ref\|last>` | Incremental: only what changed since `<ref>`, or since the commit of the latest audit (`last`). Reuses that audit's map and compares with its report. |
| `--quick` | Auditors on `sonnet`, verify only CRITICAL/HIGH, no fuzz/e2e/chains. |
| `--deep` | Fuzz 15 min per target and up to 15 targets; mutation testing on; verify LOW too. |
| `--live` | Start an isolated running instance for security/api/frontend/e2e (step 3). |
| `--mutants` | Mutation testing in the tests area (slow). Implied by `--deep`. |
| `--no-verify` | Skip verification and chains (findings stay UNVERIFIED). |

## Areas

| Area | Agent | Default |
|---|---|---|
| security | audit-security | on |
| api | audit-api | on |
| architecture | audit-architecture | on |
| correctness | audit-correctness | on |
| data | audit-data | on if any DB or on-disk state |
| reliability | audit-reliability | on |
| tests | audit-tests | on |
| frontend | audit-frontend | on if there's a UI |
| supply-chain | audit-supply-chain | on |
| practices | audit-practices | on |
| docs | audit-docs | on |
| ai-safety | audit-ai-safety | on if it runs agents or calls LLMs |
| privacy | audit-privacy | on |
| history | audit-history | on (sonnet; cheap) |
| fuzz | audit-fuzzer | on, except `--quick` |
| e2e | audit-e2e | only with `--live` |

## 1 · Set up

```bash
ROOT=$(git -C "${path:-.}" rev-parse --show-toplevel)
AUDIT_DIR="$ROOT/.audit/$(date +%Y-%m-%d-%H%M)"
mkdir -p "$AUDIT_DIR"/{findings,verified,scratch}
EXCL="$(git -C "$ROOT" rev-parse --git-common-dir)/info/exclude"
grep -qx '.audit/' "$EXCL" 2>/dev/null || echo '.audit/' >> "$EXCL"
```

`.git/info/exclude` is local-only: the audit never shows up in `git status` and the
project's files are not modified. For `--since last`: the previous audit is the newest
`$ROOT/.audit/*/metrics.json`; its `commit` is the ref. Tell the user the audit dir in
one line.

## 2 · Map

Launch **audit-mapper** with ROOT, AUDIT_DIR, `--focus`, and for `--since` the ref and
the previous audit dir. Wait for it. Its return line says which areas apply and whether
a component is big enough to split.

Apply the defaults table, `--only`/`--skip`, and the mapper's verdicts. **Split** an
area when the mapper suggests it (a component over ~15k LOC, or two components with
separate trust boundaries): one agent per component, output
`findings/<area>-<component>.md` and its own ID prefix (`COR-ENG`, `SEC-API`…) so IDs
stay unique. Size each slice so one agent can read all of it: at most ~8k LOC of the
area's code per agent (~5k for correctness and security, which read deepest). Cap the
fan-out at ~20 auditors; past that, cover the rest in the follow-up wave (step 4b). For `--since`, drop
areas none of the changed files concern.

**Confirm before running the project's code.** Fuzzing, mutation testing and `--live` build
and execute code from the audited repo, which may be hostile. When any of them is on, ask
once with AskUserQuestion, naming what will run (the fuzz targets' crate/package, the
mutation tool, the preview/dev command from step 3): run them / skip them (drop fuzz, e2e
and mutants, audit the rest statically). Recommend skipping for a repo the user didn't write.

## 3 · Live target (only with `--live`)

Start a disposable instance of the project, never the user's real/installed one, with
the project's own preview/dev instructions (its CLAUDE.md or docs — e.g. a preview
script that gives an isolated port and state dir), in the background, from an empty
state if the script supports it. No safe isolated way to run it → skip, drop e2e, say
so. Pass "live target: <UI url>, <API url>, <how to point the CLI at it>, <fixture
repos>" to security, api, frontend and e2e. Stop it (that process only) after step 5.

## 4 · Audit (all in parallel, one message)

Launch every applicable auditor **in a single message**. Each prompt contains only:
ROOT, AUDIT_DIR, output file name, `--focus`, component scope if split, live target if
any, `since` if incremental, model override `sonnet` for `--quick`, and per agent:
fuzz → time budget and max targets; tests → `mutants: on` and a time budget when
`--mutants`/`--deep`. Pass on the project's guard rules from its CLAUDE.md when they
forbid something an auditor might try (e.g. "never use port X / never restart Y").

## 4b · Close coverage gaps

Each auditor's return has a `Not covered:` line. For gaps in core code (the map's
components and hotspots, not generated or vendored files), launch one follow-up agent
of the same type per gap, scoped to just those ranges, writing
`findings/<area>-gap-<n>.md` with prefix `<PREFIX>-G<n>`. One follow-up wave only;
what's still uncovered after it is listed under Coverage in the report.

## 5 · Verify, then chain (pipelined)

Unless `--no-verify`: as **each** auditor returns, immediately launch an
**audit-verifier** on its findings file. Severities to verify: CRITICAL/HIGH/MEDIUM
(default), CRITICAL/HIGH (`--quick`), all (`--deep`). No verifier for history (its
findings are statistics) or for an area with 0 findings at those levels.

When all verifiers are back and not `--quick`, launch **audit-chainer** with AUDIT_DIR.

Keep the user posted with one line per returned agent (its summary line), nothing more.

## 6 · Report

Launch **audit-reporter** with AUDIT_DIR, and the previous audit's `REPORT.md` as
"previous report" when there is one (always for `--since`; otherwise the newest earlier
audit, if any). It returns the report between `<<<REPORT` and `REPORT>>>`
(subagents can't write report files): save that text verbatim as
`$AUDIT_DIR/REPORT.md` with the Write tool, and `metrics.json` too if it came back
inline. Then give the user, from that text:

- the verdict paragraph and the severity table, and the top chains,
- the "Fix first" list, and "Fixed since / New since" if present,
- links to `REPORT.md` and the area files.

Then offer, one line each, only what applies:
- publish the report as a private Artifact (only on yes — it holds security findings);
- `/audit plan` to turn findings into work;
- `/audit trends` when there are 2+ audits;
- schedule a recurring incremental audit (`/audit --since last --quick`) as a local
  scheduled task (the scheduled-tasks tools; local, since the audit needs this checkout)
  — only on yes.

Don't start fixing anything unasked.

## Rules

- Nothing touches the project's tracked files. Agents write only under AUDIT_DIR
  (git worktrees for mutation testing live there too and are removed after).
- Nothing touches the user's running services, installed apps, real data or remotes.
- If an agent fails or times out, relaunch it once; if it fails again, report the area
  as not covered rather than covering it from the main thread.
- Each run gets a new timestamped dir; old audits are kept for trends.
- Builds go to `$ROOT/.audit/.cache/` (shared, warm across audits), never into the
  run's dir. At the end, delete `$AUDIT_DIR/scratch/` entries over 100 MB that an agent
  left anyway, and tell the user the size of `.audit/.cache/` in one line (they can
  delete it any time; the next audit just rebuilds).
