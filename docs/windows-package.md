# 官方 Windows 控制中心样本

## 来源与完整性

- 官方链接：`https://driver.mechrevo.com/d.mechrevo.com/driver/MECHREVO2023/JL16Pro/JLkzzxSetup.zip`
- ZIP 中的原始文件名：`蛟龙游戏控制中心Setup.exe`
- ZIP SHA-256：`b0ee13441c6902fda7f8d872d72856c8bf37e6bd5946d88beedd364e5971328b`
- EXE SHA-256：`d8b7a06ece91693b3beb44be2f4c7e070bef07bf8f89b7173a3db0bc24088304`
- 安装器：Inno Setup 6.3.0
- 产品名称：蛟龙游戏控制中心
- 产品版本：0.3.15
- EXE 大小：90,956,224 字节

样本和解包文件只保存在 Git 忽略的 `artifacts/`，不会提交或重新分发。

## Authenticode

使用 `osslsigncode verify` 校验通过：

- PE checksum 一致；
- SHA-256 Authenticode message digest 一致；
- 签名者：`Shenzhen Bitland Information Technology Co., Ltd.`；
- GlobalSign EV Code Signing 证书；
- DigiCert 时间戳：2025-09-26 09:10:20 UTC；
- 签名和时间戳均验证成功。

这直接解释了 Linux 上游驱动为什么命名为 `bitland-mifs-wmi`：官方控制中心自身就是深圳市宝龙达信息技术有限公司签名的软件。

## 静态核对结果

安装器包含未混淆的 .NET 6 WPF 主程序、Portable PDB、热键服务、NvAPIWrapper 和 `KaronOC` 原生 DLL；没有发现为普通风扇控制安装的额外内核驱动。主程序源构建路径显示为 `MRID6_23_JiaoLong/controlcenter-osd/charon_gen2/MRID623CC`。

主程序的 `WMIMethodServices` 已确认：

- 固定构造 32 字节请求；
- `byte[1]` 为 250 GET、251 SET；
- `byte[3]` 为功能号；
- SET 值从 `byte[4]` 开始；
- 调用 `root\\WMI` 下 `MICommonInterface.InstanceName='ACPI\\PNP0C14\\MIFS_0'` 的 `MiInterface`；
- GET 从 `OutData` 读取结果。

与 Linux 直接相关的行为：

- 性能模式：功能 8，蛟龙 UI 只使用 0/1/2；
- MUX：功能 9，只使用 Hybrid 0、Discrete 1，写入后执行两秒倒计时重启；
- 风扇转速：功能 13；官方 UI 只显示第一个字段为笼统 FanSpeed；
- 环境/Logo 灯：功能 15；
- RGB 模式/颜色/亮度：功能 16/17/18；
- 手动风扇开关：功能 20，把 0/1 写入 payload 0；
- 手动风扇目标：功能 21，把 22–58 的目标字节写入 payload 0；
- CPU 温度与功耗限制：功能 22/23。

`KaronOC` 只导出 AMD P-state 设置读取函数；NVIDIA 监控/调校使用 NvAPIWrapper。`BLDHotKeyService` 负责 Windows 热键/OSD，并不构成 Linux 固件控制的必要依赖。

最大的上游差异是当前 `bitland-mifs-wmi` 的 `fan_boost` 给功能 20 发送 `{fan_type, state}`，而这份官方蛟龙程序发送 `{state}`。该接口在真机确认前不能写入。
