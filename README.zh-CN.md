# Codex Cleaning Temporary Processes

[English](./README.md)

Codex Cleaning Temporary Processes 是一个公开的跨平台包，用于在 Windows、macOS 和 Linux 上安全清理临时开发进程。

## 公开包模型

这个仓库支持两种面向用户的安装方式：

- 插件式安装：保持仓库根目录完整，包含 `.codex-plugin/plugin.json`、`hooks.json` 和 `hooks/`。这是启用自动强触发的安装即运行路径。
- skill 式安装：将仓库放到 `CODEX_HOME/skills/codex-cleaning-temporary-processes` 下，可以看到 `SKILL.md`、`agents/openai.yaml` 和脚本，但不会自动启用插件 hook 行为。

已安装的插件包负责自动检查点，独立的 [`SKILL.md`](./SKILL.md) 继续作为手动兜底入口。自动触发改变的是 Codex 何时重新检查清理，而不是它被允许清理什么。

## 自动强触发

当包以插件式安装启用时，它应当在固定检查点自动重新评估清理，例如：

- 每个已结束的高风险工具步骤之后
- DevTools MCP、浏览器自动化或远程调试步骤结束之后
- 一批一次性 helper 已完成且不再有复用价值之后
- 子代理结束之后
- 会话结束时的最终清扫

这种固定检查点模型是刻意设计的。自动路径不应该依赖“等任务快结束时再想起清理”，而应该在明确结束的检查点发生后尽快处理，避免进程堆积。

## 手动兜底

当包只以 skill 式安装存在，或者插件 hook 不可用时，`SKILL.md` 就是手动兜底指南。

手动路径适合用来：

- 让 Codex 显式运行 `inspect`、`checkpoint-cleanup` 或 `cleanup`
- 解释为什么某个进程被判定为 `cleanup-now`、`inspect-only` 或 `preserve`
- 在清理前先做一次显式审查

手动路径仍然应该遵循同样的固定检查点。如果几个高风险步骤已经结束，就不要等整个任务结束后才检查残留。

## 触发节奏

把清理理解为按检查点触发：

- 每个已结束的高风险步骤之后重新评估
- DevTools MCP 或浏览器调试检查点结束之后重新评估
- 子代理结果返回且其工具链不再需要时重新评估
- 一批一次性命令完成、需要做积压缓解时重新评估
- 会话结束时重新评估最终清扫

当步骤已经明确结束时，优先使用 `checkpoint-cleanup`；如果下一步仍可能复用进程，则先用 `inspect`。

## 安全模型

这个包刻意保持保守。

- 保留当前 Codex shell 和 Codex helper shell
- 保留没有自动化或远程调试标记的普通浏览器
- 当归属证据不足时保留存在歧义的 runtime
- 在 checkpoint 清理阶段保留可能仍可复用的开发服务
- 只清理对当前检查点已经没有价值的高置信度临时进程树

显式自动化有额外保护：

- 必须有当前任务链路证据或当前线程拥有的显式自动化证据
- 仅有工作区匹配仍然不够
- `Codex.exe app-server` 祖先进程只能让显式自动化进入可记录范围，不能直接变成可清理
- `-ConfirmCurrentThreadExplicitAutomation` 只适用于第一次后续确认，而且必须显式确认同一线程刚刚真的使用过该自动化，并且工作区非空
- 当前线程拥有权不会放宽普通 runtime 的清理范围

## 多项目隔离

当多个项目或多个 Codex 对话同时活跃时，这个包也必须保持安全。

- 带工作区归属的 build、test、serve、watch 和 runtime 进程，必须匹配当前工作区或当前任务祖先进程
- 其他工作区或其他 Codex 对话留下的显式自动化，除非能证明当前任务链路归属或当前线程确认归属，否则保持 `inspect-only`
- 当前线程拥有权只是同一对话、同一工作区下显式自动化的兜底恢复信号
- 不能因为存在同线程自动化声明，就把普通 runtime 直接提升为可清理对象

