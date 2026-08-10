# JiaoLongOnArch

机械革命蛟龙 16 Pro（2023，Ryzen 7 7745HX / RTX 4060）在 Linux 上的固件控制兼容项目。

## 当前状态

项目处于硬件确认阶段。首个里程碑只覆盖固件公开的 MIFS WMI 接口，不直接写 EC RAM，也不实现 Ryzen SMU、GPU 超频或降压。

Linux 上游已经在 2026 年合入 [`bitland-mifs-wmi`](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/bitland-mifs-wmi.c)，目标接口与蛟龙控制中心使用的接口一致。当前 Arch `linux` 已进入 7.1 系列，并明确配置 `CONFIG_BITLAND_MIFS_WMI=m`，因此不再编写会争抢同一 WMI GUID 的重复 DKMS 驱动。本项目优先完成：

1. 确认 7745HX 机型的 DMI 和两个 WMI GUID；
2. 对比 Windows 官方控制中心和上游协议；
3. 提供不会调用写方法的 Windows/Linux 采集工具；
4. 为内核自带驱动提供安全、可确认的用户态控制工具；
5. 将真机发现的字段错误或缺失功能直接修复到 Linux 上游。

Windows 报告已确认本机为 `Jiaolong Series MRID6` / `MRID6-23` / BIOS `MRID6_23_P_V35`，且 `MICommonInterface` 与 HID 事件类存在。下一阶段需要从 Arch 7.1 真机读取两个 WMI GUID 和上游驱动节点。

## 已知固件接口

- 控制 GUID：`B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B`
- 事件 GUID：`46C93E13-EE9B-4262-8488-563BCA757FEF`
- WMI 方法 ID：`1`
- 32 字节请求：字节 1 为操作码，字节 3 为功能号，字节 4 起为参数

协议细节见 [`docs/protocol.md`](docs/protocol.md)，目标 DMI 见 [`docs/hardware.md`](docs/hardware.md)，内核与 Arch 集成状态见 [`docs/upstream-status.md`](docs/upstream-status.md)，官方 Windows 样本记录见 [`docs/windows-package.md`](docs/windows-package.md)，真机步骤见 [`docs/test-plan.md`](docs/test-plan.md)。

## Arch 内核驱动

安装最新 Arch 后先检查，不需要安装第三方模块：

```bash
zgrep CONFIG_BITLAND_MIFS_WMI /proc/config.gz
modinfo bitland-mifs-wmi
sudo modprobe bitland-mifs-wmi
```

只有在 `/sys/bus/wmi/devices/` 中存在上述控制 GUID 时，驱动才会绑定。第一次只读取温度、风扇、性能模式和 GPU 模式；不要立即写 `fan_boost` 或 `gpu_mode`。

## 安全原则

- 未确认 DMI/WMI 前不执行任何固件写操作。
- 首轮采集工具只读取系统元数据，不调用 `MiInterface`。
- 不提供任意 WMI/EC 写入通道。
- MUX 写入必须单独确认，切换后通常需要重启。
- 自定义风扇曲线不属于首版范围；若以后实现，必须具备自动恢复 EC 控制和超温故障保护。

## Windows 只读采集

以普通用户打开 PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\tools\collect-windows.ps1
```

脚本会在桌面生成 `JiaoLongOnArch-Probe-*.zip`。它不会读取机器序列号，不会调用固件控制方法，也不会修改控制中心设置。

精确 DMI 已确认后，可以另行运行：

```powershell
.\tools\probe-windows-mifs-readonly.ps1
```

该脚本严格匹配 MRID6-23/V35，只构造操作码 `0xFA` 的 GET 请求，并特意跳过与上游存在参数冲突的功能 20；输出为桌面的 `JiaoLongOnArch-MIFS-ReadOnly-*.json`。

## Linux 检查与保守控制

安装 Arch 后，第一轮只运行：

```bash
./tools/collect-linux.sh
./tools/jiaolongctl status
```

`collect-linux.sh` 会生成可分享的只读报告。`jiaolongctl` 已实现精确 DMI/主板/BIOS 白名单、上游驱动绑定检查和以下受限命令，但在首份 Linux 报告审核完成前不要实际写入；可以先使用全流程校验但不写 sysfs 的 `--dry-run`：

```bash
sudo ./tools/jiaolongctl --dry-run profile balanced
sudo ./tools/jiaolongctl --dry-run keyboard-brightness 2
sudo ./tools/jiaolongctl --dry-run keyboard-mode fixed
sudo ./tools/jiaolongctl --dry-run gpu-mode hybrid --confirm-reboot-required
```

工具只允许官方 0.3.15 使用的安静/平衡/性能、Hybrid/Discrete、键盘亮度 0–3 和键盘模式；不提供 `fan_boost`、手动风扇、UMA 或未经蛟龙官方程序使用的全速 profile。MUX 工具永不自动重启。

## 许可证

代码以 GPL-2.0-or-later 发布。第三方项目和 Linux 上游代码保留各自版权。
