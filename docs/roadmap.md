# 项目路线图

## 已完成

- 阶段 0–5：Windows 协议确认、Linux 只读绑定、风扇识别、低风险写入、
  Discrete/KDE Wayland 和稳定性验证；
- 保守的 `jiaolongctl` CLI、安全白名单、单元测试与 GitHub Actions。

## 里程碑 6：交互式 TUI

### 6.1 首个可用版本（完成）

- [x] 使用 Textual 展示 DMI、驱动、温度、风扇、profile、MUX 和键盘状态；
- [x] 支持手动刷新和每 5 秒定时只读刷新；
- [x] 只提供 `jiaolongctl` 已允许的 profile、键盘与 Hybrid/Discrete 操作；
- [x] 普通用户运行界面，写入时通过 `pkexec` 单独提权；
- [x] MUX 保留“需要重启”二次确认，界面永不自动重启；
- [x] 不展示或调用 fan boost、UMA、全速 profile、手动风扇和任意 EC 写入；
- [x] 为命令构造、状态转换和允许选项补充测试；
- [x] 使用 uv 管理并锁定运行时与开发依赖。

验收标准：现有 CLI 行为和测试保持兼容；TUI 在没有 root 权限时可以查看
状态；所有写操作仍经过 `jiaolongctl` 的 DMI、驱动绑定和范围校验。

### 6.2 核心模块化（完成）

- [x] 提供可导入核心 API，复用 `jiaolongctl` 的状态采集和安全操作；
- [x] TUI 直接读取核心 API，CLI 参数保持兼容；
- [x] 设计只接受固定动作和值的 polkit helper，替代 TUI 直接提权 CLI；
- [x] 增加 polkit policy 与安装、卸载脚本；
- [ ] 制作 Arch `PKGBUILD` 和正式发行包。

## 里程碑 7：桌面前端（候选）

在 TUI 数据模型和权限边界稳定后，再评估 KDE/Qt 设置页或系统托盘。
桌面前端不得直接复制 sysfs 写入逻辑。

## 暂缓的上游工作

- `redmi-wmi` 事件 GUID 冲突修复；
- 风扇通道标签修复；
- `fan_boost` payload 机型差异。
