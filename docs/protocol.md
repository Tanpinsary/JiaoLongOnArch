# MIFS 协议记录

本文只记录可由公开源码、Linux 上游代码和真机采集复核的事实。未经真机确认的字段不得用于固件写入。

## 来源

- 机械革命官方“蛟龙游戏控制中心”0.3.15：由 Shenzhen Bitland Information Technology Co., Ltd. 签名；本项目只记录互操作所需的静态分析结果，不分发样本或反编译文件。
- [GaoXanSheng/JiaoLongControl](https://github.com/GaoXanSheng/JiaoLongControl)：MIT 许可的 Windows 实现，开发机为蛟龙 16 Pro 7945HX + RTX 4060。
- Linux 上游 [`bitland-mifs-wmi.c`](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/bitland-mifs-wmi.c)：GPL-2.0-or-later。
- 上游初始提交 [`dc1ec4fa86b2`](https://github.com/torvalds/linux/commit/dc1ec4fa86b2b8bba2b6122f2b4420217b5bae9e)。
- 上游挂起修复 [`d3666875c75e`](https://github.com/torvalds/linux/commit/d3666875c75eb1bc8090343fa0d6fc8fb7924356)。

本项目不分发 Windows 控制中心、其 DLL/SYS 文件或其他专有二进制。

## WMI 设备

| 用途 | GUID |
|---|---|
| 控制方法 | `B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B` |
| 固件事件 | `46C93E13-EE9B-4262-8488-563BCA757FEF` |

Windows WMI 类名为 `MICommonInterface`，实例通常为 `ACPI\\PNP0C14\\MIFS_0`。方法名为 `MiInterface`，WMI 方法 ID 为 `1`。

## 数据包

输入固定为 32 字节：

```text
offset  size  含义
0       1     保留，发送 0
1       1     操作：0xFA GET，0xFB SET
2       1     保留，发送 0
3       1     功能号
4       28    SET 参数
```

```c
struct mifs_input {
    uint8_t reserved0;
    uint8_t operation;
    uint8_t reserved2;
    uint8_t function;
    uint8_t payload[28];
} __attribute__((packed));
```

BMof 方法签名的输出是 `uint8 OutData[30]` 加单独的 `uint16 Reserved`。MRID6-23 真机在 Windows 中确认 `OutData` 长度为 30，返回头位于偏移 0–3，值从偏移 4 开始。Linux WMI buffer API会展平全部输出参数；上游驱动用 32 字节结构读取前部字段，因此不能把 Windows `OutData` 的 30 字节长度误判为固件返回过短。

Linux 7.1 使用新的 WMI buffer marshalling API。旧版 Linux 7.0 和 6.18 LTS 只有 `wmidev_evaluate_method()`，但本项目不再发布与内核驱动争抢同一 GUID 的回移模块；推荐直接使用 Arch 当前 7.1 系列内核。

## 功能号

| 十进制 | 名称 | 已知值/格式 | 首版策略 |
|---:|---|---|---|
| 8 | 性能模式 | 官方蛟龙：0 平衡、1 性能、2 安静；上游另定义 3 全速 | 首轮只用 0–2 |
| 9 | GPU/MUX 模式 | 官方蛟龙：0 Hybrid、1 Discrete；上游另定义 2 UMA | 先读；0/1 写入需确认并重启 |
| 10 | RGB 键盘状态/类型 | 固件变体语义有差异 | 只读探测 |
| 11 | Fn Lock | 0/1 | 暂不实现 |
| 12 | 触控板锁 | 0/1 | 暂不实现 |
| 13 | 风扇转速 | 多个 RPM 字段 | 只读 hwmon，字段标签待验证 |
| 15 | 环境/Logo 灯 | 0/1 | 当前上游未暴露 |
| 16 | RGB 模式 | 0 关、1 循环、2 固定、3 自定义 | 先读 |
| 17 | RGB 颜色 | payload 0/1/2 为 R/G/B | 当前上游未暴露 |
| 18 | RGB 亮度 | 固件枚举允许 0–10/128；蛟龙 UI 只写 0–3 | 上游 LED class 使用 0–3 |
| 19 | 适配器类型 | 1 USB-C、2 圆口 DC | 只读 |
| 20 | 手动风扇开关 | 官方蛟龙把 0/1 写入 payload 0；当前上游写入 `{fan_type, state}` | **协议冲突，禁止测试上游 fan_boost** |
| 21 | 手动风扇目标 | 官方蛟龙把目标字节写入 payload 0 | 真机验证前不写 |
| 22 | CPU 温度 | payload 0，单位 °C | 只读 hwmon |
| 23 | CPU 功耗控制 | 0 关、1 开、2 SPL、3 SPPT、4 温度墙 | 不属于 hwmon；首版不实现 |

## 官方 0.3.15 的关键静态结果

官方应用构造固定 32 字节请求：`byte[1]` 为 GET/SET，`byte[3]` 为功能号，SET 参数从 `byte[4]` 连续写入；它直接调用 `root\\WMI` 下 `MICommonInterface.InstanceName='ACPI\\PNP0C14\\MIFS_0'` 的 `MiInterface` 方法。

官方应用的普通手动风扇路径没有使用额外内核驱动：

- 开关：功能 20，payload 0 写 `0` 或 `1`；
- 目标：功能 21，payload 0 写目标字节；
- 安静模式允许 22–35，默认 27；
- 性能模式允许 35–50，默认 43；
- 最快/自定义页面允许 50–58，默认 53；
- 切换 MUX 后调用 `shutdown.exe -r -t 2`，说明必须重启生效。

这些范围来自 UI 安全限制，不等于已经确认的物理 RPM。当前 Linux 上游 `fan_boost` 对功能 20 发送两个字节 `{0, state}`，与这份蛟龙官方程序不一致；在真机验证前不得使用该 sysfs 写接口。

## 风扇字段待确认

Linux 上游把功能 13 的返回数据解释为：

- `payload[0..1]`：CPU RPM
- `payload[2..3]`：GPU RPM
- `payload[6..7]`：SYS RPM

Windows 真机样本返回 `C5 13 B9 13 00 00 00 00`，little-endian 解释为 5061、5049、0 RPM；这确认了方法返回字段的字节序，但没有确认通道标签。

官方 0.3.15 只把第一个字段显示为笼统的“FanSpeed”，没有给两个字段贴 CPU/GPU 标签；公开的 `JiaoLongControl` 则把前两个字段显示为 GPU、CPU，顺序与上游相反。首轮真机测试必须分别制造 CPU-only 和 GPU-only 负载，对比字段变化后再确定标签。确认前只能称为 fan channel 0/1，不能据此控制风扇。

官方 WMI 事件代码还把事件字节 2/3 按大端 RPM 组合，而当前上游驱动按相反顺序组合。该差异同样需要通过真机事件数据验证。

## Windows 实现中的直接 EC 路径

`JiaoLongControl` 的自定义曲线没有使用上述 WMI 手动风扇命令，而是通过内核驱动访问 I/O 端口 `0x4E/0x4F`，间接读写 EC RAM：

| 地址 | 公开实现中的含义 |
|---:|---|
| `0xC834` | Fan 1 RPM |
| `0xC835` | Fan 2 RPM |
| `0xC83C` | Fan 1 目标值 |
| `0xC83D` | Fan 2 目标值 |
| `0x0B20` | 手动控制位（公开实现使用位 `0x02`、`0x08`） |
| `0xC411` | EC 版本 |

公开实现将目标字节解释为 `1 unit = 100 RPM`，上限 68（6800 RPM）。这些地址和比例只在其 7945HX 开发机上得到间接验证，不能直接视为 7745HX 的稳定 ABI。本项目首版禁止这条写入路径。

## 上游与 Arch 状态

截至 2026-08：

- 驱动已经进入 Linus 的内核树，名称为 `bitland-mifs-wmi`；
- 驱动随 Linux 7.1 合入；
- Arch 当前 `linux` 包已进入 7.1 系列；
- Arch 官方 `config.x86_64` 设置了 `CONFIG_BITLAND_MIFS_WMI=m`，可直接加载模块；
- 本项目不会再发布与该模块绑定相同 GUID 的平行 DKMS 驱动。

## 真机解锁写入的门槛

1. DMI 产品名、主板名和 BIOS 版本已记录且不含序列号；
2. Windows 中存在 `MICommonInterface`；
3. Linux 中存在两个预期 WMI GUID；
4. 所有 GET 命令连续读取稳定，无 ACPI 错误；
5. 风扇字段顺序通过 CPU/GPU 分离负载确认；
6. BIOS 中存在可恢复的 GPU 模式入口，或保留 Windows 恢复环境；
7. 每项写入一次只改变目标状态，并能读回；
8. 挂起/恢复、重启和断电重启均完成测试。
