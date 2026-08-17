# 分阶段真机测试计划

所有阶段都要求连接原装圆口电源、保持散热口通畅，并保留可进入 BIOS/Windows 的恢复路径。

## 阶段 0：Windows 元数据与 GET（完成）

- 已确认 DMI：`Jiaolong Series MRID6` / `MRID6-23` / BIOS `MRID6_23_P_V35`。
- 已确认活动实例 `ACPI\\PNP0C14\\MIFS_0` 与 HID 事件类存在。
- 精确白名单下 14 个官方 GET 全部成功，功能 20 被刻意跳过。
- 首份报告为独显直连、平衡 profile、圆口 DC，两个风扇字段约 5,050 RPM。
- 已通过官方控制中心完成 Discrete 1 → Hybrid 0，重启后的 GET 确认生效；探测脚本本身未执行任何 SET。

## 阶段 1：Arch 真机只读绑定（进行中）

真机结果与完整分析见 `docs/linux-stage1-results.md`。当前状态：

- 内核 7.1.6-arch1-1，`CONFIG_BITLAND_MIFS_WMI=m`；
- 控制 GUID `...-4` 正确绑定 `bitland-mifs-wmi`；
- 事件 GUID `...-0` 被 `redmi-wmi` 抢先绑定，阶段 1 未通过；
- hwmon、platform profile、键盘 LED、`gpu_mode=hybrid`、`kb_mode=fixed` 均只读正常；
- `jiaolongctl status` 当前返回 5，并拒绝任何固件写入。

解决事件 GUID 冲突前，继续执行：

```bash
./tools/jiaolongctl status
./tools/collect-linux.sh
```

冲突修复后，阶段 1 通过条件：

- 两个预期 WMI GUID 均存在；
- 控制与事件设备均绑定 `bitland-mifs-wmi`，且存在 `Bitland MIFS WMI hotkeys` input 设备；
- `hwmon`、`platform-profile`、键盘 LED、`gpu_mode` 和 `kb_mode` 读取无 ACPI 错误；
- DMI 精确白名单命中；
- 不读取或写入 `fan_boost`。

## 阶段 2：风扇字段只读识别

先记录空闲状态，再分别制造 CPU-only 与 GPU-only 负载，每 1–2 秒记录三个 fan input、CPU 温度和 `nvidia-smi` 温度。全过程由 EC 自动控扇，不写任何风扇接口。

目标：确定功能 13 的前两个 RPM 字段究竟对应 CPU、GPU，还是主循环/辅助循环；同时核对 WMI 事件 RPM 字节序。确认前不向上游提交标签修复。

## 阶段 3：低风险、可逆写入

按顺序逐项测试，每次写前后读取状态并等待至少一分钟：

1. 键盘亮度 0–3；
2. 键盘模式 `off` / `cyclic` / `fixed`；
3. profile：`quiet`、`balanced`、`performance`。

`jiaolongctl` 把 `performance` 映射到 Linux 的 `balanced-performance`（固件值 1），不会选择 Linux `performance` 对应的未验证固件值 3。

## 阶段 4：MUX

仅当 BIOS 中存在可恢复的显卡模式入口、Windows 仍可启动且 NVIDIA 驱动已验证时测试：

```bash
sudo ./tools/jiaolongctl gpu-mode discrete --confirm-reboot-required
```

工具只写选择，不会自动重启。手动重启后验证内屏、Wayland、外接显示器和 `nvidia-smi`，再测试切回 Hybrid。

## 阶段 5：挂起、恢复与长期使用

对每个已验证 profile 完成多次挂起/恢复、冷启动、热重启和 AC 插拔。观察内核日志中的 WMI/ACPI 错误。

## 明确禁止

- 当前上游 `fan_boost`：官方蛟龙和上游的 payload 布局不同；
- `gpu_mode=uma`：官方蛟龙程序没有使用；
- Linux `performance`/固件 profile 3：官方蛟龙程序没有使用；
- 任意 EC RAM 写入；
- 手动风扇命令 21；
- Ryzen SMU、GPU 超频、降压或功耗墙。
