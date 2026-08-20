# Changelog

## 0.1.0 - 2026-08-20

首个公开里程碑版本。

### 功能

- 精确匹配 MRID6-23 / BIOS V35 的保守 `jiaolongctl`；
- Textual TUI：温度、风扇、profile、MUX、键盘与驱动状态；
- quiet、balanced、performance，键盘亮度/模式和 Hybrid/Discrete 控制；
- 受限 polkit helper、Arch/Linux 安装与卸载脚本；
- Windows/Linux 只读采集与分阶段真机检查工具。

### 真机验证

- Arch Linux 7.1 / 上游 `bitland-mifs-wmi`；
- Discrete、NVIDIA KDE Wayland 和 2560×1600@165 Hz；
- 三个允许 profile 的挂起/恢复与热重启；
- 跨 profile 的 AC 插拔与冷启动。

### 明确不支持

- `fan_boost`、手动风扇和任意 EC RAM 写入；
- UMA 和未经官方程序验证的全速 profile；
- Ryzen SMU、GPU 超频、降压和功耗墙。

### 已知问题

- 事件 GUID 与 `redmi-wmi` 存在绑定冲突，本机需要已记录的 workaround；
- 上游 CPU/GPU 风扇通道标签在 MRID6 上无法由负载测试确认；
- 部分 NVIDIA/KDE 挂起恢复周期会短暂记录输出配置告警，但显示自动恢复。
