# 项目介绍

Codex Cleaning Temporary Processes 是一个公开、跨平台的 skill，用来安全清理临时开发进程。

这个包刻意保持为纯 skill，而不是插件。它的目标是给 Codex 提供一套可复用、最佳努力的进程卫生工作流，让 Codex 在编码过程中出现临时进程残留时，更容易在合适检查点重新想到清理这件事。

这个 skill 的核心是“已结束检查点”，而不是“等整个任务结束再想起清理”。当高风险步骤、自动化步骤、子代理步骤，或者一批一次性命令已经结束时，Codex 就应该重新判断现在是否适合安全清理。

它的适用范围也不局限于单一语言。这个 skill 可以理解 npm、vite、vitest、cargo、tauri、trunk、hatch、pytest、jupyter、streamlit、dotnet、Kotlin、Scala、Go、Ruby、PHP、Elixir，以及 `clj`、`cabal`、`dune`、`Rscript`、`perl`、`lua`、`zig`、`julia`、`tox`、`xcodebuild`、`bazel` 等更广泛主流生态留下的临时进程，同时继续保持保守的清理策略。

这里强调的是“覆盖更广的主流生态”，不是“覆盖所有编程语言、所有工具链、所有命令”。

安全仍然是设计核心：

- 证据不足时先 inspect
- 只清理高置信度残留
- 显式自动化必须受当前任务链路或当前线程确认归属限制
- 不能仅凭工作区匹配就清理显式自动化
- 保留活动 shell、普通用户应用、有歧义的 runtime，以及可能仍会复用的开发服务

多项目隔离也写得很明确。A 项目的进程不能因为 B 项目恰好在另一个 Codex 对话里运行，就被误回收。工作区证据、祖先进程归属和显式自动化规则都必须保持严格。
