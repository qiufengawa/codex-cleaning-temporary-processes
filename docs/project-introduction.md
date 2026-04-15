# Project Introduction

Codex Cleaning Temporary Processes is a cross-platform Codex skill for safe process hygiene during development work.

It is designed for sessions where shells, test runners, build tools, browser-debug helpers, DevTools MCP services, subagent-owned tooling, and workspace runtimes may leave behind temporary processes. Instead of waiting until the very end of a long task, the skill supports checkpoint cleanup after a finished risky step, which keeps process buildup under control without broadly killing everything that looks developer-related.

The project targets mainstream development workflows across Windows, macOS, and Linux. Its rules are built around command-line evidence, process-tree relationships, and workspace matching so it can support frontend, backend, automation, mobile, and systems-oriented toolchains without being tied to one project layout.

The operating model stays conservative:

- inspect first when evidence is weak
- clean only high-confidence leftovers during checkpoint cleanup
- allow conservative ownership inheritance only from workspace-backed task ancestors with known dev, test, build, serve, or watch markers
- keep explicit automation inspect-only when current-task lineage or current-thread ownership is not yet proven; workspace match alone is not enough
- let the same Codex conversation keep reclaiming current-thread-owned explicit automation after it already proved ownership once, without broadening cleanup for generic runtimes
- preserve active Codex shells, ordinary user apps, and likely reusable dev services
- reserve the final sweep for temporary process trees that are definitely no longer needed

The intended cadence is incremental: re-evaluate after each finished high-risk step, after DevTools MCP or browser-debug work, after repeated one-shot shell or tool commands, and after subagents that may have launched shells, runtimes, or browsers.

Cleanup modes re-inspect the process table after kill attempts and report both what was reclaimed and what failed to stop, so downstream callers can see the real post-cleanup state instead of a stale pre-cleanup snapshot.

The `inspect` view is intentionally narrower than a full process dump: it reports classified records, while weak-signal or unmatched processes may be preserved without being listed. Direct browser-process matching currently focuses on Chromium and Edge-family remote-debug sessions; non-Chromium automation is primarily identified through explicit helper or wrapper processes.

This repository includes the skill definition, agent metadata, PowerShell scripts, a shell wrapper, and Pester tests needed to reuse or adapt the skill in other Codex environments.
