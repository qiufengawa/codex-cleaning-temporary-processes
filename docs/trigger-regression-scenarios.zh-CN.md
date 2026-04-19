# 触发回归场景

下面这些场景构成纯 skill 包的公开触发契约。

因为这个仓库是 skill，而不是插件，所以下面的检查点描述的是最佳努力的隐式调用目标，不是宿主保证的自动回调。

## 正向契约

### `must reconsider now`

适用于：

- 一次性高风险命令结束，例如 `npm test`、`vite build`、`vitest`、`cargo test`、`tauri build`、`pytest`、`dotnet build`
- `failed one-shot high-risk` 场景，也就是同类一次性高风险命令失败之后
- DevTools、浏览器自动化或远程调试检查点结束之后
- 子代理检查点完成之后
- 同一工作区一批一次性高风险命令结束之后
- 用户明确要求最终清扫

预期决策：如果残留已经明确是临时且已结束的，优先 `checkpoint-cleanup`；否则回退到 `inspect`。

### `should reconsider soon`

适用于：

- 为了缓解积压而进行的 backlog relief 检查点
- 已结束但仍然可能复用部分进程的检查点

预期决策：如果复用仍然合理，或者归属还不够清晰，就优先 `inspect`。

## 反向契约

### `do not reconsider from this checkpoint alone`

适用于：

- 低风险检查命令，例如列目录、搜索、grep、读取文件
- 长驻 `dev` / `watch` / `serve` / preview / storybook 类检查点
- `session-end alone`
- 缺少可靠工作区或任务归属的模糊检查点

预期决策：不能仅凭这一类检查点就触发更强的 cleanup 重新评估。

## 安全提醒

- 最佳努力的隐式调用必须继续保持保守。
- 更强触发表示更强的重新评估义务，不表示更强的 kill 权限。
- 当前线程拥有权只会收窄显式自动化的回收范围，不会放宽普通 runtime 的清理范围。
- 没有强任务证据时，不要清理普通交互 shell、普通用户浏览器、可复用开发服务或有歧义的 runtime。
- 仅有工作区匹配仍然不足以清理显式自动化。

## 动作协议

- 遇到触发型已完成检查点时，先 `inspect`
- 如果 `inspect` 输出里出现 `killable roots`，下一步再执行 `checkpoint-cleanup`
- 只有在刚结束的检查点确实使用了同线程显式自动化、并且工作区非空时，第一次跟进 `inspect` 才加 `-ConfirmCurrentThreadExplicitAutomation`
- 需要验证是否已经成功记账时，读取返回结果里的 ledger path 相关字段
