# JiaoLongOnArch v0.1.0

首个稳定里程碑：为机械革命蛟龙 16 Pro MRID6-23/V35 提供基于 Linux
上游 `bitland-mifs-wmi` 的保守 CLI 与 TUI。

## 安装（Arch Linux）

下载 release 中的包后：

```bash
sudo pacman -U jiaolongonarch-0.1.0-1-any.pkg.tar.zst
jiaolong-tui
```

也可以从源码使用 uv：

```bash
uv sync --locked
uv run ./tools/jiaolong-tui
```

首次写操作由 polkit 请求管理员授权。MUX 选择需要明确确认和手动重启。

## 安全范围

本版本只允许已由官方控制中心和真机测试覆盖的 profile、键盘与
Hybrid/Discrete 操作。`fan_boost`、手动风扇、UMA、全速 profile 和任意
EC 写入继续禁用。

完整变更见 `CHANGELOG.md`，真机证据见 `docs/linux-stage5-progress.md`。
