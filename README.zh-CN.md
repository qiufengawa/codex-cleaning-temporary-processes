# Codex Cleaning Temporary Processes

[English](./README.md)

这是一个面向 Windows 的安全优先 Codex skill，用来管理开发过程中的临时进程。它会在工具驱动的工作结束后，帮助你检查并清理临时 shell、测试进程、浏览器调试辅助进程和工作区相关运行时，同时避免误杀当前 Codex 会话、普通用户应用和含糊不清的长驻服务。

## 为什么需要这个 Skill

在较长的 Codex 任务里，`npm`、`vite`、`vitest`、`cargo`、`tauri`、浏览器调试工具、DevTools MCP 之类的步骤，往往会留下额外的 shell、辅助进程和运行时。如果等到整个大任务结束才统一处理，累积会越来越重。

这个 skill 提供了一个分阶段清理模型：

- `inspect`：先分类，查看哪些是候选进程、哪些是受保护进程
- `checkpoint-cleanup`：在某个高风险步骤结束后，只回收高置信度且已经没有复用价值的残留进程
- `cleanup`：在任务真正结束时，对剩余可清理的临时进程树做最终清扫

## 安全模型

这个仓库面向公开发布，因此清理策略刻意保持保守。

- 永远不清理当前 Codex shell 和 Codex 辅助 shell
- 永远不清理没有自动化或远程调试标记的普通浏览器
- 永远不清理和当前任务证据不匹配的用户自有运行时
- 在 checkpoint 清理里，永远不清理证据不足的模糊进程
- 如果后续步骤可能复用某个进程，优先先跑 `inspect`

Checkpoint 清理只针对以下高置信度对象：

- DevTools MCP 服务、launcher 和 watchdog
- 显式带有浏览器自动化或远程调试标记的进程
- 明确属于刚结束步骤的一次性 shell 和运行时
- 明确启动了 `chrome-devtools-mcp`、`playwright` 或 `--remote-debugging-port` 的高置信度 wrapper shell

像 `dev`、`serve`、`preview`、`watch`、`runserver`、`start` 这类长驻开发服务，在 checkpoint 阶段会保留为 `inspect-only`。

## 覆盖范围

当前规则已经覆盖了多个生态里具有代表性的模式。示例不是穷举，但现有规则已经包含：

- JavaScript / TypeScript 生态中的 `npm`、`pnpm`、`yarn`、`bun`、`vite`、`vitest` 以及常见框架开发命令
- Rust / Tauri 的 shell 工作流，例如 `cargo` 和 `cargo tauri dev`
- Python 开发和测试命令，例如 `pytest`、`uvicorn`、`flask`、Django `runserver`
- 当工作区匹配足够强时，.NET、Go、Ruby、PHP、Java 的开发或测试流程
- DevTools MCP、Playwright 风格自动化以及带远程调试标记的浏览器会话

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
3. 仓库文件夹名建议和 skill 名保持一致：`codex-cleaning-temporary-processes`。

## 使用方式

先做检查：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-cleaning-temporary-processes\scripts\cleanup-temporary-processes.ps1" -Mode inspect -Workspace "C:\Projects\ExampleApp"
```

在某个高风险步骤结束后做 checkpoint 清理：

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

## 隐私与脱敏

这个公开包应该只包含已经脱敏的 skill 源码。

- 使用 `C:\Projects\ExampleApp` 这样的中性占位路径
- 不要提交私有工作区路径、真实项目名或机器特定信息
- 不要发布包含用户特定信息的进程采样输出

## 协议

本项目采用 [MIT License](./LICENSE)。