## 清理与本地状态

同线程显式自动化恢复会在本地运行时状态里使用经过清理的线程标识和规范化的工作区值。

- 优先写入 `CODEX_HOME/state/codex-cleaning-temporary-processes/...`
- 如果没有 `CODEX_HOME`，则退回到操作系统临时目录
- 这些本地状态只是运行期辅助数据，不会成为放宽清理权限的理由

## 跨平台打包内容

这个公开包包含：

- [`SKILL.md`](./SKILL.md)：手动兜底指南
- [`agents/openai.yaml`](./agents/openai.yaml)：安装时元数据和默认自动提示
- `.codex-plugin/plugin.json`、`hooks.json` 和 `hooks/`：插件式自动检查点
- 用于盘点、分类、策略、账本和清理的 PowerShell 脚本
- macOS / Linux 的 shell wrapper
- 英文主文档和中文配套文档
- 用于触发、分类、策略和入口行为的 Pester 测试

这个包从设计上就是跨平台的：

- Windows 直接使用 PowerShell
- macOS 和 Linux 可以使用 `pwsh`
- macOS 和 Linux 也可以使用提供的 `bash` wrapper

## 运行要求

- Windows：默认自带 PowerShell
- macOS / Linux：安装 PowerShell 7 并保证 `pwsh` 可用
- 如果你的检出环境不保留可执行位，可以通过 `bash` 调用 Unix wrapper

## 安装方式

### 插件式安装

当你需要自动强触发时，使用这个模式。

1. 保持仓库根目录完整，确保 `.codex-plugin/plugin.json`、`hooks.json`、`hooks/`、`agents/openai.yaml` 和 `scripts/` 一起存在。
2. 通过你的 Codex 插件流程安装或启用这个包。
3. 确认当前环境支持插件 hook，这样固定检查点才能自动运行。

### skill 式安装

当你只需要手动 skill 文本和脚本时，使用这个模式。

1. 把包放到 `CODEX_HOME/skills/codex-cleaning-temporary-processes`。
2. 使用独立的 `SKILL.md` 指南，或者直接调用脚本。
3. 不要期待 skill 式安装本身带来自动 hook 行为。

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

如果某个已结束的检查点确实在当前线程里使用过 DevTools MCP、Playwright 风格自动化或远程调试浏览器，就在第一次后续检查时同时加上 `-ConfirmCurrentThreadExplicitAutomation` 和工作区。第一次确认负责记录同线程归属；后续同工作区检查才可能继续回收 launcher 退出后的残留。

## 故障排查

- 如果这个包只以 skill 式安装存在，请显式要求 Codex 使用 `$codex-cleaning-temporary-processes`。
- 如果自动 hook 不可用，请检查插件式安装文件是否齐全：`.codex-plugin/plugin.json`、`hooks.json` 和 `hooks/`。
- 如果进程栈仍在增长，请检查某个已结束的高风险步骤或子代理结果之后，是否漏掉了固定检查点。
- 如果下一步可能复用某个进程，先让 Codex 跑 `inspect`，而不是强制清理。
- 如果某个进程被保留，这通常意味着工作区证据、自动化标记或其他强归属信号还不够。
- 如果 `-Workspace` 为空、缺失或指向别的仓库，同线程确认就不会记账，也不会提升这些对象。
- 如果某个进程只是在 `Codex.exe app-server` 下面，也仍然不足以清理它。
- 如果多个项目同时活跃，无法证明归属的 DevTools 或浏览器调试残留会继续保持 `inspect-only`。

## 测试

运行重点测试：

```powershell
Invoke-Pester -Path .\scripts\process-inventory.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\process-classification.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-policy.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\cleanup-temporary-processes.Tests.ps1 -PassThru
Invoke-Pester -Path .\scripts\skill-trigger-contract.Tests.ps1 -PassThru
```

或者直接跑完整矩阵：

```powershell
Invoke-Pester -Path .\scripts -PassThru
```

## 许可证

本项目使用 [MIT License](./LICENSE)。
