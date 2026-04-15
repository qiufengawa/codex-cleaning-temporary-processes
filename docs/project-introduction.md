# Project Introduction

Codex Cleaning Temporary Processes is a public, cross-platform skill for safe cleanup of temporary development processes.

The package is intentionally pure skill, not a plugin. Its goal is to give Codex a reusable best-effort process-hygiene workflow that can be picked up through implicit invocation when coding work creates temporary process residue.

The skill is designed around finished checkpoints rather than task-end memory. After a finished high-risk step, a finished automation checkpoint, a finished subagent, or a finished batch of one-shot commands, Codex should reconsider whether cleanup is now safe and useful.

The supported scope is broader than a single language. The skill can reason about mainstream toolchains such as npm, vite, vitest, cargo, tauri, trunk, hatch, pytest, jupyter, streamlit, dotnet, Kotlin, Scala, Go, Ruby, PHP, Elixir, and browser automation helpers, while still keeping the cleanup policy conservative.

Safety remains the core design priority:

- inspect first when evidence is weak
- only clean high-confidence leftovers
- keep explicit automation gated by current-task lineage or confirmed current-thread ownership
- never let workspace match alone authorize explicit automation cleanup
- preserve active shells, ordinary user apps, ambiguous runtimes, and likely reusable dev services

Multi-project isolation is explicit. A process from project A must not be reclaimed just because project B happens to run in another Codex conversation. Workspace-backed evidence, ancestor ownership, and explicit-automation rules must all stay narrow.
