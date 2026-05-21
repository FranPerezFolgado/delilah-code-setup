---
description: Shows token savings and tool status — RTK savings, QMD collections, and Codegraph index state.
---

# Stats

Shows setup status and accumulated token savings.

## Steps

1. **RTK savings**
```bash
rtk gain
```

2. **RTK by command** (top impact)
```bash
rtk gain --history
```

3. **Indexed QMD collections**
```bash
qmd collection list
```

4. **Codegraph status** in current project
```bash
codegraph status 2>/dev/null || echo "Codegraph not initialised in this project — run: codegraph init -i"
```

## Output

Present a clean summary:

```
── Token savings (RTK) ──
  Tokens saved:  XXX,XXX (XX%)
  Commands:      XXX
  Top saver:     git / ls / read

── QMD collections ──
  project-name   XXX docs   last indexed: XX ago

── Codegraph ──
  Status: indexed / not initialised
  Symbols: XXX   Files: XXX
```

Append any gaps detected:
- ⚠️ Codegraph not initialised → `codegraph init -i`
- ⚠️ No QMD collection for this project → `/setup-qmd`
- ⚠️ QMD not responding → `qmd mcp --http --daemon`
