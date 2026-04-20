# Codex Cleaning Temporary Processes

[English](./README.md)

Codex Cleaning Temporary Processes 是一个公开、跨平台的 skill，用于在不越过工作区边界的前提下，安全清理临时开发进程。

## 纯 Skill 形态

这个仓库以纯 skill 形态发布。

- 安装到 `CODEX_HOME/skills/codex-cleaning-temporary-processes`
- 保持 `SKILL.md`、`agents/openai.yaml` 和 `scripts/` 在一起
- 依赖最佳努力的隐式调用，而不是插件 hook 或宿主回调

这意味着这个 skill 可以主动引导 Codex 在合适时机重新考虑清理，但它本身不提供宿主级固定 hook、定时器或强制自动触发。如果你的环境里没有发生隐式调用，就显式要求 Codex 使用 `$codex-cleaning-temporary-processes`。

## 推荐的全局增强方案

如果你希望在继续保持纯 skill 形态的前提下，把触发率尽量拉高，最实用的办法是在 Codex 的全局指令层再加一层强化。

推荐的分层方式：

- 在 `~/.codex/config.toml` 的 `developer_instructions` 里放一段短而硬的规则
- 在 `~/.codex/AGENTS.md` 里放更完整的操作说明
- 同时继续把这个仓库安装在 `CODEX_HOME/skills/codex-cleaning-temporary-processes`

这样做的好处：

- 每个新开的 Codex 对话一开始就会把临时进程卫生当成默认工作纪律
- 在长任务里，Codex 更容易在已完成检查点之后主动重新评估清理，而不是一直拖到最后
- 即使用户没有手动提醒，inspect-first、显式自动化跟进和多项目隔离这些关键规则也更容易持续生效

这样做仍然不能改变的边界：

- 它仍然不会变成宿主 hook、定时器或常驻后台回调
- 它仍然不能保证百分之百自动触发
- 它仍然必须遵守同样的安全规则：先 `inspect`，只有证据足够强才回收，而且绝不能跨工作区或跨对话误杀

`developer_instructions` 示例模式：

```toml
developer_instructions = """
Use `$codex-cleaning-temporary-processes` as the default temporary-process hygiene strategy whenever coding work may leave temporary development processes, browser automation residue, helper shells, wrappers, launchers, watchdogs, test runners, build tools, or remote-debug chains.

This is a pure skill, not a host-level plugin. Do not pretend the host guarantees automatic callbacks. Instead, proactively reconsider cleanup at trigger-worthy finished checkpoints during normal work.

Hard rules:
- After every trigger-worthy finished checkpoint, inspect first.
- Only run `checkpoint-cleanup` if `inspect` explicitly reports `killable roots`.
- Reserve full `cleanup` for cases where the remaining temporary tree is clearly finished and no longer useful.
- Use `-ConfirmCurrentThreadExplicitAutomation` only on the first follow-up `inspect` after real same-thread DevTools MCP, browser automation, or remote-debug work, and only with a non-blank workspace.
- Never let workspace match alone authorize explicit automation cleanup.
- Never let same-thread ownership broaden cleanup for generic runtimes.
- Never kill the active Codex shell, ordinary interactive shells, ordinary browsers, reusable `dev` or `watch` or `serve` servers, or ambiguous user-owned runtimes.
- Never allow one project, workspace, worktree, conversation, or task to reclaim another project's processes.
- If evidence is weak, ambiguous, cross-workspace, or cross-thread, remain `inspect-only`.
- Reconsider cleanup after finished one-shot commands, finished browser automation, finished DevTools or remote-debug work, finished subagent batches, finished same-workspace batches, timeouts, interruptions, and user-requested final sweeps. Do not wait only for full task completion.
"""
```

建议让 `AGENTS.md` 负责：

- 保留 `developer_instructions` 里的短规则块
- 补充更完整的长文说明
- 在里面写清楚触发类型、显式自动化跟进、多项目隔离和报告要求

## 覆盖范围

这个 skill 面向公开场景，不局限于单一项目或单一语言。它应该能够理解主流工具链留下的临时进程残留，例如：

- JavaScript / TypeScript：`npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest`、`jest`、`webpack`、`rollup`、`next`、`nuxt`、`turbo`
- Rust 与原生工具链：`cargo`、`rustc`、`tauri`、`trunk`
- Python：`python`、`uv`、`pip`、`pipenv`、`poetry`、`hatch`、`pytest`、`uvicorn`、`jupyter`、`streamlit`
- JVM 与 .NET：`java`、`mvn`、`gradle`、`kotlin`、`scala`、`dotnet`
- 其他常见栈：`go`、`ruby`、`bundle`、`rails`、`php`、`composer`、`artisan`、`elixir`、`mix`、`iex`、`rebar3`、`deno`
- 新增主流生态：`clj`、`lein`、`ghci`、`runghc`、`cabal`、`stack`、`ocaml`、`dune`、`Rscript`、`perl`、`prove`、`cpanm`、`lua`、`luarocks`、`zig`
- 构建、Apple 与报告工具：`julia`、`tox`、`nox`、`quarto`、`crystal`、`xcodebuild`、`bazel`、`buck2`
- 浏览器自动化与远程调试：`chrome-devtools-mcp`、Playwright 风格工具、无头浏览器、remote-debug 启动链

覆盖范围很广，但清理策略仍然保守。这里强调的是“覆盖更多主流生态”，不是“穷尽所有编程语言或所有命令”。

