# Codex Cleaning Temporary Processes

[English](./README.md)

这是一个面向 Windows、macOS 和 Linux 的跨平台 Codex skill，用来在工具驱动的开发工作后安全地检查和清理临时开发进程，同时避免误伤当前 Codex shell、普通用户应用和证据不足的长期服务。

## 概述

长时间开发会话里，shell、测试进程、构建辅助进程、浏览器调试进程以及工作区运行时，常常会在某个步骤结束后继续残留在后台。这个 skill 的目标，就是给 Codex 一套可重复的流程，让它识别这些残留，并且只回收那些已经明确完成使命、不会再被复用的临时进程。

这是一个公开、通用的 skill，不绑定某一个项目、不绑定某一种技术栈，也不绑定某一种操作系统。

## 支持环境

- Windows
- macOS
- Linux

实现上使用统一的 PowerShell 主入口，并为 macOS / Linux 提供 shell wrapper。

## 运行要求

- Windows：默认自带 PowerShell
- macOS / Linux：需要安装 PowerShell 7，并保证 `pwsh` 可用
- 如果你的检出环境不会保留可执行位，可以直接通过 `bash` 调用 Unix wrapper
- 如果 Codex 能在 shell 环境里暴露 `CODEX_THREAD_ID`，当前线程显式 automation 回收会更可靠；如果没有这个线程 id，skill 会自动退回到只依赖工作区和当前任务证据

## 生态覆盖

当前规则面向主流开发工作流，覆盖多个常见生态，包括：

- JavaScript / TypeScript 工具链，例如 `npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest`、`next`、`nuxt`、`astro`、`webpack`、`storybook`
- Node 后端和服务端工具，例如 `tsx`、`ts-node`、`ts-node-dev`、`nodemon`、`nest`、`remix`、`svelte-kit`
- Rust 工具链，例如 `cargo`、`cargo test`、`cargo tauri dev`
- Python 工具链，例如 `pytest`、`uvicorn`、`gunicorn`、`flask`、Django `runserver`
- JVM 和 .NET 工具链，例如 `java`、`gradle`、`mvn`、`dotnet`
- Go、Ruby、PHP、Elixir、Swift、Dart、Flutter 以及常见原生构建工具，只要命令证据和工作区证据足够强
- DevTools MCP、Playwright 风格自动化以及远程调试浏览器会话

这些例子只是代表性覆盖，不是穷举。这个 skill 依赖的是命令行证据、进程树关系和工作区匹配，而不是只针对某一种项目结构。

对于普通的 build、test、serve、run 这类流程，建议尽量传入 `-Workspace`。如果没有工作区证据，脚本会保持保守，只把显式自动化和远程调试标记视为高置信度目标。

## 工作方式

这个 skill 使用三种模式：

- `inspect`：输出已分类的临时目标以及能被明确识别出来的受保护类型，只看不杀
- `checkpoint-cleanup`：在高风险步骤结束后，只回收高置信度残留
- `cleanup`：在任务真正结束时，对仍然可清理的临时进程树做最终清扫

底层实现分成两层判断：

- 进程分类层负责回答“这是什么类型的进程”
- 清理策略层负责回答“当前模式下它该保留、仅检查，还是立即清理”

## 归属判断信号

这个 skill 在判断一个进程是否属于“当前任务”时，策略是刻意保守的。

- 优先传入 `-Workspace`，让命令行可以和当前仓库或项目路径进行匹配
- 相对路径启动的子进程，只有在父进程或祖先进程已经同时具备工作区证据以及明确的 dev、test、build、serve、watch 标记时，才会继承当前任务归属
- 显式 automation 和远程调试进程，只有在当前工作区或当前任务归属证据足够强时才会进入可清理范围，否则保持 `inspect-only`
- 本地的“当前线程归属账本”可以让同一个 Codex 对话在先前已经证明归属之后，继续回收自己的显式 automation，即使原始 launcher shell 之后已经退出
- 当前线程归属不会单独把普通 runtime 或普通开发工具放宽成可清理目标
- 仅仅因为进程链路挂在 Codex shell 下面，并不会自动变成可杀目标
- 只要证据不够强或者存在歧义，就保持 `inspect-only`，甚至直接忽略

