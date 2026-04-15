# Project Introduction

Codex Cleaning Temporary Processes is a public, cross-platform package for safe cleanup of temporary development processes.

The package supports two installation modes:

- plugin-style installation keeps `.codex-plugin/plugin.json`, `hooks.json`, and `hooks/` at the repo root and enables automatic strong triggering
- skill-style installation under `CODEX_HOME/skills` exposes the skill text and scripts but does not activate automatic hook behavior on its own

That split is user-facing and intentional. The installed plugin package handles automatic fixed checkpoints, while `SKILL.md` remains the manual fallback guide.

The fixed-checkpoint model is deliberate. Instead of waiting for Codex to remember cleanup when the task ends, the package re-evaluates after concrete finished checkpoints such as a high-risk tool step, a DevTools or browser-debug checkpoint, a subagent completion, a one-shot helper backlog, or session end.

The safety model stays narrow:

- inspect first when evidence is weak
- clean only high-confidence leftovers during checkpoint cleanup
- require current-task lineage or confirmed current-thread ownership for explicit automation
- never treat workspace match alone as enough for explicit automation
- never let current-thread ownership broaden cleanup for generic runtimes
- preserve active Codex shells, ordinary user apps, ambiguous runtimes, and likely reusable dev services

The package also keeps multi-project isolation explicit. Workspace-backed runtime cleanup must still match the current workspace or a task-owned ancestor, and explicit automation from another conversation or repository remains `inspect-only` unless ownership is proven.

For same-thread explicit automation recovery, local runtime state uses sanitized thread identifiers and normalized workspace values. That local state supports safe lookup and filename handling, but it does not widen cleanup authority.

This repository includes the public docs, metadata, plugin manifest, hook definitions, PowerShell scripts, shell wrapper, and tests needed to package the behavior for Windows, macOS, and Linux.
