# Linux 阶段 2 风扇字段识别进度

阶段 2 目标：确认功能 13 的前两个 RPM 字段是否真的对应 CPU、GPU。
当前只进行只读 hwmon 采样，不写任何风扇/EC 接口。

## 已确认

- 采样工具：`tools/fan-sample.py`，只读，已通过单元测试。
- 当前 `hwmon` 标签为上游预设 `fan1=CPU`、`fan2=GPU`、`fan3=SYS`；
  这些标签在阶段 2 完成前只能视为字段名，不是验证结论。
- `fan3` 在本机始终为 0 RPM，与 Windows GET 样本一致。

## CPU-only 初步结果（2026-08-17）

方法：8 线程 `sha256sum /dev/zero` 短促加载一次；随后改为 2 线程
`nice -n 19` 加载 120 秒，每 1 秒记录 `temp1_input`、`fan1/2/3_input`。

观察：

1. 8 线程负载使 `temp1_input` 在约 3 秒内从 83°C 升到 96°C，测试
   脚本按 93°C 上限立即停止；风扇在停止后约 12 秒才开始明显上升。
   该轮不用于通道判定。
2. 2 线程负载使温度稳定在约 89–91°C；约 17 秒后两个风扇从约
   2,650 RPM 同步上升到约 5,000 RPM，随后保持。
3. 整个 CPU 负载期间 `fan1` 与 `fan2` 差值大多在 ±50 RPM 以内，
   **没有出现一个通道单独响应 CPU 负载的现象**。

初步结论：CPU-only 负载不能把 `fan1` 与 `fan2` 区分为 CPU/GPU；
两者至少受同一热策略同步驱动，或者该模具的两个物理风扇共同响应
CPU 热源。需要 GPU-only 对照才能继续判断。

## 本环境的限制

- 当前工作 shell 没有 `/dev/nvidia*` 和 `/dev/dri/*` 设备节点；
  `mknod` 被拒绝，`nvidia-smi` 无法通信，因此不能从这里直接产生
  NVIDIA GPU-only 负载。
- 桌面会话本身有 Firefox、QQ、dsh 等常驻负载，空闲 CPU 温度约
  70–83°C；正式判定前应尽量关闭这些进程，或记录基线并扣除影响。

## 下一步

1. 在用户桌面终端产生 NVIDIA-only 负载，例如：

   ```bash
   __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia vkcube
   # 或 glxgears / 稳定的 CUDA 负载，持续 3–5 分钟
   ```

   同时由本项目采样：

   ```bash
   ./tools/fan-sample.py --duration 300 --interval 1 > gpu-only.csv
   ```

2. 对比 CPU-only、GPU-only、空闲三段曲线的 fan1/fan2 响应。
3. 若 GPU-only 仍让两者同步上升，则向上游报告：功能 13 前两个字段
   不能按当前 CPU/GPU 标签区分，至少对 MRID6-23 V35 不成立。
