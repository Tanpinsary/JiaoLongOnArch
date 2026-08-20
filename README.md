# JiaoLongOnArch

机械革命蛟龙 16 Pro（2023，Ryzen 7 7745HX / RTX 4060）在 Linux 上的固件控制兼容项目。

## 当前状态

项目已完成硬件确认、低风险控制、Discrete 模式和阶段 5 稳定性真机验证。
首个里程碑只覆盖固件公开的 MIFS WMI 接口，
不直接写 EC RAM，也不实现 Ryzen SMU、GPU 超频或降压。

Linux 上游已经在 2026 年合入 [`bitland-mifs-wmi`](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/bitland-mifs-wmi.c)，目标接口与蛟龙控制中心使用的接口一致。当前 Arch `linux` 已进入 7.1 系列，并明确配置 `CONFIG_BITLAND_MIFS_WMI=m`，因此不再编写会争抢同一 WMI GUID 的重复 DKMS 驱动。本项目优先完成：

1. 确认 7745HX 机型的 DMI 和两个 WMI GUID；
2. 对比 Windows 官方控制中心和上游协议；
3. 提供不会调用写方法的 Windows/Linux 采集工具；
4. 为内核自带驱动提供安全、可确认的用户态控制工具；
5. 将真机发现的字段错误或缺失功能直接修复到 Linux 上游。

Windows 报告已确认本机为 `Jiaolong Series MRID6` / `MRID6-23` / BIOS `MRID6_23_P_V35`，活动实例为 `ACPI\\PNP0C14\\MIFS_0`；精确白名单下的 14 个 GET 全部成功。用户已经通过官方控制中心完成 Discrete 1 → Hybrid 0 并重启复查。

Arch 7.1.6 真机阶段 1 已通过：DMI 白名单、控制 GUID、hwmon、
platform profile、键盘 LED、`gpu_mode=hybrid` 和 `kb_mode=fixed` 均
只读正常。事件 GUID 与 `redmi-wmi` 存在上游 alias 冲突，已通过 sysfs
重绑完成验证，重启持久化方案记录在
[`docs/linux-stage1-results.md`](docs/linux-stage1-results.md)。

阶段 2 风扇识别已完成：CPU-only 与约 80 W GPU-only 测试均显示前两个
风扇通道同步，不能可靠标记为 CPU/GPU。阶段 3 低风险写入已完成：键盘
亮度、`kb_mode=cyclic/fixed`、三个 profile 均通过并恢复基线；
`kb_mode=off` 的固件回读语义保留为上游缺口。阶段 4 已通过 BIOS 进入
Discrete，KDE Wayland 在 NVIDIA 独显直连下正常。阶段 5 已完成三个允许
profile 的挂起/恢复与热重启，并跨 profile 覆盖 AC 插拔和冷启动；进度见
[`docs/linux-stage2-progress.md`](docs/linux-stage2-progress.md)、
[`docs/linux-stage3-results.md`](docs/linux-stage3-results.md)、
[`docs/kde-wayland-discrete.md`](docs/kde-wayland-discrete.md) 和
[`docs/linux-stage5-progress.md`](docs/linux-stage5-progress.md)。

## 已知固件接口

- 控制 GUID：`B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B`
- 事件 GUID：`46C93E13-EE9B-4262-8488-563BCA757FEF`
- WMI 方法 ID：`1`
- 32 字节请求：字节 1 为操作码，字节 3 为功能号，字节 4 起为参数

协议细节见 [`docs/protocol.md`](docs/protocol.md)，目标 DMI 见 [`docs/hardware.md`](docs/hardware.md)，Windows 固件读取结果见 [`docs/windows-read-results.md`](docs/windows-read-results.md)，Arch 7.1 阶段 1 结果见 [`docs/linux-stage1-results.md`](docs/linux-stage1-results.md)，内核与 Arch 集成状态见 [`docs/upstream-status.md`](docs/upstream-status.md)，官方 Windows 样本记录见 [`docs/windows-package.md`](docs/windows-package.md)，真机步骤见 [`docs/test-plan.md`](docs/test-plan.md)。

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

`collect-linux.sh` 会生成可分享的只读报告。`jiaolongctl` 已实现精确 DMI/主板/BIOS 白名单、上游驱动绑定检查和以下受限命令，但在首份 Linux 报告审核完成前不要实际写入；可以先使用全流程校验但不写 sysfs 的 `--dry-run`，它不需要 root：

```bash
./tools/jiaolongctl --dry-run profile balanced
./tools/jiaolongctl --dry-run keyboard-brightness 2
./tools/jiaolongctl --dry-run keyboard-mode fixed
./tools/jiaolongctl --dry-run gpu-mode hybrid --confirm-reboot-required
```

蛟龙真机在 Linux 7.1 上存在事件 GUID 与 `redmi-wmi` 的绑定冲突：
`jiaolongctl status` 返回 5 时，需要先按
[`docs/linux-stage1-results.md`](docs/linux-stage1-results.md)
把事件设备重绑到 `bitland-mifs-wmi`，写入命令才会放行。实际写入命令
仍需要 root。

工具只允许官方 0.3.15 使用的安静/平衡/性能、Hybrid/Discrete、键盘亮度 0–3 和键盘模式；不提供 `fan_boost`、手动风扇、UMA 或未经蛟龙官方程序使用的全速 profile。MUX 工具永不自动重启。

## 开发与测试

项目的自动测试不访问真实固件，使用临时目录模拟 sysfs。安装开发依赖后
运行统一检查入口：

```bash
python3 -m pip install -r requirements-dev.txt
make check
```

检查包括 Ruff 静态检查与格式验证、Python 单元测试，以及所有 Shell
脚本的语法检查。GitHub Actions 会在 push 和 pull request 时运行同一套
命令。

## 许可证

代码以 GPL-2.0-or-later 发布。第三方项目和 Linux 上游代码保留各自版权。
