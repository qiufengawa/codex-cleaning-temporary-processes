# Project Introduction

Codex Cleaning Temporary Processes is a cross-platform Codex skill for safe process hygiene during development work.

It is designed for sessions where shells, test runners, build tools, browser-debug helpers, DevTools MCP services, and workspace runtimes may leave behind temporary processes. Instead of waiting until the very end of a long task, the skill supports checkpoint cleanup after a risky step finishes, which keeps process buildup under control without broadly killing everything that looks developer-related.

The project targets mainstream development workflows across Windows, macOS, and Linux. Its rules are built around command-line evidence, process-tree relationships, and workspace matching so it can support frontend, backend, automation, mobile, and systems-oriented toolchains without being tied to one project layout.

The operating model stays conservative:

- inspect first when evidence is weak
- clean only high-confidence leftovers during checkpoint cleanup
- preserve active Codex shells, ordinary user apps, and likely reusable dev services
- reserve the final sweep for temporary process trees that are definitely no longer needed

This repository includes the skill definition, agent metadata, PowerShell scripts, a shell wrapper, and Pester tests needed to reuse or adapt the skill in other Codex environments.
