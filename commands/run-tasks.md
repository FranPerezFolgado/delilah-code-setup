---
description: Ejecuta las tareas de Spec Kit de una feature, en paralelo solo cuando es seguro
argument-hint: <carpeta de la feature, p. ej. specs/003-async-hc3>
---

Ejecuta las tareas de la feature en `$ARGUMENTS` (si está vacío, usa la carpeta más reciente bajo `specs/`).

1. Lee `tasks.md`. No resumas `spec.md` ni `plan.md`: solo comprueba que existen.
2. Agrupa las tareas pendientes (`- [ ]`) por fases, respetando el orden y las dependencias.
3. Dentro de cada fase, las tareas marcadas `[P]` cuyos ficheros NO se solapan forman un lote paralelo. Si dos tareas `[P]` tocan el mismo fichero, van en secuencia.
4. Para cada tarea:
   - Si es pequeña o depende de otra: hazla tú inline.
   - Si está en un lote paralelo con trabajo sustancial: lanza un subagente por tarea con este encargo, sin parafrasear:
     ```
     Lee antes de empezar: <ruta>/spec.md, <ruta>/plan.md, <ruta>/tasks.md
     Tu tarea: <ID de la tarea, copiada literal de tasks.md>
     Solo puedes editar: <ficheros de la tarea>
     Verificación: <comandos de test concretos>
     Devuelve: ficheros cambiados, "<comando>: <resultado>" y bloqueos.
     ```
5. Al cerrar cada tarea: márcala `- [x]` en `tasks.md` y añade debajo una línea de evidencia (`comando: resultado`). Comprueba tú uno de los resultados de cada subagente.
6. Al acabar la fase, aplica la "Revisión por riesgo" de CLAUDE.md al diff de la fase.
7. Guarda en Engram las decisiones tomadas durante la ejecución.
8. Para y dime el estado: tareas hechas, pendientes y cualquier decisión que necesites de mí. No hagas commit ni push.
