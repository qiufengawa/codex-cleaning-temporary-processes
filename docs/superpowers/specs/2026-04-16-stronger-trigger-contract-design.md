# Stronger Trigger Contract Design

## Goal

Strengthen when the public pure skill must reconsider cleanup, without pretending to install host hooks, background callbacks, or any plugin-style automation inside Codex.

## Current Problem

The current public package already says cleanup should be reconsidered at finished checkpoints, but the trigger language is still too soft and too broad in two ways:

- it does not clearly separate "must reconsider now" from "cleanup may still resolve to inspect-only"
- it still carries fixture naming that looks hook-shaped even though the public package now explicitly says it is a pure skill

That combination weakens the skill in practice. Codex has less precise trigger language to latch onto, while human readers can still over-infer private host-hook behavior from the public repository layout.

## Requirements

- Keep the repository as a pure skill package.
- Do not introduce plugin manifests, hook entrypoints, or host-callback claims.
- Strengthen the trigger contract around finished checkpoints using language Codex can reuse implicitly.
- Make it explicit that stronger triggering means stronger reconsideration, not broader kill authority.
- Treat failed one-shot high-risk steps as trigger-worthy, because failures can still leave residue behind.
- Add explicit negative trigger cases so long-lived workflows do not become over-eager cleanup prompts.
- Rename public trigger sample fixtures so they read as checkpoint simulations rather than host-hook payloads.
- Lock the public contract in tests so future edits cannot silently drift back toward hook-like language or weaker trigger rules.

## Approaches Considered

### Option A: Prompt-only strengthening

Pros:

- low implementation cost
- improves search and implicit invocation odds

Cons:

- does not fully lock the contract in tests
- does not remove the misleading hook-shaped fixture naming

### Option B: Contract-only strengthening

Pros:

- highly honest
- easy to regression-test

Cons:

- less likely to improve actual implicit pickup if metadata wording stays soft

### Option C: Hybrid stronger-trigger contract

Pros:

- strengthens metadata and docs for better implicit pickup
- strengthens tests so the public contract stays honest
- removes misleading fixture naming without changing the packaging model

Cons:

- touches more files
- requires bilingual doc updates

## Recommended Design

Choose Option C.

## Trigger Model

Separate trigger strength from cleanup authority.

### Layer 1: Trigger obligation

The skill publicly defines checkpoint classes for when Codex should reconsider cleanup:

- `must reconsider now`
- `should reconsider soon`
- `do not reconsider from this checkpoint alone`

### Layer 2: Cleanup decision

After reconsideration, the existing safety model still decides whether the result is:

- `inspect`
- `checkpoint-cleanup`
- `cleanup`
- preserve

The stronger trigger layer never changes process ownership or killability by itself.

## Public Contract

### Must reconsider now

Use this class for:

- successful one-shot high-risk commands such as build, test, install, package, verify, or one-shot runtime passes
- failed one-shot high-risk commands in the same categories
- finished DevTools, browser automation, or remote-debug checkpoints
- completed subagent checkpoints
- completed same-workspace batches of high-risk one-shot commands
- explicit user requests for a final sweep

### Should reconsider soon

Use this class for:

- finished checkpoints where residue risk exists but reuse value is still plausible
- backlog-relief situations where temporary helpers may be accumulating but the next step may still reuse some of them

### Do not reconsider from this checkpoint alone

Use this class for:

- low-risk commands such as reads, greps, listing, or harmless inspection
- launching or continuing long-lived `dev`, `watch`, `serve`, preview, or storybook-style sessions from the checkpoint alone
- session-end language by itself
- ambiguous or workspace-free situations with no clear task ownership

## Fixture Contract

- Rename `scripts/hook-trigger-fixtures` to `scripts/trigger-fixtures`.
- Treat every fixture as a checkpoint regression sample, not a host-hook payload.
- Prefer neutral names such as:
  - `checkpoint-one-shot-success.json`
  - `checkpoint-one-shot-failure.json`
  - `checkpoint-explicit-automation.json`
  - `checkpoint-subagent-complete.json`
  - `checkpoint-batch-finished.json`
  - `checkpoint-low-risk.json`
  - `checkpoint-long-running-dev.json`
  - `checkpoint-session-end.json`

Fixture content may still include example event-like fields, but the public docs and tests must frame them as simulated checkpoint samples rather than host integration requirements.

## Documentation Changes

- `SKILL.md` should present the three trigger classes and the "reconsider, do not auto-kill" boundary.
- `agents/openai.yaml` should explicitly bias toward reconsideration after fixed high-risk checkpoints, including failure cases.
- `README.md` and `README.zh-CN.md` should explain the stronger trigger contract in end-user terms.
- Trigger scenario docs should become positive and negative contract documents instead of only a short scenario list.

## Testing Strategy

- Add RED tests that require stronger trigger wording in English and Chinese docs.
- Add RED tests that require negative trigger rules for low-risk commands, long-lived dev sessions, and session-end-alone cases.
- Add RED tests that require failure-trigger wording for one-shot high-risk steps.
- Add RED tests that require the neutral fixture directory and forbid the old hook-shaped public fixture name.
- Keep the existing anti-plugin guarantees in place.

## Out of Scope

- adding host hooks, timers, callbacks, or background daemons
- changing process killability logic
- reintroducing plugin packaging
- claiming deterministic implicit invocation inside Codex
