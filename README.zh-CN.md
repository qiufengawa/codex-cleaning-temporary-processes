# Codex Cleaning Temporary Processes

[English](./README.md)

这是一个面向 Windows、macOS 和 Linux 的跨平台 Codex skill，用来在工具驱动的开发任务后检查并清理临时进程，同时避免误伤当前 Codex shell、普通用户应用和证据不足的长驻服务。

## 概览

在长时间开发会话里，shell、测试进程、构建辅助进程、浏览器调试进程和工作区运行时，常常会在任务步骤结束后继续留在后台。这个 skill 的目标，就是给 Codex 一套可重复的流程，让它识别这些残留，并且只回收那些已经明确结束、没有继续价值的临时进程。

它是一个公开的通用 skill，不绑定某一个项目、某一种技术栈，也不绑定某一个操作系统。

## 支持环境

- Windows
- macOS
- Linux

实现上采用共享的 PowerShell 主入口，并为 macOS / Linux 提供 shell wrapper。

## 运行要求

- Windows：默认就有 PowerShell
- macOS / Linux：需要安装 PowerShell 7，让 `pwsh` 可用
- 如果你的检出环境不会保留可执行位，就用 `bash` 来调用 Unix wrapper

## 生态覆盖

当前规则面向主流开发工作流，覆盖多个常见生态，包括：

- JavaScript / TypeScript 工具链，例如 `npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest`、`next`、`nuxt`、`astro`、`webpack`、`storybook`
- Node 后端和服务端工具，例如 `tsx`、`ts-node`、`ts-node-dev`、`nodemon`、`nest`、`remix`、`svelte-kit`
- Rust 工具链，例如 `cargo`、`cargo test`、`cargo tauri dev`
- Python 工具链，例如 `pytest`、`uvicorn`、`gunicorn`、`flask`、Django `runserver`
- JVM 和 .NET 工具链，例如 `java`、`gradle`、`mvn`、`dotnet`
- Go、Ruby、PHP、Elixir、Swift、Dart、Flutter 以及常见原生构建工具，只要命令证据和工作区证据足够强
- DevTools MCP、Playwright 风格自动化以及远程调试浏览器会话

这些示例只是代表性覆盖，不是穷举。这个 skill 主要依赖命令行证据、进程树关系和工作区匹配，而不是只针对某一种项目结构。

## 工作方式

这个 skill 采用三种模式：

- `inspect`：先分类，只看不杀
- `checkpoint-cleanup`：在高风险步骤结束后，只回收高置信度残留
- `cleanup`：在任务真正结束时，做最终清扫

整个实现拆成两层判断：

- 进程分类层负责回答“这是什么类型的进程”
- 清理策略层负责回答“当前模式下该保留、只检查，还是立即清理”

## 推荐使用策略

不要等到一个超长任务完全结束后才统一清理，更安全的方式是按短周期执行：

1. 当归属还不明确时，先跑 `inspect`
2. 每完成一次高风险步骤，例如测试、构建、一次性脚本、浏览器自动化或 DevTools MCP 之后，跑一次 `checkpoint-cleanup`
3. 再跑一次 `inspect`，确认只回收了预期残留
4. 只有在剩余临时进程树确定不再需要时，才使用 `cleanup`

## 安全边界

这个 skill 的策略是保守型的。

- 会保留当前 Codex shell 和 Codex helper shell
- 会保留没有自动化或远程调试标记的普通用户浏览器
- 当证据不够强时，会保留进程而不是强行清理
- 在 checkpoint 阶段，会把可能还要复用的开发服务保留在 `inspect-only`
- 只有在高置信度、并且当前步骤已经不再需要时，才会清理对应进程树

Checkpoint 清理主要面向这些对象：

- DevTools MCP 服务、launcher 和 watchdog
- 明确带有浏览器自动化或远程调试标记的会话
- 明确属于刚结束步骤的一次性 shell 和运行时
- 明确启动了 `chrome-devtools-mcp`、`playwright` 或 `--remote-debugging-port` 的 wrapper shell

## 它不会做什么

- 不会清理当前 Codex shell 或 Codex helper shell
- 不会清理没有自动化标记的普通用户浏览器
- 不会因为进程名叫 `node`、`python`、`java` 之类，就直接结束它
- 当证据不足时不会强行清理，而是保留在 `inspect-only`

## 仓库结构

- `SKILL.md`：公开 skill 说明和操作规则
- `agents/openai.yaml`：默认 agent 元数据和调用提示
- `scripts/process-inventory.ps1`：跨平台进程采集
- `scripts/process-classification.ps1`：进程分类规则
- `scripts/cleanup-policy.ps1`：清理决策策略
- `scripts/cleanup-temporary-processes.ps1`：共享的检查和清理入口
- `scripts/cleanup-temporary-processes.sh`：macOS / Linux shell wrapper
- `scripts/*.Tests.ps1`：进程采集、分类和策略行为的 Pester 测试
- `docs/project-introduction.md`：英文项目介绍
- `docs/project-introduction.zh-CN.md`：中文项目介绍

## 安装方式

1. 将这个仓库克隆或复制到你的 Codex skills 目录。
2. 放到 `$CODEX_HOME/skills/codex-cleaning-temporary-processes`，或你本机对应的 Codex skill 路径下。
3. 仓库目录名建议与 skill 名保持一致：`codex-cleaning-temporary-processes`。

## 使用方式

Windows：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

macOS / Linux 使用 PowerShell：

```bash
pwsh -NoProfile -File "$HOME/.codex/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.ps1" -Mode inspect -Workspace "/Users/example/project"
```

macOS / Linux 使用 shell wrapper：

```bash
bash "$HOME/.codex/skills/codex-cleaning-temporary-processes/scripts/cleanup-temporary-processes.sh" -Mode inspect -Workspace "/Users/example/project"
```

在高风险步骤结束后，把 `inspect` 换成 `checkpoint-cleanup`。只有在剩余临时进程树确定不再需要时，才使用 `cleanup`。

## 测试

运行仓库自带的 Pester 测试：

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
```

## 协议

本项目采用 [MIT License](./LICENSE)。
