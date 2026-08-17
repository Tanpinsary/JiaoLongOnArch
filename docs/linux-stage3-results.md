# Linux 阶段 3 低风险写入结果

测试时间：2026-08-17。所有写入均通过 `tools/jiaolongctl` 白名单和
驱动绑定检查，不涉及 `fan_boost`、`gpu_mode`、UMA、EC RAM 或任意 WMI。

## 键盘亮度：通过

基线 `brightness=3`。依次写入 0、1、2、3，每步等待 60 秒，读回值均与
目标一致；最后恢复基线 3。

## 键盘 RGB 属性确认

`GaoXanSheng/JiaoLongControl` 的开源实现确认 7945HX/4060 蛟龙 16 Pro
的键盘是 RGB 键盘：

- `RGBKeyboardMode`：`Mode_Off = 0`、`Mode_RGBFixedMode = 2`；
- `KeyboardController` 提供 `GetColor()` / `SetColor(r, g, b)`；
- 键盘亮度为 0–3；
- 前端页面为“键盘 RGB 灯效”，提供 RGB 通道滑杆和快捷配色。

用户当前观察键盘亮蓝光，与本机 Windows 样本功能 17 返回
`(0, 255, 199)`、功能 16 返回 `fixed` 一致。因此此前“不是完整 RGB
键盘”的判断不成立，已撤回。

## 键盘模式：cyclic 与 fixed 通过；off 读回语义待确认

基线 `kb_mode=fixed`。测试结果：

| 写入 | 读回 | 等待 | 判定 |
|---|---|---|---|
| `cyclic` | `cyclic` | 60s | 通过 |
| `fixed` | `fixed` | 60s | 通过 |
| 恢复 `fixed` | — | 60s | 通过 |

`off` 仍为：

```text
error: write did not read back as requested: expected='off', observed='fixed'
```

说明：

- sysfs 写入本身没有返回错误；
- 上游 `kb_mode_store` 的 WMI SET 被固件接受；
- 随后 GET 功能 16 仍然返回 `fixed`。

有两种可能，不能用当前日志区分：

1. 固件确实忽略 `off`；
2. 固件已经关闭背光，但功能 16 GET 仍返回关闭前的 `fixed`。

该机键盘已是 RGB，且开源实现明确提供 Off/Fixed 模式，因此不能直接
下“不支持 off”的结论。下一步需要人工观察：执行 `keyboard-mode off`
后，物理键盘背光是否熄灭。

## Profile：通过

基线 `balanced-performance`。测试结果：

| 写入 | Linux 值 | 读回 | 等待 | 判定 |
|---|---|---|---|---|
| `quiet` | `low-power` | `low-power` | 60s | 通过 |
| `balanced` | `balanced` | `balanced` | 60s | 通过 |
| `performance` | `balanced-performance` | `balanced-performance` | 60s | 通过 |
| 恢复 `performance` | `balanced-performance` | — | 60s | 通过 |

`jiaolongctl` 没有暴露固件 profile 3 对应的 Linux `performance`。

## 阶段 3 结论

- 键盘亮度、cyclic/fixed、三个官方 profile 均通过；
- `off` 待人工观察背光后定性；
- 所有测试结束后系统已恢复到亮度 3、`kb_mode=fixed`、
  `profile=balanced-performance`；
- 完整日志：
  `/home/tanp/Projects/JiaoLongOnArch-stage3-20260817-223612/run.log`。
