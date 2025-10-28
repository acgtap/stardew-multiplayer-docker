# s6-overlay 错误快速修复指南

## 问题
在 Pterodactyl 面板运行时出现错误：
```
s6-hiercopy: fatal: unable to copy hierarchy from /etc/s6/init/env to /var/run/s6/env-stage1: No such file or directory
```

## 无需重新构建镜像的解决方案

### 方法 1：重新导入更新的 Egg（推荐）

1. **下载更新的 Egg 文件**
   - 从本仓库获取最新的 `egg-stardew-valley.json`

2. **在 Pterodactyl 管理面板中导入**
   - 进入 **Admin Panel** → **Nests**
   - 找到 Stardew Valley 的 Nest
   - 点击 **Import Egg**
   - 上传 `egg-stardew-valley.json`
   - 选择 **覆盖现有 Egg**

3. **重启服务器**
   - 返回到您的 Stardew Valley 服务器
   - 点击 **重启**

### 方法 2：手动修改 Egg 配置

如果您无法重新导入 Egg，可以手动修改：

1. **进入 Egg 编辑界面**
   - Admin Panel → Nests → 选择包含 Stardew Valley 的 Nest
   - 点击 Stardew Valley Egg 的编辑按钮

2. **修改启动命令**
   - 在 **Process Configuration** 标签页
   - 找到 **Startup Command** 字段
   - 将值从：`/startapp.sh`
   - 改为：`/bin/bash /startapp.sh`

3. **保存并重启**
   - 保存 Egg 配置
   - 返回服务器并重启

### 方法 3：通过服务器 Startup 修改（临时方案）

如果您没有管理员权限修改 Egg：

1. 进入您的服务器 → **Startup** 标签
2. 查找是否有 **Startup Command** 覆盖选项
3. 如果有，设置为：`/bin/bash /startapp.sh`

注意：此方法可能不适用于所有 Pterodactyl 配置。

## 验证修复是否成功

重启服务器后，在控制台中您应该看到：

✅ **成功输出：**
```
==> Running in Pterodactyl mode - bypassing s6-overlay
Pterodactyl deployment detected - using /home/container for saves
==> Starting VNC services for Pterodactyl...
==> VNC password configured
==> Started Xvfb (PID: xxx) at 1200x900
==> Started x11vnc on port 5900
==> Started Web VNC on port 5800
==> Game server port: 24642
```

❌ **不应该再看到：**
```
s6-hiercopy: fatal: unable to copy hierarchy...
```

## 原理说明

### 为什么会出现这个错误？

基础镜像 `jlesage/baseimage-gui` 使用 s6-overlay 进程管理系统。在 Pterodactyl 环境中：
- 容器的某些目录（如 `/var/run`）可能是只读的
- s6-overlay 在脚本运行前就尝试初始化
- 无法创建必需的目录结构，导致失败

### 修复方案如何工作？

1. **绕过 s6-overlay ENTRYPOINT**
   - 原来：容器启动 → s6-overlay 初始化（失败）→ 脚本运行
   - 现在：容器启动 → 直接运行 bash 脚本

2. **脚本自行管理服务**
   - 脚本检测到 Pterodactyl 模式
   - 跳过 s6-overlay 相关设置
   - 直接启动 VNC、X11、游戏服务器

3. **保持兼容性**
   - 非 Pterodactyl 环境（普通 Docker）仍然正常工作
   - 所有功能保持不变

## 测试清单

修复后请验证：

- [ ] 容器正常启动，无 s6-overlay 错误
- [ ] 控制台显示 "Running in Pterodactyl mode - bypassing s6-overlay"
- [ ] VNC 服务启动（端口 5900）
- [ ] Web VNC 可访问（端口 5800）
- [ ] 可以通过 VNC 密码连接
- [ ] 游戏服务器正常运行
- [ ] 存档正确保存到 `/home/container/Saves/`

## 常见问题

### Q: 修改后仍然报错？
A: 确保：
- Egg 配置已正确保存
- 服务器已完全重启（不是重载）
- 使用的是正确的镜像标签

### Q: VNC 无法连接？
A: 检查：
- VNC 端口是否正确分配
- VNC 密码是否设置（环境变量 `VNC_PASSWORD`）
- 查看控制台确认 VNC 服务是否启动

### Q: 游戏存档丢失？
A: 所有存档都在 `/home/container/Saves/`，Pterodactyl 会自动持久化此目录。

### Q: 需要重新构建镜像吗？
A: **不需要！** 此修复只需更新 Egg 配置，无需重新构建镜像。

## 获取帮助

如果问题仍然存在：
1. 查看完整的控制台日志
2. 检查 Pterodactyl 版本是否兼容
3. 在 GitHub Issues 报告问题，附上：
   - 完整错误日志
   - Egg 配置截图
   - Pterodactyl 版本

---

**最后更新：** 2025-10-28  
**适用镜像：** ghcr.mirrorify.net/acgtap/stardew-multiplayer-docker:latest

