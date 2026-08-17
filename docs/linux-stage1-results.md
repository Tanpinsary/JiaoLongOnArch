# Linux 7.1 真机阶段 1 只读结果

采集时间：2026-08-15。主机 `TanpArch`，内核 `7.1.6-arch1-1`。
本轮没有写入 `platform_profile`、`gpu_mode`、`kb_mode`、`fan_boost`、
键盘亮度、EC RAM 或任何 WMI 方法。

## 结论

阶段 1 已确认大部分绑定，但**未通过**，因为事件 GUID 被
`redmi-wmi` 抢先绑定，`bitland-mifs-wmi` 的事件设备没有建立。
在解决该冲突前，`jiaolongctl` 拒绝任何固件写入。

| 检查项 | 结果 |
|---|---|
| 内核 7.1 + `CONFIG_BITLAND_MIFS_WMI=m` | 通过 |
| 精确 DMI/BIOS 白名单 | 通过 |
| 控制 GUID 存在且绑定 `bitland-mifs-wmi` | 通过 |
| 事件 GUID 存在且绑定 `bitland-mifs-wmi` | **失败：当前为 `redmi-wmi`** |
| `hwmon` / `platform_profile` / 键盘 LED 读取 | 通过 |
| `gpu_mode` / `kb_mode` 只读 | 通过（Hybrid / fixed） |
| `fan_boost` | 未读取；继续保持禁用 |

## DMI/BIOS

| 字段 | 值 |
|---|---|
| `sys_vendor` | `MECHREVO` |
| `product_name` | `Jiaolong Series MRID6` |
| `product_version` | `1` |
| `board_vendor` | `MECHREVO` |
| `board_name` | `MRID6-23` |
| `board_version` | `Base Board Version` |
| `bios_vendor` | `INSYDE Corp.` |
| `bios_version` | `MRID6_23_P_V35` |
| `bios_date` | `01/10/2024` |

## WMI 实例与绑定

Linux WMI 子系统的 sysfs 节点名带有实例号，不是裸 GUID：

| GUID | sysfs 实例 | 驱动 |
|---|---|---|
| `B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B` | `...-4` | `bitland-mifs-wmi` |
| `46C93E13-EE9B-4262-8488-563BCA757FEF` | `...-0` | `redmi-wmi` |

`modinfo` 显示两个模块都声明了同一个事件 GUID alias：

```text
bitland-mifs-wmi:
  alias: wmi:46C93E13-EE9B-4262-8488-563BCA757FEF
  alias: wmi:B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B

redmi-wmi:
  alias: wmi:46C93E13-EE9B-4262-8488-563BCA757FEF
```

当前后果：

- 存在 `Redmibook WMI keys`（`/devices/.../46C...-0/input/input8`）；
- 不存在 `Bitland MIFS WMI hotkeys`；
- `bitland-mifs-wmi` 无法收到键盘灯、profile 或风扇事件通知；
- hwmon 仍可主动轮询控制 GUID，因此温度/风扇读取不受影响。

## 已确认的驱动节点读数

`./tools/jiaolongctl status` 和 `./tools/collect-linux.sh` 的实测输出：

- `hwmon6 name=bitland_mifs`；
  - `temp1_input` 约 54,000–67,000 m°C（54–67°C）；
  - `fan1_input` 约 1,972–2,241 RPM，标签 `CPU`；
  - `fan2_input` 约 1,972–2,243 RPM，标签 `GPU`；
  - `fan3_input` 0 RPM，标签 `SYS`；
  - 注意：标签仍是上游未经验证的 CPU/GPU 顺序，阶段 2 负载测试前不得视为最终结论。
- `platform_profile`：
  - `choices=low-power balanced balanced-performance performance`；
  - 当前 `balanced-performance`（对应固件性能值 1）。
- 键盘 LED：`bitland-mifs-wmi::kbd_backlight`，`max_brightness=3`；
  观察期间 `brightness` 在 0 与 3 之间变化，属动态状态。
- 控制节点：`gpu_mode=hybrid`、`kb_mode=fixed`。
- AC 电源为 `ADP1 type=Mains online=1`；另有未接入的 `ucsi-source-psy-USBC000:001`。

