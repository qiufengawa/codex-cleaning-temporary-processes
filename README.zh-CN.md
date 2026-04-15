# Codex Cleaning Temporary Processes

[English](./README.md)

这是一个面向 Windows 的安全优先 Codex skill，用来在工具驱动的开发任务后检查并清理临时进程，同时避免误伤当前 Codex shell、普通用户应用和证据不足的长驻服务。

## 概览

在 Windows 开发会话里，包管理器、测试命令、构建命令、浏览器调试工具和工作区运行时，经常会留下额外的 shell、辅助进程和子进程树。这个 skill 的作用，就是给 Codex 一套稳定的流程，让它能识别这些残留，并且只清理那些已经明确结束、没有继续复用价值的进程。

它尤其适合长任务场景，因为很多一次性命令其实在某一步结束后就已经没有用了，没有必要一直堆到整个任务收尾时再一起处理。

## 它解决什么问题

- `npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest`、`cargo`、`tauri` 等命令结束后留下的临时 shell 和辅助进程
- DevTools MCP、远程调试、浏览器自动化步骤结束后残留的 helper 进程
- 长任务中“一步一堆积”的临时进程问题
- 过度清理带来的误杀风险，例如把所有 shell 或运行时都当成可随手结束的对象

## 工作方式

这个 skill 采用三种模式：

- `inspect`：先分类，只看不杀
- `checkpoint-cleanup`：在高风险步骤结束后，只回收高置信度残留
- `cleanup`：在任务真正结束时，做最终清扫

整个实现拆成两层判断：

- 进程分类层负责回答“这是什么类型的进程”
- 清理策略层负责回答“当前模式下该保留、只检查，还是立即清理”

## 安全边界

这个 skill 的策略是保守型的。

- 会保留当前 Codex shell 和 Codex helper shell
- 会保留没有自动化或远程调试标记的普通浏览器
- 当证据不够强时，会保留进程而不是强行清理
- 在 checkpoint 阶段，会把可能还要复用的开发服务保持在 `inspect-only`
- 只有在高置信度、并且当前步骤已经不再需要时，才会清理对应进程树

Checkpoint 清理主要面向这些对象：

- DevTools MCP 服务、launcher 和 watchdog
- 明确带有浏览器自动化或远程调试标记的会话
- 明确属于刚结束步骤的一次性 shell 和运行时
- 明确启动了 `chrome-devtools-mcp`、`playwright` 或 `--remote-debugging-port` 的 wrapper shell

## 覆盖范围

当前规则已经覆盖多个常见生态中的代表性模式，包括：

- JavaScript / TypeScript 工作流，例如 `npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest` 和常见框架开发命令
- Rust / Tauri 工作流，例如 `cargo` 和 `cargo tauri dev`
- Python 工作流，例如 `pytest`、`uvicorn`、`flask` 和 Django `runserver`
- 当工作区证据足够强时，.NET、Go、Ruby、PHP、Java 的开发或测试流程
- DevTools MCP、Playwright 风格自动化以及远程调试浏览器会话

## 仓库结构

- `SKILL.md`：公开 skill 说明和操作规则
- `agents/openai.yaml`：默认 agent 元数据和调用提示
- `scripts/process-classification.ps1`：进程分类规则
- `scripts/cleanup-policy.ps1`：清理决策策略
- `scripts/cleanup-temporary-processes.ps1`：检查和清理入口脚本
- `scripts/*.Tests.ps1`：分类和策略行为的 Pester 测试
- `docs/project-introduction.md`：英文项目介绍
- `docs/project-introduction.zh-CN.md`：中文项目介绍

## 安装方式

1. 将这个仓库克隆或复制到你的 Codex skills 目录。
2. 放到 `$CODEX_HOME/skills/codex-cleaning-temporary-processes`，或你本机对应的 Codex skill 路径下。
3. 仓库目录名建议与 skill 名保持一致：`codex-cleaning-temporary-processes`。

## 使用方式

先做检查：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

在高风险步骤结束后做 checkpoint 清理：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode checkpoint-cleanup -Workspace "C:\Projects\ExampleApp"
```

只有在任务结束，或者剩余临时进程树确定不再需要时，再做最终清理：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode cleanup -Workspace "C:\Projects\ExampleApp"
```

## 测试

运行仓库自带的 Pester 测试：

```powershell
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
```

## 协议

本项目采用 [MIT License](./LICENSE)。
