#!/bin/bash
# 翼龙面板容器清理脚本
# 用于清理旧的游戏文件，准备重新部署

echo "=================================="
echo "翼龙面板容器清理脚本"
echo "=================================="
echo ""

# 检查是否在翼龙面板环境中
if [ ! -d "/home/container" ]; then
    echo "错误：这不是翼龙面板环境（/home/container 不存在）"
    exit 1
fi

echo "警告：此脚本将删除以下内容："
echo "  - /home/container/Stardew/ (游戏文件)"
echo "  - /home/container/xdg/ (配置和缓存)"
echo ""
echo "以下内容将被保留："
echo "  - /home/container/Saves/ (存档文件)"
echo ""

read -p "确定要继续吗？(输入 yes 确认): " confirm

if [ "$confirm" != "yes" ]; then
    echo "操作已取消"
    exit 0
fi

echo ""
echo "开始清理..."

# 删除游戏文件
if [ -d "/home/container/Stardew" ]; then
    echo "  删除游戏文件: /home/container/Stardew"
    rm -rf /home/container/Stardew
    echo "  ✓ 已删除"
else
    echo "  跳过: /home/container/Stardew (不存在)"
fi

# 删除 XDG 目录（配置和缓存）
if [ -d "/home/container/xdg" ]; then
    echo "  删除配置和缓存: /home/container/xdg"
    rm -rf /home/container/xdg
    echo "  ✓ 已删除"
else
    echo "  跳过: /home/container/xdg (不存在)"
fi

# 删除启动脚本
if [ -f "/home/container/start_game.sh" ]; then
    echo "  删除启动脚本: /home/container/start_game.sh"
    rm -f /home/container/start_game.sh
    echo "  ✓ 已删除"
fi

# 删除日志文件
if [ -f "/home/container/x11vnc.log" ]; then
    echo "  删除 VNC 日志: /home/container/x11vnc.log"
    rm -f /home/container/x11vnc.log
    echo "  ✓ 已删除"
fi

echo ""
echo "=================================="
echo "清理完成！"
echo "=================================="
echo ""
echo "下一步："
echo "1. 重启容器"
echo "2. 游戏文件将自动复制到正确的位置"
echo "3. 你的存档文件已被保留在 /home/container/Saves/"
echo ""

