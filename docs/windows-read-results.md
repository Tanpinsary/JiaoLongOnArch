# Windows MIFS 只读结果

采集时间：2026-08-10。脚本通过精确 MRID6-23/V35 白名单，只发送 `0xFA` GET，并跳过功能 20。

## 接口确认

- 实例：`ACPI\\PNP0C14\\MIFS_0`
- Active：`true`
- 所有 14 个 GET 均成功；无异常。
- Windows `OutData` 长度为 30 字节，与 BMof 的 `uint8 OutData[30]` 一致；另有单独的 `uint16 Reserved`。Linux WMI marshalling 会把输出参数展平，上游驱动只使用前面的字段。
- 返回头通常为 `00-80-00-<function>`，实际值从偏移 4 开始。

## 首次状态（独显直连）

| 功能 | 原始 payload | 解释 |
|---:|---|---|
| 8 SystemPerMode | `00` | 平衡模式 |
| 9 GPUMode | `01` | 当前为独显直连 |
| 10 RGBKeyboardStatus | `00` | 语义仍不明确；不能据此断言是白光键盘 |
| 11 FnLock | `00` | 关闭 |
| 12 TPLock | `00` | 未锁定 |
| 13 CPUGPUFanSpeed | `C5 13 B9 13 00 00 00 00` | 前两个 little-endian 字段为 5061、5049 RPM；第三字段为 0 |
| 15 Ambientlight | `00` | 关闭 |
| 16 RGBKeyboardMode | `02` | 固定颜色 |
| 17 RGBKeyboardColor | `00 FF C7` | RGB `(0, 255, 199)` |
| 18 RGBKeyboardBrightness | `01` | 亮度 1 |
| 19 SystemAcType | `02` | 圆口 DC 电源 |
| 21 MaxFanSpeed | `32` | 手动风扇目标字节 50 |
| 22 CPUThermometer | `4E` | CPU 78°C |
| 23 CPUPower | `00` | 自定义 CPU 功耗模式关闭 |

功能 13 的值证明方法返回的 RPM 字段是 little-endian：`C5 13` 解释为 5061 RPM 合理，而大端解释为 50451 不可能。两个字段在这次样本中接近，仍不能确定哪个对应 CPU/GPU。

## 官方 MUX 切换复查

用户随后通过官方控制中心关闭独显直连并重启。第二份只读报告中功能 9 返回：

```text
00-80-00-09-00-00-...
            ^ offset 4 = 0
```

这确认当前已经是 Hybrid 0，也验证了官方程序的 Discrete 1 → Hybrid 0 写入和重启流程。第二份样本的两个风扇字段为 3067、3115 RPM，CPU 温度为 83°C；风扇目标字节仍是 50，说明功能 21 的目标值本身不能代表手动开关当前是否启用。

## 安装 Arch 前的直接影响

机器现在已处于适合首次 Arch 安装、AMD 核显桌面、PRIME 和 Waydroid 验证的 Hybrid 0。首次 Linux MUX 测试前仍应保留 Windows，并且不要使用尚未完成真机验证的 sysfs 切换。

## 仍然禁止的接口

- 功能 20：本次刻意未读写；官方程序和上游 `fan_boost` 的 SET payload 不一致。
- 功能 21 写入：虽然 GET 已确认目标为 50，但尚未在 Linux 实现或测试故障恢复。
- profile 3、GPU UMA 2、EC RAM、SMU、超频和降压。
