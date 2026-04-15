# Project Introduction

Codex Cleaning Temporary Processes is a public Windows-focused Codex skill for safe process hygiene during development work.

It is designed for sessions where package managers, dev servers, tests, browser automation, DevTools MCP helpers, and workspace-owned runtimes may leave behind temporary processes. Instead of waiting until the very end of a long task, the skill supports checkpoint cleanup after a risky step finishes. That keeps process buildup under control without broadly killing everything that looks developer-related.

The project follows a conservative policy:

- inspect before acting when evidence is weak
- clean only high-confidence leftovers during checkpoint cleanup
- preserve active Codex shells, ordinary user apps, and likely reusable dev services
- keep public examples sanitized and free of private workspace details

This repository contains the skill definition, agent metadata, PowerShell scripts, and Pester tests needed to reuse or adapt the skill in other Codex environments.
