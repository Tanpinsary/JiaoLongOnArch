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

## 待完成

- 冷启动一次，并在重启前把 profile 设为 `balanced-performance`；
- 另两个 profile（quiet/balanced）的同样循环。
