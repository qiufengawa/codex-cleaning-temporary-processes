# Codex Cleaning Temporary Processes

[English](./README.md)

Codex Cleaning Temporary Processes 是一个公开的跨平台 skill，用来在不越过工作区边界的前提下，安全清理临时开发进程。

## 纯 Skill 形态

这个仓库以纯 skill 形式发布。

- 安装到 `CODEX_HOME/skills/codex-cleaning-temporary-processes`
- 保持 `SKILL.md`、`agents/openai.yaml` 和 `scripts/` 在一起
- 依赖最佳努力的隐式调用，而不是插件 hook 或宿主回调

这意味着 skill 可以主动引导 Codex 在合适的时机考虑清理，但它不能单靠自己提供宿主级的强自动触发。如果你的环境里没有发生隐式调用，就显式要求 Codex 使用 `$codex-cleaning-temporary-processes`。

## 覆盖范围

这个 skill 面向公开场景，不局限于单一前端项目。它应该能理解主流工具链留下的临时进程残留，例如：

- JavaScript / TypeScript：`npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest`、`jest`、`webpack`、`rollup`、`next`、`nuxt`、`turbo`
- Rust 与原生工具链：`cargo`、`rustc`、`tauri`、`trunk`
- Python：`python`、`uv`、`pip`、`poetry`、`hatch`、`pytest`
- JVM 与 .NET：`java`、`mvn`、`gradle`、`dotnet`
- 其他常见栈：`go`、`ruby`、`bundle`、`rails`、`php`、`composer`、`artisan`、`elixir`、`mix`、`deno`
- 浏览器自动化与远程调试：`chrome-devtools-mcp`、Playwright 风格工具、无头浏览器、远程调试启动链路

覆盖范围广，不代表清理策略激进。最终是否清理仍然由安全规则决定。

## 触发节奏

把清理理解成按检查点触发，而不是等整个任务结束。

这个 skill 适合在下面这些“已结束检查点”之后重新评估：

- 某个 build、test、install、preview、serve、watch 或一次性 runtime 步骤已经结束
- 某个 DevTools、浏览器自动化或远程调试步骤已经结束
- 某个子代理已经结束，且它拉起的 helper 已经没有复用价值
- 一批一次性命令已经结束，进程积压需要缓解
- 当前工作分支已经暂停，适合做一次明确安全的最终清扫

因为这是纯 skill 包，所以这里描述的是最佳努力的隐式调用，不是宿主保证的自动回调。

模式建议：

- 可能复用时，先用 `inspect`
- 已结束检查点留下高置信度残留时，用 `checkpoint-cleanup`
- 剩余临时进程树已经明确无用时，用 `cleanup`

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
- 其他工作区或其他对话留下的显式自动化，除非当前任务链路或当前线程确认归属能证明所有权，否则继续保持 `inspect-only`
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
