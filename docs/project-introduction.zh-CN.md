# 项目介绍

Codex Cleaning Temporary Processes 是一个跨平台 Codex skill，用来在开发任务中安全地管理临时进程卫生。

它适用于这类场景：shell、测试命令、构建工具、浏览器调试辅助进程、DevTools MCP 服务以及工作区运行时，会在任务过程中留下额外的临时进程。这个 skill 不要求等到整个长任务结束后再统一处理，而是支持在高风险步骤结束后做 checkpoint cleanup，从而控制进程堆积，同时避免把“看起来像开发进程”的对象全部粗暴结束掉。

这个项目面向 Windows、macOS 和 Linux 上的主流开发工作流。它的规则建立在命令行证据、进程树关系和工作区匹配之上，因此可以覆盖前端、后端、自动化、移动端以及系统工具链，而不是绑定某一个项目结构。

整个运行模型保持保守：

- 当证据不足时先检查
- checkpoint 阶段只清理高置信度残留
- 保留当前 Codex shell、普通用户应用和可能仍需复用的开发服务
- 只有在剩余临时进程树确定不再需要时，才做最终清扫

这个仓库包含 skill 定义、agent 元数据、PowerShell 脚本、shell wrapper 以及 Pester 测试，方便在其他 Codex 环境中直接使用或继续扩展。
