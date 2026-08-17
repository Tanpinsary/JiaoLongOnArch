# Linux 阶段 3 低风险写入结果

测试时间：2026-08-17。所有写入均通过 `tools/jiaolongctl` 白名单和
驱动绑定检查，不涉及 `fan_boost`、`gpu_mode`、UMA、EC RAM 或任意 WMI。

## 键盘亮度：通过

基线 `brightness=3`。依次写入 0、1、2、3，每步等待 60 秒，读回值均与
目标一致；最后恢复基线 3。

## 键盘模式：发现 off 不支持

基线 `kb_mode=fixed`。

`tools/jiaolongctl keyboard-mode off` 的执行结果：

```text
error: write did not read back as requested: expected='off', observed='fixed'
```

说明：

- sysfs 写入本身没有返回错误；
- 上游 `kb_mode_store` 的 WMI SET 被固件接受，但功能 16 值 0 没有改变
  固件状态；
- 本机键盘读取到 `fixed` 后保持不变，与 Windows 阶段功能 10 语义不明
  的记录一致。

初步判断：MRID6-23 V35 的键盘并非全功能 RGB 键盘，固件忽略 RGB mode
`off`；关闭背光应使用键盘亮度 0，而不是 `kb_mode=off`。这是上游
`bitland-mifs-wmi` 暴露了该机型不支持的 `off` 选项，属于待报告缺口。

## 待完成

- `kb_mode=cyclic` 与 `kb_mode=fixed` 写入及读回；
- profile `quiet` / `balanced` / `performance` 写入及读回；
- 每项等待 60 秒并在完成后恢复基线。
