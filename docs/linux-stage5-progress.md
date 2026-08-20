# Linux 阶段 5 进度

测试环境：Discrete、KDE Wayland、内核 7.1.8-arch1-3、AC 圆口在线。

## balanced-performance：挂起/恢复 3 次

| 轮次 | 时间 | jiaolongctl | 显示 | WMI/ACPI | KWin |
|---|---|---|---|---|---|
| 1 | 00:38 | 0 | 正常 | 无新增 | `Applying output configuration failed!` 1 次，随后恢复 |
| 2 | 00:43 | 0 | 正常 | 无新增 | 同样 1 次，随后恢复 |
| 3 | 00:47 | 0 | 正常 | 无新增 | 同样 1 次，随后恢复 |

观察：

- 每次恢复后 `gpu_mode=discrete`、`profile=balanced-performance` 均保持；
- 事件 GUID 仍绑定 `bitland-mifs-wmi`；
- `nvidia-smi -L` 可见 RTX 4060，`kscreen-doctor` 输出 eDP-2 正常；
- 每次 resume 时 KWin 报一次 `Applying output configuration failed!`，
  但随后显示恢复，属于可重复的恢复期告警，已记录；
- 无 ACPI/WMI 新错误。

## AC 插拔（完成，2026-08-19 14:06–14:07）

监控文件：`/home/tanp/Projects/JiaoLongOnArch-stage5-ac-20260819-140609.csv`。

观察：

- 14:06:53 `ADP1 online` 1 → 0，`BAT0 status` 变为 `Discharging`；
- 14:07:26 `ADP1 online` 0 → 1，随后 BAT0 回到 `Not charging`；
- 拔电/插电前后 `fan1/fan2` 约 1,800–1,830 RPM，变化平稳；
- journal 无新增 ACPI/WMI/bitland 错误；
- 当前 `ADP1 online=1`，`BAT0 status=Not charging`。

AC 圆口插拔测试通过。

## 热重启（完成，2026-08-19 14:13）

- `jiaolongctl status=0`；
- 事件 GUID 重启后自动绑定 `bitland-mifs-wmi`，黑名单 workaround 生效；
- `gpu_mode=discrete` 保持；
- KWin Wayland 正常，无输出配置错误；
- 无新增 ACPI/WMI 错误。

发现：profile 由重启前的 `balanced-performance` 变为 `low-power`。
journal 中没有 KDE/power-profiles-daemon 写 profile 的记录，因此更像
固件重启后默认回到 quiet；该非持久化行为待冷启动复核。

## 冷启动（完成，2026-08-19 14:20）

冷启动前已显式设置 `profile=balanced-performance`。结果：

- 冷启动后 profile 仍为 `balanced-performance`；
- `jiaolongctl status=0`；
- 事件 GUID 自动绑定 `bitland-mifs-wmi`；
- `gpu_mode=discrete` 保持；
- KWin Wayland 正常；
- 无新增 ACPI/WMI 错误。

## 受控热重启复核（通过，2026-08-19 16:05–16:09）

重启前运行 `stage5-check.sh balanced-performance-before-reboot`，确认
`profile=balanced-performance`、`gpu_mode=discrete`、两个 WMI GUID 均绑定
`bitland-mifs-wmi`。热重启后再次检查：

- profile 保持 `balanced-performance`；
- `jiaolongctl status=0`，事件 GUID 自动正确绑定；
- `gpu_mode=discrete`，AC 圆口在线；
- 无新增 ACPI/WMI 或 KWin 错误。

因此上一次热重启后的 `low-power` 未能复现，更可能是重启前 profile 已被
其他操作改变，暂不视为固件重启复位问题。

检查脚本同时移除了开发者主目录硬编码：报告现在默认写入仓库内已忽略的
`artifacts/`，也可用 `STAGE5_OUTPUT_DIR` 指定其他目录。

## low-power / quiet：完整循环通过（2026-08-19–20）

- 三轮挂起/恢复均保持 `profile=low-power`、`gpu_mode=discrete` 和正确的
  WMI 绑定；每轮恢复时 KWin 各报一次已知的
  `Applying output configuration failed!`，随后显示正常；
- AC 圆口插拔时 `ADP1 online` 完成 1 → 0 → 1，电池随后进入 Charging，
  fan1/fan2 稳定在约 1,970–1,980 RPM，无新增 WMI/ACPI 错误；
- 热重启后 profile 保持 `low-power`，NVIDIA 与 eDP-2 165 Hz 正常；
- 冷启动后 profile 仍保持 `low-power`，`jiaolongctl status=0`，NVIDIA、
  KDE Wayland 和 eDP-2 165 Hz 正常，无新增 WMI/ACPI 或 KWin 错误；
- 冷启动检查时 CPU 约 51°C，fan1/fan2 均为 0，符合 quiet 模式低温停转
  状态，hwmon 设备和其余字段读取正常。

## 待完成

- balanced profile 的同样循环。
