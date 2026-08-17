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

## AC 插拔

正在进行，监控文件：

```text
/home/tanp/Projects/JiaoLongOnArch-stage5-ac-*.csv
```

待完成：圆口 AC 拔出 ≥30 秒后重新插入，对比 `ADP1 online`、BAT0
状态、hwmon 和 journal。

## 待完成

- AC 插拔一次；
- 热重启一次；
- 冷启动一次；
- 另两个 profile（quiet/balanced）的同样循环。
