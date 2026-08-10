# 已采集的目标硬件

报告时间：2026-08-10。报告未采集序列号、UUID、MAC 或 PNP 实例 ID。

## DMI/BIOS

| 字段 | 值 |
|---|---|
| System manufacturer | `MECHREVO` |
| System/product name | `Jiaolong Series MRID6` |
| Product version | `1` |
| Baseboard manufacturer | `MECHREVO` |
| Baseboard product | `MRID6-23` |
| Baseboard version | `Base Board Version` |
| BIOS vendor | `INSYDE Corp.` |
| BIOS version | `MRID6_23_P_V35` |
| BIOS release date | 2024-01-10 |

CPU 为 Ryzen 7 7745HX（8C/16T），显卡为 AMD Radeon iGPU 与 RTX 4060 Laptop。

官方控制中心 PDB 中的构建路径包含 `MRID6_23_JiaoLong/.../MRID623CC`，与本机 `MRID6-23` 主板和 `MRID6_23_P_V35` BIOS 精确对应。因此官方 0.3.15 的协议分析可作为该机型的强证据，而不是仅依据相近同方模具推测。

## Windows WMI

下列类已确认存在于 `root/WMI`：

- `MICommonInterface`
- `HID_EVENT20`
- `HID_EVENT21`
- `HID_EVENT22`
- `HID_EVENT23`

修正后的精确白名单探测确认活动实例为 `MICommonInterface.InstanceName='ACPI\\PNP0C14\\MIFS_0'`，14 个官方 GET 均成功；功能 20 被刻意跳过，且未执行 SET。

## 写入白名单建议

用户态控制工具至少同时匹配：

```text
sys_vendor      = MECHREVO
product_name    = Jiaolong Series MRID6
product_version = 1
board_vendor    = MECHREVO
board_name      = MRID6-23
bios_vendor     = INSYDE Corp.
bios_version    = MRID6_23_P_V35
```

首轮 Linux 测试仍保持只读。若未来支持其他 BIOS 版本，应在读接口和每项写接口重新验证后逐个添加，不能使用前缀或宽泛的 `MRID6` 匹配。
