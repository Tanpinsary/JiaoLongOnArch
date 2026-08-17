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
3. 整个 120 秒 CPU 负载期间：

   - `fan1` 范围 2,662–5,085 RPM，均值约 4,598 RPM；
   - `fan2` 范围 2,632–5,073 RPM，均值约 4,599 RPM；
   - 稳定段 `fan1 - fan2` 为 -117 到 +127 RPM，均值约 +7 RPM；
   - `fan1`/`fan2` 相关系数约 0.976。

   **没有出现一个通道单独响应 CPU 负载的现象。**

初步结论：CPU-only 负载不能把 `fan1` 与 `fan2` 区分为 CPU/GPU；
两者至少受同一热策略同步驱动，或者该模具的两个物理风扇共同响应
CPU 热源。需要 GPU-only 对照才能继续判断。

## 本环境的限制

- 当前工作 shell 没有 `/dev/nvidia*` 和 `/dev/dri/*` 设备节点；
  `mknod` 被拒绝，`nvidia-smi` 无法通信，因此不能从这里直接产生
  NVIDIA GPU-only 负载。
- 桌面会话本身有 Firefox、QQ、dsh 等常驻负载，空闲 CPU 温度约
  70–83°C；正式判定前应尽量关闭这些进程，或记录基线并扣除影响。

## vkcube + NVENC 同步运行（2026-08-17 16:34）

第一次同步 GPU 负载使用 2 个 vkcube + 3 路 4K60 `hevc_nvenc`。结果：

- GPU 高 utilization 持续约 237 秒；
- 功耗中位数 24.0 W，P90 32.1 W，**最大只有 32.17 W**；
- GPU 温度最大 64°C，几乎没有形成 GPU 热负载；
- CPU `temp1_input` 反而在负载初期达到 90°C，无法排除 CPU 对风扇的
  贡献；
- 该时段的 `fan1`/`fan2` 相关系数 0.9947，仍完全同步。

结论：vkcube 的 99% utilization 是轻量 shader 下的指令/呈现占用，
不能代表真实 TGP 负载；3 路 NVENC 也只贡献了很少功耗。必须改用
计算密集负载，并同时记录 SM/MEM 时钟与 enforced power limit。

## Discrete 下 vkcube + NVENC 同步运行（2026-08-18 00:04）

阶段 4 已通过 BIOS 进入 Discrete。相同负载在独显直连下复测：

- `enforced.power.limit` 为 **80 W**；
- 实际 `power.draw` 高 utilization 段均值 36.7 W，最大 **43.75 W**；
- SM 时钟最高 2,565 MHz，显存最高 8,001 MHz；
- GPU 温度最大 67°C；
- CPU `temp1_input` 仍在负载初期达到 92°C；
- 负载段 `fan1/fan2` 相关系数 0.995，差值 -136 到 +139 RPM，
  两个风扇仍然完全同步。

注意：80 W 是 enforced power limit，不是实际功耗。vkcube + NVENC
在 Discrete 下只把实际功耗从 32 W 级提高到约 44 W，仍未压满 TGP。
还需要 hashcat 这类计算密集负载。

## Discrete + hashcat 80W 最终测试（2026-08-18 00:15）

`hashcat -b --benchmark-all -d 1` 成功把 dGPU 压到 enforced power limit：

| 指标 | 值 |
|---|---|
| 高 utilization 时长 | 约 191 秒 |
| power.draw 均值/中位数/最大 | 75.4 / 79.9 / 80.59 W |
| GPU 温度均值/最大 | 77.3 / 80.0°C |
| SM 时钟均值 | 2,462 MHz |
| enforced.power.limit | 80 W |
| CPU temp1 最大 | 99°C |
| fan1 负载段 | 2,665 → 5,109 RPM，均值 4,651 RPM |
| fan2 负载段 | 2,648 → 5,061 RPM，均值 4,668 RPM |
| fan1 - fan2 | -127 到 +128 RPM，均值 -17 RPM |
| fan1/fan2 相关系数 | **0.9971** |
| fan3 | 始终 0 RPM |

分析：

- 这是本项目第一次真实接近 TGP 的 GPU-only 计算负载；
- 即使 GPU 功耗达到 80 W、GPU 温度 80°C，fan1 与 fan2 仍然几乎完全
  同步升到约 5,000 RPM；
- CPU 温度同时升到 99°C，说明该模具 CPU/GPU 共用热系统，CPU 温度
  传感器会被 dGPU 热量显著加热；
- 因此功能 13 的前两个字段不能用于区分“CPU 风扇”和“GPU 风扇”。

## 阶段 2 最终结论

1. `fan1` 与 `fan2` 在 CPU-only、GPU-only 和 80 W GPU 计算负载下都
   同步响应，相关系数分别为 0.976、0.995、0.997。
2. 上游 `fan1_label=CPU`、`fan2_label=GPU` 在 MRID6-23 V35 上
   **无法验证，且现有数据不支持这种区分**。
3. `fan3` 始终为 0 RPM。
4. 风扇通道只能称为 `fan channel 0` / `fan channel 1`；建议向上游
   报告并推动将标签改为不含 CPU/GPU 语义的名称，或至少按机型 quirk
   屏蔽这两个标签。
5. 功能 13 的 RPM little-endian 解释继续成立：80 W 测试中两个字段
   在 2,600–5,100 RPM 范围内变化，大端解释会得到不可能的数值。
