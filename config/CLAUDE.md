## Active tools

### RTK (token reduction)
RTK is active via PreToolUse hook. Shell commands are rewritten automatically — no manual action needed.

### Codegraph (code exploration)
ALWAYS use codegraph tools before Read/grep to explore code:
- `codegraph_search` — find symbols by name
- `codegraph_context` — get relevant context for a task
- `codegraph_callers` / `codegraph_callees` — trace call chains
- `codegraph_impact` — analyse change impact

Only use Read/Grep for config files, plain text, or when the symbol isn't in the graph.

### Engram (session memory)
Engram is the single store for what we learn while working.
- At session start: `mem_context` (recent history) and `mem_search` for the task at hand.
- Save with `mem_save`: decisions and their why, non-obvious bugs and their cause, discovered conventions.
- At the end of a session: `mem_session_summary`.

### QMD (reference docs only)
Use QMD for reference documentation: `docs/`, `specs/`, ADRs. Not for session notes (those live in Engram).
- Tool: `query` combining `lex` (keywords) and `vec` (semantic)
- Active collection is in the local `CLAUDE.md` (`## QMD Collection`)
- If no collection configured: run `/project-setup`

If QMD doesn't respond: the daemon is managed by launchd (macOS) or systemd (Linux). Run `/stats` to diagnose.

@RTK.md

<!-- fran-setup:start -->
## Cómo trabajar

- Trabaja directamente (inline) por defecto. Usa un subagente SOLO si puedes nombrar uno de estos motivos, y nómbralo antes de delegar:
  1. **Explorar**: entender código desconocido requiere más de ~5 búsquedas seguidas. Un explorador de solo lectura devuelve un mapa corto con referencias `path:line`.
  2. **Escritores en paralelo**: dos o más tareas independientes que tocan ficheros distintos y suponen varios minutos de trabajo cada una (100+ líneas o varios ficheros).
  3. **Relevo de contexto**: la sesión es muy larga; pasa la siguiente unidad acotada a un worker nuevo.
  4. **Verificación independiente**: el cambio es de riesgo alto (ver "Revisión").
- Ante la duda, inline. El número de ficheros o el tamaño de la tarea no deciden por sí solos.
- Al delegar, pasa rutas exactas (spec.md, plan.md, tasks.md, SKILL.md), nunca un resumen tuyo de ellas. Indica qué comandos de verificación debe ejecutar y comprueba tú uno de sus resultados.
- Las preguntas, explicaciones y revisiones son solo lectura: no cambies código hasta que te lo pida.

## Spec Kit: solo para trabajo grande

Antes de usar `/specify`, decide el tamaño:
- **Pequeño** (cabe en una sesión, se retoma leyendo el diff, riesgo contenido): hazlo directo, sin spec.
- **Grande** (varias sesiones, esperas externas o requisitos que no sobrevivirían a una compactación): usa Spec Kit y ejecuta las tareas con `/run-tasks`.

## Tests

- Si hay un test ejecutable y un resultado claro: primero un test que falle (RED) por cada regla pedida, luego implementación (GREEN), luego refactor.
- Añade un test por cada comportamiento existente que toques, para probar que sigue igual. Nada más.
- Si no tiene sentido un test, explica por qué y ejecuta igualmente las comprobaciones funcionales.

## Memoria y documentación

- **Engram = lo que aprendemos trabajando.** Al empezar, consulta el contexto del proyecto. Guarda con `mem_save`: decisiones y su porqué, bugs no obvios y su causa, convenciones descubiertas. Al acabar, guarda un resumen de sesión.
- **QMD = documentación de referencia** (specs, ADRs, openEHR/DICOM, docs de APIs). Búscala antes de suponer cómo funciona algo.
- No dupliques en Engram lo que ya está en la documentación: referencia el documento.
- Antes de preguntarme algo que ya decidimos, búscalo en Engram.

## Revisión por riesgo

Al terminar un cambio, clasifícalo según lo que toca:
- **Bajo** (docs, comentarios, sin efecto ejecutable): relectura rápida.
- **Medio** (cambio normal cubierto por tests): ejecuta los tests y reporta `<comando>: <resultado>`.
- **Alto**: toca datos persistidos o migraciones, seguridad/autenticación, contratos que otros consumen (APIs, mensajes de RabbitMQ, esquemas), concurrencia, despliegue, o no hay test que detecte una regresión. Entonces:
  1. Guarda el diff: `git diff > /tmp/review-$(date +%s).diff`.
  2. Lanza el revisor de seguridad y el arquitecto sobre ESE fichero, con las lentes Riesgo, Resiliencia, Legibilidad y Fiabilidad que apliquen.
  3. Una sola ronda de corrección de los bloqueantes. Lo que siga abierto, me lo planteas como decisión.
- Commit, push y PR los decido yo.
<!-- fran-setup:end -->