## 推荐使用策略

不要等到一个超长任务完全结束后再统一清理，更安全的方式是按短周期执行：

1. 当归属还不明确时，先跑 `inspect`。
2. 每完成一次高风险步骤，例如测试、构建、一次性脚本、浏览器自动化或 DevTools MCP 后，跑一次 `checkpoint-cleanup`。
3. 再跑一次 `inspect`，确认只回收了预期残留。
4. 只有在剩余临时进程树明确不再需要时，才使用 `cleanup`。

## 触发节奏

把触发理解成“按步骤判断”，而不是“只在整项任务结束后判断”：

- 让 Codex 在每个已经结束的高风险步骤之后重新判断是否要使用这个 skill，不要只等任务最终结束。
- 在 DevTools MCP、浏览器远程调试或 Playwright 风格流程结束后重新判断。
- 如果子代理在完成工作后，可能留下 shell、运行时、浏览器辅助进程、测试、构建或开发服务，也要重新判断。
- 在一批一次性 shell 或工具命令执行完、且这些进程已经没有复用价值之后，也要重新判断。
- 如果下一步可能复用这些进程，优先 `inspect`；如果该步骤已经明确结束，再使用 `checkpoint-cleanup`。

## 安全边界

这个 skill 的策略是保守型的。

- 会保留当前 Codex shell 和 Codex helper shell
- 会保留没有自动化或远程调试标记的普通浏览器
- 如果无法证明属于当前任务，也会保留 DevTools MCP、浏览器自动化和远程调试会话
- 对于同一个 Codex 对话先前已经证明归属的显式 automation，后续步骤仍然可以通过当前线程归属继续回收
- 当证据不够强时，会保留进程而不是强行清理
- 在 checkpoint 阶段，会把可能还要复用的开发服务保留为 `inspect-only`
- 只有在高置信度且当前步骤已经不再需要时，才会清理对应进程树

Checkpoint 清理主要面向这些对象：

- DevTools MCP 服务、launcher 和 watchdog
- 明确带有浏览器自动化或远程调试标记的会话
- 明确属于刚结束步骤的一次性 shell 和运行时
- 明确启动了 `chrome-devtools-mcp`、`playwright` 或 `--remote-debugging-port` 的 wrapper shell

`checkpoint-cleanup` 是面向已结束步骤的增量清理；`cleanup` 是任务尾声使用的最终清扫。

## 多项目安全

当多个 Codex 对话、多个分支或多个仓库同时活跃时，这个 skill 默认只清理属于“当前任务”的进程。

- 带工作区归属的 dev、test、build、serve、runtime 进程，必须匹配当前工作区或当前任务祖先进程。
- DevTools MCP、Playwright 风格 helper、远程调试浏览器这类显式 automation，如果还不能证明属于当前任务，就保持 `inspect-only`。
- 当前线程归属只用于“同一个 Codex 对话已经证明归属”的显式 automation 兜底，不代表同工作区下可以宽泛清理所有对象。
- 仅仅因为同属 Codex 进程链路，并不意味着一个项目可以清理另一个项目的进程树。

## 它不会做什么

- 不会清理当前 Codex shell 或 Codex helper shell
- 不会清理没有自动化标记的普通用户浏览器
- 不会因为进程名叫 `node`、`python`、`java` 之类，就直接结束它
- 如果还不能建立当前任务归属，也不会去清理其他工作区或其他 Codex 对话留下的 DevTools MCP、浏览器自动化或远程调试会话
- 不会只因为“当前线程归属”存在，就去结束普通的 dev、test、build 或 runtime 进程
- 不会把“挂在 Codex shell 下面”本身当成当前任务归属的充分证据
- 当证据不足时不会强行清理，而是保留在 `inspect-only`
- 直接浏览器进程匹配当前主要覆盖 Chromium / Edge 家族的远程调试会话；非 Chromium 浏览器自动化更多依赖 helper 或 wrapper 进程来识别

