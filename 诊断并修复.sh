#!/bin/bash

echo "=========================================="
echo "Stardew Valley 翼龙面板诊断脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

镜像名称="ghcr.mirrorify.net/acgtap/stardew-multiplayer-docker:latest"

echo "步骤 1: 检查 Dockerfile 修改"
echo "----------------------------------------"
if grep -q 'ENTRYPOINT \[\]' docker/Dockerfile; then
    echo -e "${GREEN}✓${NC} Dockerfile 包含 ENTRYPOINT [] 清空指令"
else
    echo -e "${RED}✗${NC} Dockerfile 缺少 ENTRYPOINT [] - 这是必需的！"
    echo "  请确保 Dockerfile 最后有:"
    echo "  ENTRYPOINT []"
    echo "  CMD [\"/bin/bash\", \"/startapp.sh\"]"
fi

if grep -q '/etc/s6/init/env' docker/Dockerfile; then
    echo -e "${GREEN}✓${NC} Dockerfile 创建了 s6 所需目录"
else
    echo -e "${YELLOW}⚠${NC} Dockerfile 可能缺少 s6 目录创建"
fi

echo ""
echo "步骤 2: 检查本地镜像"
echo "----------------------------------------"
if docker images | grep -q "stardew-multiplayer-docker"; then
    echo -e "${GREEN}✓${NC} 找到本地镜像:"
    docker images | grep "stardew-multiplayer-docker"
    
    # 获取镜像的 ENTRYPOINT
    echo ""
    echo "检查镜像的 ENTRYPOINT:"
    ENTRYPOINT=$(docker inspect "$镜像名称" 2>/dev/null | grep -A 5 '"Entrypoint"' | head -10)
    if echo "$ENTRYPOINT" | grep -q '"Entrypoint": null'; then
        echo -e "${GREEN}✓${NC} 镜像的 ENTRYPOINT 已清空（null）- 正确！"
    elif echo "$ENTRYPOINT" | grep -q '"Entrypoint": \[\]'; then
        echo -e "${GREEN}✓${NC} 镜像的 ENTRYPOINT 是空数组 - 正确！"
    else
        echo -e "${RED}✗${NC} 镜像仍然有 ENTRYPOINT:"
        echo "$ENTRYPOINT"
        echo -e "${YELLOW}  这意味着镜像需要重新构建！${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC} 本地没有找到镜像"
fi

echo ""
echo "步骤 3: 构建建议"
echo "----------------------------------------"
echo "如果上面的检查失败，请执行以下命令："
echo ""
echo -e "${YELLOW}# 1. 清除 Docker 缓存${NC}"
echo "docker builder prune -f"
echo ""
echo -e "${YELLOW}# 2. 删除旧镜像（如果存在）${NC}"
echo "docker rmi -f $镜像名称"
echo ""
echo -e "${YELLOW}# 3. 重新构建（不使用缓存）${NC}"
echo "cd \"$PWD\""
echo "docker build --no-cache -t $镜像名称 -f docker/Dockerfile docker/"
echo ""
echo -e "${YELLOW}# 4. 验证新镜像的 ENTRYPOINT${NC}"
echo "docker inspect $镜像名称 | grep -A 5 '\"Entrypoint\"'"
echo ""
echo -e "${YELLOW}# 5. 推送到仓库${NC}"
echo "docker push $镜像名称"
echo ""

echo "步骤 4: 翼龙面板操作"
echo "----------------------------------------"
echo "在翼龙节点服务器上："
echo ""
echo -e "${YELLOW}# 1. 停止容器${NC}"
echo "docker ps -a | grep stardew"
echo "docker stop <container_id>"
echo "docker rm <container_id>"
echo ""
echo -e "${YELLOW}# 2. 删除旧镜像${NC}"
echo "docker rmi $镜像名称"
echo ""
echo -e "${YELLOW}# 3. 拉取新镜像${NC}"
echo "docker pull $镜像名称"
echo ""
echo -e "${YELLOW}# 4. 验证镜像 ENTRYPOINT${NC}"
echo "docker inspect $镜像名称 | grep -A 5 '\"Entrypoint\"'"
echo "# 应该看到 null 或 []"
echo ""

echo "步骤 5: 快速测试"
echo "----------------------------------------"
echo "在推送到翼龙前，可以先本地测试："
echo ""
echo "docker run -it --rm \\"
echo "  -e P_SERVER_UUID=test \\"
echo "  -e VNC_PASSWORD=test123 \\"
echo "  $镜像名称"
echo ""
echo "如果成功，应该看到："
echo "  ==> Running in Pterodactyl mode - bypassing s6-overlay"
echo ""
echo "=========================================="
echo "诊断完成"
echo "=========================================="

