---
name: orchestrate
description: Orchestrated implementation of a Spec Kit feature with subagents — slices tasks.md into work packages, runs code-researcher → implementer (test-first, checked by a hook) per package, parallelises packages that share no files, and reviews each phase. The /feature skill hands over to it; run it directly to start or resume implementing a feature that already has tasks.md.
argument-hint: "[feature dir or name] [--resume]"
model: sonnet
---

# orchestrate

Implements a Spec Kit feature with subagents while this session only orchestrates.
Usage: `/orchestrate [specs/<feature>]` — no argument: the feature in `.specify/feature.json`.

> **RTK active** — all Bash commands are automatically rewritten by the PreToolUse hook.

## You are the orchestrator

- **Never edit source code or tests yourself.** You write only `progress.md`, the checkboxes in `tasks.md`, briefs and commits. Code changes go to `implementer`.
- **Keep your context small.** Don't read the codebase, whole diffs or test logs. Read `packages.md`, `progress.md`, the spec excerpts you put in briefs, and agents' replies.
- **Reports go to files.** Every brief asks the subagent to write its full report to `specs/<feature>/reports/<WP>-<agent>.md` and to reply with at most 15 lines: verdict, files touched and the report's path. Don't read those reports except to settle a `blocked` package or a CRITICAL/HIGH finding.
- **Never improvise around a blocked package.** Ask the user.

## Inputs from /feature

When `/feature` hands over it passes `OUTPUT_FORMAT` (`markdown` | `html`), `CLAUDE_BRANCHES` (`yes` | `no`)
and `AUTONOMY` (`auto` | `step`).
Run directly, read them from the `Mode:` line of `progress.md`; if there's none, ask the first two with AskUserQuestion
(same options as `/feature`: "Output format for the reports?" and "Commit each package on the feature branch?")
and take `AUTONOMY=auto` unless the user asked to approve each phase.

- `auto`: don't stop between phases or for fix packages. Stop only for a `blocked` package, an OUT OF SCOPE
  file, review findings that don't converge (§3), or a decision the spec doesn't settle.
- `step`: ask before every fix package and at the end of every phase, as below.

## 0. Preconditions

1. Resolve the feature dir: argument, else `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` (`FEATURE_DIR`), else `.specify/feature.json`. No `tasks.md` → stop and suggest `/speckit-tasks`.
2. Branch: note `git branch --show-current`. If `CLAUDE_BRANCHES` is `yes` and you're on the default branch, stop: the branch must exist first (Spec Kit's `before_specify` hook or `/speckit-git-feature` creates it). All work, worktrees included, starts from this branch.
3. Working tree: if there are uncommitted changes outside `specs/`, ask whether to commit them first, continue anyway, or stop. The verify hook checks every uncommitted file, so leftover changes would be blamed on the packages.
4. If the repo has a `.codegraph/` index, run `codegraph sync` so the maps are current.
5. Read the project `CLAUDE.md` section `## Stack & checks`. If it's missing, tell the user the hook will guess checks from marker files, and offer to add the section (one short table) before continuing.
6. Run the `before_implement` hooks from `.specify/extensions.yml` the way `speckit-implement` does (mandatory ones automatically, optional ones only if the user agrees).

## 1. Resume or slice

**`progress.md` exists** → show its table, and continue from the first package that isn't `done`/`skipped`. A package left `implementing` was cut off: check `git status` for its files and ask whether to re-run it from scratch (discarding those files) or let a new implementer finish it.

**Otherwise** → launch `task-slicer` with the feature dir. Show the user its table and doubts, then AskUserQuestion: approve / adjust (free text → re-run the slicer with the changes) / stop.

Then write `specs/<feature>/progress.md`:

```markdown
# Progress — <feature>

Branch: <branch> · Base: <short sha> · Started: <date>
Mode: format=<markdown|html> commits=<yes|no> autonomy=<auto|step>

| WP | Phase | Group | Status | Attempts | Commit | Notes |
|----|-------|-------|--------|----------|--------|-------|
| WP-01 | 2 | 2A | pending | 0 | | |

## Open findings

| Phase | Reviewer | Severity | Finding | File |
|-------|----------|----------|---------|------|
```

Statuses: `pending` → `implementing` → `verified` → `done` · `blocked` · `skipped`. Update the file at every transition: it's what makes resuming possible.

## 2. Run each phase

Phases in order; inside a phase, parallel groups in order. For each group:

### 2a. Map
For each package, launch `code-researcher` ("work package map" mode) with its tasks, file list and report file `specs/<feature>/reports/<WP-id>-code-researcher.md`. Launch all maps of the group in one message.

### 2b. Brief
Write each implementer's brief, at most ~80 lines:

```
WORK PACKAGE <WP-id> — <title>
Feature: specs/<feature>/   Branch: <branch>

Tasks (verbatim from tasks.md):
- T0xx …

Acceptance criteria (excerpt from spec.md, only what applies):
- FR-00x …  / Scenario: Given … When … Then …

Allowed files (edit only these):
- path …

Code map: specs/<feature>/reports/<WP-id>-code-researcher.md (read it first)

Checks: <from Stack & checks for these files>
Notes: <decisions from earlier packages that matter here, if any>
Report: write the full report to specs/<feature>/reports/<WP-id>-implementer.md; reply with at most 15 lines (verdict, files touched, report path).
```