## 输出结构

`inspect` 返回当前分类快照：

- `matchedCount`
- `killableRoots`
- `decisionCounts`
- `processes`

`checkpoint-cleanup` 和 `cleanup` 会返回清理后的重新检查结果，以及 kill 统计：

- `matchedCount`
- `killableRoots`
- `decisionCounts`
- `killedCount`
- `killedIds`
- `failedCount`
- `failedIds`
- `processes`

其中 cleanup 模式下的 `processes` 是 kill 尝试之后重新检查得到的结果，因此调用方看到的是“现在还剩什么”，而不是“清理前看到了什么”。

`inspect` 返回的是“已分类记录”，不是完整进程表转储。对于证据不足或未命中的对象，脚本可能会选择保留并且不在输出里展示。

## 仓库结构

- `SKILL.md`：公开 skill 说明和操作规则
- `agents/openai.yaml`：默认 agent 元数据和调用提示
- `scripts/process-inventory.ps1`：跨平台进程采集
- `scripts/process-classification.ps1`：进程分类规则
- `scripts/cleanup-policy.ps1`：清理决策策略
- `scripts/cleanup-temporary-processes.ps1`：统一的检查与清理入口
- `scripts/thread-ownership-ledger.ps1`：用于显式 automation 回收的本地“当前线程归属账本”
- `scripts/cleanup-temporary-processes.sh`：macOS / Linux shell wrapper
- `scripts/*.Tests.ps1`：覆盖采集、分类、策略和入口行为的 Pester 测试
- `docs/project-introduction.md`：英文项目介绍
- `docs/project-introduction.zh-CN.md`：中文项目介绍
- `docs/trigger-regression-scenarios.md`：英文触发时机场景
- `docs/trigger-regression-scenarios.zh-CN.md`：中文触发时机场景

当前线程归属状态属于本地运行时数据，不会包含在公开包里。启用时，默认写到 `$CODEX_HOME/state/codex-cleaning-temporary-processes/thread-ownership/`；如果 `CODEX_THREAD_ID` 不可用，脚本就不会启用这层优化，而是继续只依赖工作区和当前任务证据。

## 安装方式

1. 将这个仓库克隆或复制到你的 Codex skills 目录。
2. 放到 `$CODEX_HOME/skills/codex-cleaning-temporary-processes`，或你本机对应的 Codex skill 路径下。
3. 仓库目录名建议与 skill 名保持一致：`codex-cleaning-temporary-processes`。

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

当高风险步骤结束后，可以把 `inspect` 换成 `checkpoint-cleanup`。只有在剩余临时进程树明确不再需要时，才使用 `cleanup`。

例如，在 DevTools MCP、测试或其他一次性步骤结束后，可以这样做增量清理：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:CODEX_HOME\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode checkpoint-cleanup -Workspace "C:\Projects\ExampleApp"
```

## 故障排查

- 如果进程还在持续堆积，请显式要求 Codex 使用 `$codex-cleaning-temporary-processes`。
- 如果一个长任务始终停留在同一个 assistant 回合里，应该在已结束的步骤之间请求 checkpoint cleanup，而不是只等最终回答。
- 如果下一步可能还要复用某个进程，先让 Codex 跑 `inspect`，不要直接强制清理。
- 如果某个进程没有被清理，可能是因为缺少工作区证据、自动化标记或其他高置信度归属信号，这通常是有意保守保留下来的结果。
- 如果某些已经脱离 launcher 的 DevTools 或浏览器调试辅助进程本来就属于当前这个 Codex 对话，后续一次检查仍然可能通过“当前线程归属”把它们回收掉。
- 如果同时有多个 Codex 对话或多个项目在运行，无法证明属于当前任务的 DevTools 或浏览器调试残留会继续保持 `inspect-only`，这是为了避免跨项目误杀。

## 测试

可以分别运行这些测试：

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

也可以直接跑完整矩阵：

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## 协议

本项目采用 [MIT License](./LICENSE)。
