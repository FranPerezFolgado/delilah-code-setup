---
description: Spec-driven feature development wrapping spec-kit early phases (specify → clarify → plan → tasks). Searches QMD for prior art and uses code-nav to analyze affected code before starting.
argument: description - what feature you want to implement
---

# feature

**DO NOT read any files. DO NOT load context. DO NOT analyse the codebase. Ask these questions first.**

1. "Output format for the spec and plan — `html` (opens in browser) or `markdown` (inline)?"
2. "Create the feature branch automatically? (`yes` / `no`)"
3. "Scope — `lean` (specify → plan, fast) or `full` (specify → clarify → checklist → plan → tasks)?"

Store answers as `OUTPUT_FORMAT`, `CLAUDE_BRANCHES`, `SCOPE`.

**Wait for all three answers before doing anything else.**

---

## After receiving answers

### Phase 1 — Load context

Search QMD and code-researcher in parallel:

**QMD — prior art:**
```
query(collection: "<project-collection>", searches: [
  {type: "lex", query: "<feature keywords>"},
  {type: "vec", query: "<feature description>"}
], intent: "prior implementations, ADRs, or sessions related to this feature")
```

**code-researcher — affected code:**
Which modules, files, and dependencies will be touched.

Present summary. Ask: "Context loaded. Anything to add before I write the spec?"
Wait for go-ahead.

---

### Phase 2 — Specify

Add missing entries to `.gitignore`:
```bash
GITIGNORE=".gitignore"
[ ! -f "$GITIGNORE" ] && touch "$GITIGNORE"
for entry in ".specify/" "specs/"; do
  grep -qF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
done
```

Invoke `/speckit.specify` passing: description + prior art context + affected files map.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/spec.html` and open it.

**Ask:** "Spec ready. Approve to move to planning, or tell me what to change."
Wait for explicit approval.

---

### Phase 3 — Plan

If `SCOPE` is `full`: invoke `/speckit.clarify` if ambiguities, then `/speckit.checklist`.

Invoke `/speckit.plan`.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/plan.html` and open it.

**Ask:** "Plan ready. Approve to generate tasks, or tell me what to adjust."
Wait for explicit approval.

---

### Phase 4 — Tasks (only if SCOPE = full)

Invoke `/speckit.tasks`.

If `OUTPUT_FORMAT` is `html`: generate `specs/<name>/tasks.html` and open it.

---

### Done

- If `CLAUDE_BRANCHES` is `yes`: create branch `feature/<spec-short-name>`
- If `CLAUDE_BRANCHES` is `no`: remind user to create it manually
- No `Co-Authored-By` or AI attribution in any commits
