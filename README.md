# Codex Cleaning Temporary Processes

[简体中文](./README.zh-CN.md)

Codex Cleaning Temporary Processes is a public, cross-platform skill for safely cleaning temporary development processes without crossing workspace boundaries.

## Pure Skill Model

This repository ships as a pure skill package.

- Install it under `CODEX_HOME/skills/codex-cleaning-temporary-processes`
- Keep `SKILL.md`, `agents/openai.yaml`, and `scripts/` together
- Rely on best-effort implicit invocation instead of plugin hooks or host callbacks

That means the skill can proactively guide Codex toward cleanup at the right moments, but it does not guarantee host-level automatic triggering. If your environment does not invoke the skill implicitly, explicitly ask for `$codex-cleaning-temporary-processes`.

## What It Covers

The skill is intentionally broader than a single frontend stack. It should reason about temporary process residue across mainstream toolchains such as:

- JavaScript and TypeScript: `npm`, `pnpm`, `yarn`, `bun`, `vite`, `vitest`, `jest`, `webpack`, `rollup`, `next`, `nuxt`, `turbo`
- Rust and native tooling: `cargo`, `rustc`, `tauri`, `trunk`
- Python: `python`, `uv`, `pip`, `pipenv`, `poetry`, `hatch`, `pytest`, `uvicorn`, `jupyter`, `streamlit`
- JVM and .NET: `java`, `mvn`, `gradle`, `kotlin`, `scala`, `dotnet`
- Other popular stacks: `go`, `ruby`, `bundle`, `rails`, `php`, `composer`, `artisan`, `elixir`, `mix`, `iex`, `rebar3`, `deno`
- Additional mainstream ecosystems: `clj`, `lein`, `ghci`, `runghc`, `cabal`, `stack`, `ocaml`, `dune`, `Rscript`, `perl`, `prove`, `cpanm`, `lua`, `luarocks`, `zig`
- Build, Apple, and report tooling: `julia`, `tox`, `nox`, `quarto`, `crystal`, `xcodebuild`, `bazel`, `buck2`
- Browser automation and remote debugging: `chrome-devtools-mcp`, Playwright-style tooling, headless browsers, remote-debug launchers

Coverage is language-agnostic, but cleanup is still conservative.
Coverage is broad across mainstream ecosystems, not exhaustive across every language or command.

## Trigger Cadence

Treat cleanup as checkpoint-scoped rather than task-scoped.

Use the public trigger classes below:

- `must reconsider now`
  Use this after a finished one-shot high-risk checkpoint succeeds or fails, after a finished DevTools, browser automation, or remote-debug checkpoint, after a finished subagent result, after a finished same-workspace batch of one-shot high-risk commands, or after a clearly safe final sweep request.
- `should reconsider soon`
  Use this when residue risk exists and backlog relief matters, but reuse is still plausible for part of the temporary tree.
- `do not reconsider from this checkpoint alone`
  Use this for low-risk inspection commands, long-lived `dev` or `watch` or `serve` sessions, session-end alone, or ambiguous workspace-free checkpoints.

Because this is a skill package, that cadence is best-effort implicit invocation, not guaranteed host automation.

Stronger trigger wording means stronger reconsideration, not stronger kill authority. Even a checkpoint marked `must reconsider now` may still resolve to `inspect` or preserve.

Use:

- `inspect` when reuse is still plausible
- `checkpoint-cleanup` when a finished checkpoint left high-confidence leftovers
- `cleanup` for the final sweep when the remaining temporary tree is clearly done

## Practical Limits

This package is still a pure skill, not a background plugin.

- It can improve Codex's odds of reconsidering cleanup at the right checkpoints
- It cannot inject fixed host hooks, timers, or always-on callbacks into the Codex app
- If your environment does not perform implicit invocation reliably enough, explicit use of `$codex-cleaning-temporary-processes` is still the honest fallback
- A failed one-shot high-risk checkpoint still counts, because residue can remain after errors too
- This is not stronger kill authority
- Broad toolchain coverage does not loosen the safety bar: ownership and workspace evidence still decide whether something is inspect-only or reclaimable
- Broader mainstream coverage still does not mean "all programming languages"
- Additional build, Apple, and scripting coverage still follows the same conservative ownership checks

## Safety Model

This skill is intentionally conservative.

- Preserve the active Codex shell and Codex helper shells
- Preserve ordinary browsers that do not carry automation or remote-debug flags
- Preserve ambiguous runtimes when ownership evidence is weak
- Preserve likely reusable dev servers during checkpoint cleanup
- Only clean high-confidence temporary process trees that no longer provide value to the current checkpoint

Explicit automation has extra guards:

- current-task lineage or confirmed current-thread ownership is required
- workspace match alone is not enough
- `Codex.exe app-server` ancestry can make a tree seedable, but not immediately killable
- `-ConfirmCurrentThreadExplicitAutomation` only applies to a first follow-up pass that explicitly confirms same-thread real use with a non-blank workspace
- current-thread ownership never broadens cleanup for generic runtimes

## Multi-Project Isolation

The skill must stay safe when several projects or Codex conversations are active at once.

- Workspace-backed build, test, serve, watch, and runtime processes must match the current workspace or a task-owned ancestor
- Explicit automation from another workspace or another conversation stays `inspect-only` unless current-task lineage or confirmed current-thread ownership proves ownership
- Generic runtimes do not become killable just because same-thread automation evidence exists

## Installation

1. Copy this repository to `CODEX_HOME/skills/codex-cleaning-temporary-processes`.
2. Keep `SKILL.md`, `agents/openai.yaml`, `scripts/`, and the docs together.
3. Let Codex use implicit invocation when available.
4. If implicit invocation does not happen in your environment, explicitly ask Codex to use `$codex-cleaning-temporary-processes`.

## Usage

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

macOS or Linux with PowerShell:

```bash
pwsh -NoProfile -File "$CODEX_HOME/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.ps1" -Mode inspect -Workspace "/Users/example/project"
```

macOS or Linux with the shell wrapper:

```bash
bash "$CODEX_HOME/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.sh" -Mode inspect -Workspace "/Users/example/project"
```

If a finished checkpoint in this same thread really used DevTools MCP, browser automation, or a remote-debug browser, add `-ConfirmCurrentThreadExplicitAutomation` on the first follow-up pass together with the workspace.

## Package Layout

The public package contains:

- [`SKILL.md`](./SKILL.md)
- [`agents/openai.yaml`](./agents/openai.yaml)
- PowerShell inventory, classification, policy, ledger, and cleanup scripts
- a shell wrapper for macOS and Linux
- English and Chinese documentation
- Pester tests

## Testing

Run the focused suites:

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\thread-ownership-ledger.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

Or run the full matrix:

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## License

This project is released under the [MIT License](./LICENSE).
