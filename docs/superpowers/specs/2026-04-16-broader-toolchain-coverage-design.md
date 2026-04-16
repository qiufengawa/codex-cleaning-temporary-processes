# Broader Toolchain Coverage Design

## Goal

Expand the public skill's explicit toolchain coverage so it can safely reason about a wider set of mainstream development ecosystems, while keeping the cleanup model conservative and honest.

## Current Problem

The public package already covers many mainstream stacks, but it still leaves visible gaps for several ecosystems that appear in real multi-language coding workflows:

- Clojure tooling such as `clj` and `lein`
- Haskell tooling such as `ghci`, `runghc`, `cabal`, and `stack`
- OCaml tooling such as `ocaml` and `dune`
- R tooling such as `Rscript`
- Perl tooling such as `perl`, `prove`, and `cpanm`
- Lua tooling such as `lua` and `luarocks`
- Zig tooling such as `zig`

That gap weakens the public package in two ways:

- documentation over-promises "broad language-agnostic coverage" without enough concrete classifier support for those ecosystems
- users working across several repositories and languages can accumulate residue from unrecognized toolchains

## Requirements

- Keep the package as a pure skill, not a plugin.
- Keep multi-project isolation unchanged.
- Do not widen explicit-automation cleanup authority.
- Add explicit classifier support for more mainstream ecosystems, not every language under the sun.
- Keep the same conservative threshold: no workspace evidence means no cleanup classification.
- Add regression tests for each newly documented ecosystem.
- Update public docs so they describe broader mainstream coverage honestly, not "all programming languages."

## Approaches Considered

### Option A: Documentation-only broadening

Pros:

- low implementation effort
- improves public discoverability

Cons:

- dishonest if the classifier does not actually recognize the new tools
- does not reduce residue from the missing ecosystems

### Option B: Classifier-only broadening

Pros:

- behavior improves immediately
- minimal documentation churn

Cons:

- public readers still cannot see what is covered
- future maintainers can drift docs and implementation apart

### Option C: Test-led classifier and documentation broadening

Pros:

- keeps coverage claims honest
- improves real classification behavior
- makes future regression obvious

Cons:

- touches tests, classifier patterns, and docs together

## Recommended Design

Choose Option C.

## Coverage Model

Treat broader coverage as "more mainstream ecosystems are recognized under the same safety rules," not "cleanup becomes more aggressive."

### Positive coverage additions

Add explicit support for:

- Clojure: `clj`, `lein`
- Haskell: `ghci`, `runghc`, `cabal`, `stack`
- OCaml: `ocaml`, `dune`
- R: `Rscript`
- Perl: `perl`, `prove`, `cpanm`
- Lua: `lua`, `luarocks`
- Zig: `zig`

### Safety invariants

Keep these rules unchanged:

- workspace-backed evidence or a workspace-backed task-owned ancestor is still required
- generic runtimes do not become killable from same-thread explicit-automation evidence
- explicit automation still needs lineage or confirmed current-thread ownership
- docs must never claim coverage of all languages or all commands

## Classifier Changes

Update the public classifier pattern sets so the new ecosystems are recognized in the same three places used by the existing public package:

- direct tool names
- shell-wrapped workspace-scoped command lines
- generic runtime or direct-tool command lines for current-task processes

The new patterns should target common dev, test, run, build, serve, or repl-style markers rather than every command each tool can ever accept.

## Testing Strategy

- Add RED tests in `process-classification.Tests.ps1` for the new ecosystems.
- Include at least one negative test proving that missing workspace evidence still prevents classification.
- Extend the public trigger and documentation contract tests so README and project-introduction files mention the newly covered ecosystems.
- Re-run the full Pester matrix after the classifier and docs are updated.

## Out Of Scope

- claiming full coverage of all programming languages
- introducing background hooks or automatic host callbacks
- widening cleanup rights for explicit automation
- classifying arbitrary one-off scripts with no recognizable dev or test markers
