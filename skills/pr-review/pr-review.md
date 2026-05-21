---
description: Guided remote PR review — fetches PR context, shows a preview, then runs all review agents. Use this when you want to review someone else's PR or want to see PR metadata before reviewing.
argument: pr - PR number or URL (optional)
---

# pr-review

**Use this when:** reviewing a PR you haven't looked at yet — it shows title, description, and change stats before running agents, so you have full context.

**Use `/review <number>` when:** you already know the PR and just want the findings fast.

---

Guided review of a remote PR with 4 specialised agents in parallel.

## Steps

### 1. Get the PR
If not passed as argument, ask:
> "Which PR do you want to review? (number or URL)"

Extract the number if a URL was provided.

### 2. Fetch PR context
```bash
gh pr view <number> --json title,body,author,baseRefName,headRefName,additions,deletions,changedFiles
gh pr diff <number>
```

Show a preview to the user:
- Title and description
- Author, source branch → target branch
- +X / -Y lines, N files changed

### 3. Run in parallel
- **security-reviewer** with the diff
- **code-quality-reviewer** with the diff
- **test-reviewer** with the diff
- **architecture-reviewer** with the diff

### 4. Consolidated verdict

```
── PR #<N>: <title> ──

SECURITY        [✅/⚠️/❌]  one-line summary
CODE QUALITY    [✅/⚠️/❌]  one-line summary
TESTS           [✅/⚠️/❌]  one-line summary
ARCHITECTURE    [✅/⚠️/❌]  one-line summary

VERDICT: ✅ READY | ⚠️ NEEDS ATTENTION | ❌ NEEDS WORK
```

Followed by full detail from each agent ordered by severity.
