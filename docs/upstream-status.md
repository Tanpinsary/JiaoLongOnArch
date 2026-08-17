# Linux 上游与 Arch 状态

## 结论

蛟龙 16 Pro 所使用的 MIFS WMI 协议已经有正式 Linux 上游驱动，不应再创建绑定相同 GUID 的平行内核模块。

- 上游文件：[`drivers/platform/x86/bitland-mifs-wmi.c`](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/bitland-mifs-wmi.c)
- 初始提交：[`dc1ec4fa86b2`](https://github.com/torvalds/linux/commit/dc1ec4fa86b2b8bba2b6122f2b4420217b5bae9e)
- 挂起/恢复修复：[`d3666875c75e`](https://github.com/torvalds/linux/commit/d3666875c75eb1bc8090343fa0d6fc8fb7924356)
- 合入版本：Linux 7.1
- 当前 Arch `linux` 包：7.1 系列
- [Arch 配置](https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/blob/main/config.x86_64)：`CONFIG_BITLAND_MIFS_WMI=m`

## 已提供的 Linux 接口

| 功能 | Linux 接口 |
|---|---|
| CPU 温度、CPU/GPU/SYS 风扇转速 | `hwmon` |
| 安静/平衡/性能/全速模式 | `platform_profile` |
| 键盘亮度 | LED class |
| 键盘模式 | WMI 设备的 `kb_mode` sysfs 属性 |
| Hybrid/Discrete/UMA | WMI 设备的 `gpu_mode` sysfs 属性 |
| 风扇全速开关 | WMI 设备的 `fan_boost` sysfs 属性 |
| 固件快捷键 | input/WMI events |

性能与全速模式写入前，驱动会检查系统正在使用圆口 DC 供电，而不是 USB-C。

## 当前缺口

1. 上游事件 GUID `46C93E13-...` 与 `redmi-wmi` 重复声明。本机实测该事件设备被 `redmi-wmi` 绑定，导致 `bitland-mifs-wmi` 无法创建热键 input 设备，也无法收到键盘灯、profile 和风扇事件通知；两个驱动的事件 ID/keymap 语义不同，需要通过 DMI 白名单或共享事件层修复。详见 `docs/linux-stage1-results.md`。
2. 上游直接把功能 13 的前两个风扇字段标记为 CPU、GPU。本机 CPU-only 与 80 W GPU-only 测试均显示两通道同步（相关系数 0.976/0.997），无法按 CPU/GPU 区分；应改为不带 CPU/GPU 语义的通道名或机型 quirk。详见 `docs/linux-stage2-progress.md`。
3. 上游只暴露键盘亮度和模式，没有暴露固定 RGB 颜色。
4. 主线目前只有 `fan_boost`，没有任意风扇曲线；更重要的是，主线对功能 20 写 `{0, state}`，蛟龙官方 0.3.15 写入单字节 `{state}`，所以该机型在真机验证前禁止使用 `fan_boost`。
5. 官方 0.3.15 用功能 21 的单字节目标实现手动风扇，并按模式限制在 22–58；2026-05 的 thermal cooling device 补丁不在当前主线中，不能视为已支持功能。
6. 上游未暴露官方程序支持的环境/Logo 灯（功能 15）和固定 RGB 颜色（功能 17）。
7. 官方程序的 MUX 只使用 0/1 并在写后立即重启；上游额外提供 UMA 2，蛟龙首轮测试不应选择 UMA。

## Arch 初次测试

```bash
zgrep CONFIG_BITLAND_MIFS_WMI /proc/config.gz
modinfo bitland-mifs-wmi
sudo modprobe bitland-mifs-wmi
./tools/jiaolongctl
./tools/collect-linux.sh
```

初次测试只读取状态。确认 DMI、WMI GUID、字段顺序和 BIOS 恢复入口以前，不写 `gpu_mode`、`fan_boost` 或性能模式。