### 2c. Implement
Mark the packages `implementing` and launch one `implementer` per package. Packages of the same group go **in the same message** so they run in parallel; they share no files, so they share the checkout. Use `isolation: "worktree"` only when the user asked for it or the slicer flagged a shared file; then merge each worktree's branch into the feature branch afterwards, one at a time, and mention that a Rust worktree builds `target/` from scratch.

The `SubagentStop` hook (`~/.claude/hooks/verify-package.sh`) re-runs the checks when an implementer stops and sends it back up to 3 times. Its last result is in `$(git rev-parse --git-dir)/claude-verify/<agent_id>.log`: read just the last 2 lines (PASS / FAIL attempt n).

**Scope check.** The allowed-files list is only a prompt, so check it. Before launching a group, keep `git status --porcelain` as the baseline. When the group's implementers have stopped, run it again; every path that is new or changed since the baseline must be in the allowed files of one of the group's packages (`specs/<feature>/reports/` is always allowed). A path outside every list → don't commit anything of that group yet; show the path, which package's report mentions it, and its `git diff --stat`, then AskUserQuestion: allow it (add it to that package's list) / revert it (`git checkout -- <path>`, or delete it if it's new) / stop here.

### 2d. Settle each package
- **done + checks pass** → tick its tasks `- [X]` in `tasks.md`, status `verified`. If `commits=yes`: `git add <its files> specs/<feature>/tasks.md specs/<feature>/progress.md` and commit `feat(<feature-short>): <WP-id> <title>` (plain message, no AI attribution); put the short sha in the table.
- **failing after 3 attempts** → `blocked`, attempts=3. Launch `debugger` with the hook log path, the brief and the implementer's report. Show its diagnosis in a few lines, then AskUserQuestion: retry with the debugger's fix hint (sent to the same implementer with SendMessage) / retry with my own hint (free text) / I'll fix it by hand / skip. If the hint needs a file outside the package, handle it like OUT OF SCOPE.
- **OUT OF SCOPE** → show the file and the reason. AskUserQuestion: allow the file (SendMessage to the same agent with the new list) / move that work to another package / skip.

Never start a group while a package of a previous group it depends on isn't `verified`.

## 3. Review each phase

When every package of a phase is `verified`:
1. Diff range: the phase's commits (or `git diff <base>` when `commits=no`).
2. Launch in one message:
   - `spec-compliance-reviewer` — always, with the feature dir, the phase name and the range.
   - `contract-reviewer` / `migration-reviewer` / `security-reviewer` / `architecture-reviewer` — only those named in the `Reviewers` line of the phase's packages, or whose area the diff touches (`git diff --stat` is enough to tell).
   - `ui-verifier` — only when the phase changed something the UI renders. Give it the phase's acceptance scenarios (Given/When/Then from `spec.md`) and how to reach the app (the project `CLAUDE.md` says how to try changes; pass a URL if a preview is already running). Native-only behaviour it can't reach goes in the report as not checked.
3. Summarise in at most ~15 lines: verdict per reviewer and the CRITICAL/HIGH findings.
4. CRITICAL/HIGH findings → one fix package (`WP-xxF`, the findings as tasks, the files they cite as allowed files) through 2b–2d, then re-run only the reviewers that raised them on the fix's commits. At most 2 fix rounds per phase: if CRITICAL/HIGH findings remain after the second, stop and ask (fix by hand / another round / accept as open).
5. MEDIUM/LOW findings → `auto`: append them to "Open findings" in `progress.md` and carry on; `step`: list them and let the user choose.
6. Mark the phase's packages `done`. If this session's context is past ~150k tokens, update `progress.md` and ask the user to run `/clear` and then `/orchestrate` again, which resumes from `progress.md`; stop here. Otherwise, `auto`: go on to the next phase. `step`: AskUserQuestion: next phase / stop here (progress is saved).

## 4. Finish

- Run the full checks once (`## Stack & checks` → "everything"), in the background if they're long.
- Run the `after_implement` hooks from `.specify/extensions.yml`, if any.
- Version bump, if the project `CLAUDE.md` asks for one: pick the semver level from what the feature does
  (its rules there), then run the project's bump script (e.g. `scripts/bump-version.sh <level>`) or follow its
  release steps by hand, and commit `chore: bump version to X.Y.Z` on its own. Put the level and why in the report
  and in the `pr-writer` brief.
- If `format=html`: write `specs/<feature>/progress.html` — a single page with the package table, review verdicts and open findings — and open it.
- If `commits=yes`: launch `pr-writer` with the base branch, the feature dir and the phases' review verdicts, and keep its draft for the PR.
- Report: packages done/skipped/blocked, commits, the "Open findings" table (MEDIUM/LOW left for you), and the next step (try it in a preview, `/review`, open the PR with the drafted description — opening it is the user's call).
