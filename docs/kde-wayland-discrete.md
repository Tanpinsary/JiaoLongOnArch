# KDE Wayland 独显直连兼容记录

## 事故现象

进入 KDE 密码界面后黑屏。日志显示 KWin 以 legacy modesetting 启动，
随后反复出现：

```text
Atomic Mode Setting requested off via environment variable.
Using legacy mode on GPU "/dev/dri/card1" / "/dev/dri/card2"
GL_INVALID_OPERATION ... <image> and <target> are incompatible
Invalid framebuffer status: "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT"
Applying output configuration failed!
```

## 原因

上一个会话中 KWin 继承了 `KWIN_DRM_NO_AMS=1`。该变量强制关闭 atomic
mode setting，使 KWin 回退到 legacy modesetting。此路径在 NVIDIA 独显
直连 + `nvidia_drm` 下不能正确分配 EGL framebuffer，最终输出配置失败
并黑屏。

该变量不是当前持久化文件写入的：

- `/etc/environment`、`environment.d`、`plasma-workspace/env`、
  systemd user drop-in、fish/bash history 中均无匹配；
- 当前 `systemctl --user show-environment` 没有该变量；
- Steam/QQ 崩溃转储中出现的 `KWIN_DRM_NO_AMS=1` 只是进程崩溃时保存的
  environ 快照，不是来源。

因此判断是之前某个 agent 通过临时 user-session 环境（例如
`systemctl --user set-environment KWIN_DRM_NO_AMS=1`）注入，重启后
消失。Grep 卡在 Steam 只是因为 Wine prefix 和 crashpad 目录体积大，
扫描时间过长，与 Steam 本身无关。

## 当前独显直连状态（2026-08-17 23:40 启动）

- `gpu_mode = discrete`；
- KWin DRM backend 正常运行；
- `Atomic Mode Setting on GPU 0/1 = true`；
- OpenGL：NVIDIA RTX 4060 Laptop GPU，EGL 平台；
- 输出：eDP-2，2560x1600@165；
- `jiaolongctl status = 0`；
- 键盘亮度已设为 0。

当前 KWin 日志没有 legacy/GL framebuffer 错误，Wayland 独显渲染路径
正常。

## 稳定性要求

1. **永远不要在独显直连下设置 `KWIN_DRM_NO_AMS=1`。**
   默认 atomic modesetting 才是 NVIDIA + KDE Wayland 的正确路径。
2. 保持 NVIDIA DRM modeset 配置：

   ```bash
   cat /etc/modprobe.d/nvidia-modeset.conf
   # options nvidia_drm modeset=1 fbdev=1
   ```

3. 如果再次出现黑屏，先确认环境：

   ```bash
   systemctl --user show-environment | grep -i kwin
   # 如有 KWIN_DRM_NO_AMS，执行：
   systemctl --user unset-environment KWIN_DRM_NO_AMS
   # 然后注销或重启图形会话
   ```

4. 可选用早期 KMS，在 `/etc/mkinitcpio.conf` 中：

   ```bash
   MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
   sudo mkinitcpio -P
   ```

   当前机器未启用早期 KMS 也已正常进入桌面，因此该步骤不是必须。
5. 排查 Wayland 状态时使用：

   ```bash
   kscreen-doctor -o
   qdbus6 org.kde.KWin /KWin supportInformation
   journalctl -b -t kwin_wayland
   ```
