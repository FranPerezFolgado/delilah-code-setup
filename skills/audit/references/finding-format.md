# Audit finding format (shared by every audit-* agent)

Every auditor writes its findings to `<audit_dir>/findings/<area>.md` and returns only a
short summary to the caller. The verifier and the reporter parse this file, so keep the
format exact.

## File layout

```markdown
# <Area> audit — <project>

Scope: <what you covered> · Not covered: <what you skipped and why>
Tools run: <commands run and their outcome, e.g. `cargo audit` → 2 advisories>

## <PREFIX>-001 · <short title>

- **Severity:** CRITICAL | HIGH | MEDIUM | LOW | INFO
- **Confidence:** high | medium | low
- **Category:** <kebab-case, e.g. path-traversal, race-condition, leaky-abstraction>
- **Location:** `path/to/file.rs:120-148` (more lines for each place involved)
- **Problem:** one or two sentences, the defect itself.
- **Evidence:** the code path that proves it — quote the key lines (≤10) and trace
  input → sink / caller → callee with file:line at each hop.
- **Scenario:** concrete inputs or state → what goes wrong (exploit, crash, data loss,
  wrong result, the change that becomes painful).
- **Fix:** concrete change, naming the function/type to touch. Effort: S | M | L.

## <PREFIX>-002 · ...
```

End with a `## Notes` section for suspicions you could not prove (no ID, one line each),
and areas you'd look at next with more time.

## Severity

| Level | Meaning |
|---|---|
| CRITICAL | Exploitable now, or loses/corrupts user data, or takes the system down, with a realistic trigger. |
| HIGH | Same impact under plausible but less common conditions; or a design flaw that already blocks/forces workarounds. |
| MEDIUM | Real defect with limited impact or an unlikely trigger; design debt that will hurt on the next change in that area. |
| LOW | Hardening, inconsistency, minor smell with a concrete downside. |
| INFO | Observation worth knowing, no defect. Use sparingly. |

Rate impact × likelihood in *this* project's threat model (from the map), not in the abstract:
a local-only daemon and a public SaaS endpoint get different ratings for the same bug.

## Rules for every auditor

- **Evidence or it didn't happen.** Every finding cites file:line you actually read. No
  "might be", no generic best-practice lists. If you can't prove it, put it in Notes.
- **Run things.** Prefer a failing command, a test you wrote in the scratch dir, or a
  traced code path over reasoning alone. Never modify the project's files; write
  scratch files only under `<audit_dir>/scratch/`.
- **Read-only on the outside world.** No network calls to third parties beyond what
  package advisory tools do, no git push/commit, no stopping or starting the user's
  services. If something would need that, describe it in Notes.
- **One finding per root cause.** Several call sites with the same cause → one finding
  listing all locations.
- **Stay in your lane, but don't drop things.** Something clearly outside your area goes
  in Notes as `→ <area>: ...` so the reporter can route it.
- **Builds:** never build into the project's own `target/` or into the audit dir. Rust:
  `CARGO_TARGET_DIR=<ROOT>/.audit/.cache/target` (shared across audits so it stays
  warm; cargo's lock serialises concurrent builds, which is fine). Scratch crates such
  as fuzz harnesses: `<ROOT>/.audit/.cache/scratch-target`.
- **Coverage is part of the result.** Every file in your scope that you did not read
  in full goes in the `Not covered:` line with line ranges (`inbox.rs:420-1035`).
  Don't claim coverage you don't have; the orchestrator relaunches on the gaps.
- **IDs in a split area:** the caller gives you an ID prefix (e.g. `COR-ENG`); use it
  instead of the plain area prefix, so IDs stay unique across the audit
  (`COR-ENG-001`).
- **IDs:** `SEC`, `API`, `ARC`, `COR`, `DAT`, `REL`, `TST`, `UI`, `SUP`, `PRA`, `DOC`, `AIS` (ai-safety), `PRV` (privacy), `HIS`
  (history), `FUZ` (fuzz), `E2E`, `CHN` (chains) + 3 digits.
- **Incremental runs (`since` given by the caller):** audit the changed files listed in
  the map's `## Changed since` section plus whatever they affect
  (`codegraph_impact`/callers), and say in the Scope line that the run is incremental.
  Don't re-report findings from the previous report unless the change made them worse.

## Return value (to the caller, not the file)

```
<AREA>: <n> findings (C:<n> H:<n> M:<n> L:<n> I:<n>) → <path to findings file>
Top: <ID> <title>; <ID> <title>; <ID> <title>
Not covered: <file:range, ...> | none
```

Nothing else. The caller reads the file when it needs detail.
