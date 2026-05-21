# ADR 001 — PR creation is intentionally manual

**Date:** 2026-05-21  
**Status:** Accepted

## Context

During setup, the option of automating PR creation (via `gh pr create` triggered by `/feature` or `/commit`) was considered. Tools like spec-kit can extract the feature name and generate a PR description from spec artefacts.

## Decision

PR creation remains a manual step. The workflow provides all the context needed (spec, plan, commit messages) but does not open PRs automatically.

## Reasons

- PRs are a communication act, not just a code submission. The title, description, and reviewer selection involve judgment that shouldn't be delegated silently.
- Spec-kit artefacts (`spec.md`, `plan.md`) are local-only and not committed — they can't be referenced in a PR description without manual curation.
- Automated PR creation in the wrong branch or with the wrong base is hard to undo once reviewers are notified.
- The `/review` skill already covers the review itself. The gap is small.

## Tradeoffs

A `/pr` skill that drafts the PR description from spec artefacts and prompts for confirmation before submitting could be added later. This is different from fully automatic creation and would be acceptable.

## Consequences

Users run `gh pr create` manually after `/commit`. The workflow docs note this explicitly.
