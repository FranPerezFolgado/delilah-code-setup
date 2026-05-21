---
description: Quick parallel code review of local changes or a known PR. Pass a PR number/URL to review remotely. For a guided PR review with preview, use /pr-review instead.
argument: pr - GitHub PR number or URL (optional; without argument reviews local changes)
---

# Review

**Use this when:** you want a fast review of your local changes, or you already know the PR number and just want results.

**Use `/pr-review` when:** you want a guided flow — it fetches the PR title/description/stats and asks you to confirm before running the review.

---

Reviews changes with 4 specialised agents in parallel.

## Diff source

**No argument** (local changes):
```bash
git diff main...HEAD
```

**With PR number/URL**:
```bash
gh pr diff <number>
```

## Agents (run in parallel)

1. **security-reviewer** — secrets, injections, auth, OWASP
2. **code-quality-reviewer** — correctness, SOLID, design patterns, error handling
3. **test-reviewer** — coverage, test quality, edge cases
4. **architecture-reviewer** — coupling, consistency, breaking changes

Each agent receives the full diff and returns findings with severity (`CRITICAL` / `HIGH` / `MEDIUM` / `LOW`), file:line, and suggestion.

## Consolidated verdict

```
SECURITY        [✅/⚠️/❌]  summary
CODE QUALITY    [✅/⚠️/❌]  summary
TESTS           [✅/⚠️/❌]  summary
ARCHITECTURE    [✅/⚠️/❌]  summary

VERDICT: ✅ READY | ⚠️ NEEDS ATTENTION | ❌ NEEDS WORK
```

- **✅ READY**: no CRITICAL or HIGH
- **⚠️ NEEDS ATTENTION**: MEDIUM/LOW only
- **❌ NEEDS WORK**: CRITICAL or HIGH present

Full detail per agent, ordered by severity.
