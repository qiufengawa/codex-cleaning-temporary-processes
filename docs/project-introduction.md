# Project Introduction

Codex Cleaning Temporary Processes is a Windows-focused Codex skill for safe process hygiene during development work.

It is meant for sessions where package managers, test runners, build tools, browser-debug helpers, DevTools MCP services, and workspace runtimes may leave behind temporary processes. Instead of waiting until the very end of a long task, the skill supports checkpoint cleanup after a risky step finishes, which keeps process buildup under control without broadly killing everything that looks developer-related.

The project follows a conservative operating model:

- inspect first when evidence is weak
- clean only high-confidence leftovers during checkpoint cleanup
- preserve active Codex shells, ordinary user apps, and likely reusable dev services
- use a final cleanup sweep only when the remaining temporary process trees are no longer needed

This repository includes the skill definition, agent metadata, PowerShell scripts, and Pester tests needed to reuse or adapt the skill in other Codex environments.