## 发现的工具缺陷

初版 `jiaolongctl` 和 `collect-linux.sh` 使用裸 GUID 拼接 sysfs 路径，
而真实节点为 `GUID-INSTANCE`，因此把两个已存在的 WMI 设备误报为
`absent`。已修复为同时匹配裸 GUID 与数字实例后缀，并新增冲突诊断：

```bash
python3 tools/jiaolongctl --json status
bash tools/collect-linux.sh /home/tanp/Projects/JiaoLongOnArch-Probe-stage1
```

`status` 返回码定义：

- `0`：DMI、控制 GUID、事件 GUID 全部匹配且绑定正确；
- `2`：控制 GUID 不存在；
- `3`：控制 GUID 未绑定 `bitland-mifs-wmi`；
- `4`：事件 GUID 不存在；
- `5`：事件 GUID 被其他驱动绑定（当前实测返回 5）。

## 事件 GUID 冲突分析

`wmi_bus_type.match = wmi_dev_match` 只按 GUID 匹配
`wmi_device_id`；一个 WMI 设备同一时间只能绑定一个驱动。设备驱动核心
会忽略失败的 `probe()` 并尝试下一个匹配驱动
（`drivers/base/dd.c` 中 `__device_attach_driver` 的行为），因此让错误
机型的驱动在 `probe()` 中返回 `-ENODEV` 是可行的修复路线。

`redmi-wmi` 没有 DMI 白名单，所以在蛟龙上也会成功 probe。
`bitland-mifs-wmi` 与 `redmi-wmi` 对事件包的解读并不兼容：

- bitland：`{event_type, event_id, value_low, value_high, ...}`；
- redmi：把前 4 字节整体按 little-endian scancode 查 keymap；
- 两者的事件 ID 语义也不同，例如 bitland 的 17–21 是 Fn J/F/0/1/2/3，
  redmi 的 17–21 映射为 F13–F17。

因此不能简单让两个驱动共享通知，必须确保每个机型只绑定语义匹配的驱动。
上游修复方向：

1. 给 `redmi-wmi` 的事件 probe 增加 Redmi 机型 DMI 白名单；
2. 给 `bitland-mifs-wmi` 的事件 probe 增加 Bitland/MECHREVO 机型 DMI 白名单；
3. 或者把该共享事件 GUID 抽成通用 WMI 事件层，再按 DMI 选择 keymap。

本项目将继续保留本机证据，用于向上游报告或提交修复。

## 本地验证（未执行，需要 root）

在修复上游驱动之前，可以在本机临时验证 bitland 事件驱动本身是否正常：

```bash
sudo sh -c 'echo 46C93E13-EE9B-4262-8488-563BCA757FEF-0 > /sys/bus/wmi/drivers/redmi-wmi/unbind'
sudo sh -c 'echo 46C93E13-EE9B-4262-8488-563BCA757FEF-0 > /sys/bus/wmi/drivers/bitland-mifs-wmi/bind'
./tools/jiaolongctl status
```

预期会新增 `Bitland MIFS WMI hotkeys` input 设备，且 `status` 返回 0。
该操作不写固件，但会改变系统热键驱动绑定；持久化方案待上游修复确认后
再选择 `modprobe.d` 黑名单或 udev `driver_override` 规则。

## 重启复现

2026-08-17 系统重启后再次运行 `jiaolongctl status`，事件 GUID 仍然绑定
`redmi-wmi`，说明这不是一次性模块加载顺序，而是稳定的驱动 alias 冲突。
控制 GUID、hwmon、platform profile、键盘 LED、`gpu_mode=hybrid` 和
`kb_mode=fixed` 均再次只读正常。

## 阶段 1 后续

- 解决事件 GUID 绑定后重新运行 `jiaolongctl status` 和只读采集；
- 观察是否存在 `Bitland MIFS WMI hotkeys`，并触发 Fn/性能切换键核对
  keymap；
- 只有阶段 1 全部通过后，才进入阶段 2 的风扇字段 CPU/GPU 分离负载识别。
