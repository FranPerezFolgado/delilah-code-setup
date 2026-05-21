---
description: Delegates code searches to the code-researcher agent. Keeps the main context clean.
argument: query - what you want to find in the codebase
---

# Code Nav

Delegate to the `code-researcher` subagent: "$ARGUMENTS"

The agent will use Codegraph to find symbols, call chains, and relevant files, falling back to Grep/Read only if the graph doesn't have the answer.

Return the result to the main thread without reading files directly here.