## 触发节奏

把清理理解成按检查点触发，而不是等整个任务结束。

使用下面三档公开触发规则：

- `must reconsider now`
  适用于一次性高风险检查点成功之后、`failed one-shot high-risk` 这类失败检查点之后、DevTools 或浏览器自动化或远程调试检查点结束之后、子代理完成之后、同一工作区一批一次性高风险命令结束之后，或者用户明确要求最终清扫时。
- `should reconsider soon`
  适用于存在残留风险、需要缓解堆积，但部分进程仍然可能复用的场景。
- `do not reconsider from this checkpoint alone`
  适用于低风险检查命令、长生命周期的 `dev` / `watch` / `serve` 会话、`session-end alone`，以及缺少工作区归属的模糊检查点。

因为这是纯 skill 包，所以这里描述的是最佳努力的隐式调用，不是宿主保证的自动回调。

更强触发表示更强的重新评估义务，不表示更强的 kill 权限。即使某个检查点属于 `must reconsider now`，最终也仍然可能落到 `inspect` 或保留。

建议模式：

- 可能复用时，先用 `inspect`
- 已结束检查点留下高置信度残留时，用 `checkpoint-cleanup`
- 剩余临时进程树已经明确无用时，用 `cleanup`

## 动作协议

在纯 skill 的诚实边界内，最强的公开协议是：

- 在触发型检查点后先 `inspect`
- 如果 `inspect` 返回 `killable roots`，下一步再执行 `checkpoint-cleanup`
- 如果刚结束的检查点确实使用了同线程 DevTools MCP、浏览器自动化或远程调试，就在第一次后续 `inspect` 上加 `-ConfirmCurrentThreadExplicitAutomation`
- 读取返回结果里的 ledger path 和 state root 字段，确认当前线程 ownership 是否真的被写入

返回字段里会暴露：

- `threadOwnershipLedgerPath`
- `threadOwnershipStateRoot`

## 现实边界

这个包依然是纯 skill，不是后台插件。

- 它能提升 Codex 在合适检查点重新考虑清理的概率
- 它不能向 Codex 宿主注入固定 hook、定时器或常驻回调
- 如果你的环境里隐式调用不够稳定，显式要求使用 `$codex-cleaning-temporary-processes` 仍然是诚实且安全的兜底方案
- 一次性高风险检查点即使失败也要重新评估，因为失败同样可能留下残留
- 这不是更强的 kill 权限
- 覆盖更多主流生态不代表放宽安全线
- 这不是“所有编程语言都已覆盖”的承诺
- 新增构建、Apple 和脚本工具覆盖后，仍然遵守同一套保守归属判断

## 安全模型

这个 skill 刻意保持保守。

- 保留当前 Codex shell 和 Codex helper shell
- 保留没有自动化或远程调试标记的普通浏览器
- 当归属证据不足时，保留有歧义的 runtime
- 在检查点清理阶段保留可能仍可复用的开发服务
- 只清理对当前检查点已经没有价值的高置信度临时进程树

显式自动化有额外保护：

- 必须有当前任务链路或当前线程确认归属
- 仅有工作区匹配仍然不够
- `Codex.exe app-server` 祖先进程可以让对象进入可记账范围，但不能直接变成可清理
- `-ConfirmCurrentThreadExplicitAutomation` 只适用于第一次后续确认，而且必须和非空工作区一起使用
- 当前线程拥有权不会放宽普通 runtime 的清理范围

## 多项目隔离

当多个项目或多个 Codex 对话同时活跃时，这个 skill 也必须安全。

- 带工作区归属的 build、test、serve、watch 和 runtime 进程，必须匹配当前工作区或任务祖先进程
- 其他工作区或其他对话留下的显式自动化，除非当前任务链路或当前线程确认归属能够证明所有权，否则继续保持 `inspect-only`
- 仅有工作区匹配仍然不足以清理显式自动化
- 不能因为存在同线程自动化证据，就把普通 runtime 提升为可清理对象

## 安装方式

1. 把这个仓库复制到 `CODEX_HOME/skills/codex-cleaning-temporary-processes`。
2. 保持 `SKILL.md`、`agents/openai.yaml`、`scripts/` 和文档一起存在。
3. 在支持的环境里让 Codex 通过隐式调用使用这个 skill。
4. 如果你的环境没有发生隐式调用，就显式要求 Codex 使用 `$codex-cleaning-temporary-processes`。

## 使用方式

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

macOS / Linux 使用 PowerShell：

```bash
pwsh -NoProfile -File "$CODEX_HOME/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.ps1" -Mode inspect -Workspace "/Users/example/project"
```

macOS / Linux 使用 shell wrapper：

```bash
bash "$CODEX_HOME/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.sh" -Mode inspect -Workspace "/Users/example/project"
```

如果当前线程刚刚确实用过 DevTools MCP、浏览器自动化或远程调试浏览器，就在第一次后续检查时同时加上 `-ConfirmCurrentThreadExplicitAutomation` 和工作区。

## 包内容

公开包包含：

- [`SKILL.md`](./SKILL.md)
- [`agents/openai.yaml`](./agents/openai.yaml)
- PowerShell 盘点、分类、策略、账本和清理脚本
- macOS / Linux 的 shell wrapper
- 中英文文档
- Pester 测试

## 测试

运行重点测试：

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\thread-ownership-ledger.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

或者直接跑完整矩阵：

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## 许可证

本项目使用 [MIT License](./LICENSE)。
