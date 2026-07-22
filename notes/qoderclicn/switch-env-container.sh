#!/bin/bash
# macOS Apple Container 环境一致性切换脚本
# 用途：在 Docker/OrbStack/Colima 容器中创建隔离环境运行 Claude Code / Codex
# 用法：
#   ./switch-env-container.sh us    # 创建美国环境容器
#   ./switch-env-container.sh jp    # 创建日本环境容器
#   ./switch-env-container.sh stop  # 停止并移除容器
#   ./switch-env-container.sh check # 检查容器状态
#   ./switch-env-container.sh shell # 进入已运行的容器
#
# 前提：已安装 Docker Desktop / OrbStack / Colima

set -e

REGION="${1:-check}"
CONTAINER_NAME="ai-coding-env"
IMAGE="node:20-bookworm"

# ============ 区域配置 ============
declare -A TZ_MAP=(
  ["us"]="America/New_York"
  ["jp"]="Asia/Tokyo"
  ["cn"]="Asia/Shanghai"
  ["uk"]="Europe/London"
  ["sg"]="Asia/Singapore"
)

declare -A LOCALE_MAP=(
  ["us"]="en_US.UTF-8"
  ["jp"]="ja_JP.UTF-8"
  ["cn"]="zh_CN.UTF-8"
  ["uk"]="en_GB.UTF-8"
  ["sg"]="en_SG.UTF-8"
)

# 代理配置（Apple Container 用 host.container.internal 指向 macOS 宿主机；
# 若用 Docker Desktop / OrbStack / Colima，请改为 host.docker.internal）
PROXY_HOST="host.container.internal"
PROXY_PORT="7897"

# 工作目录（挂载到容器内）
WORKSPACE="${HOME}/workspace"

# ============ 函数 ============

check_runtime() {
  if command -v docker &>/dev/null; then
    if ! docker info &>/dev/null 2>&1; then
      echo "错误: Docker 未运行"
      echo "  - Docker Desktop: 请启动应用"
      echo "  - OrbStack: 请执行 orb start"
      echo "  - Colima: 请执行 colima start"
      exit 1
    fi
    echo "[运行时] Docker ($(docker --version | awk '{print $3}' | tr -d ','))"
  else
    echo "错误: 未找到 Docker"
    echo "安装方式（任选其一）:"
    echo "  brew install --cask docker        # Docker Desktop"
    echo "  brew install orbstack             # OrbStack (推荐)"
    echo "  brew install colima docker        # Colima"
    exit 1
  fi
}

print_status() {
  echo ""
  echo "===== 容器环境状态 ====="

  if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q "$CONTAINER_NAME"; then
    echo "[状态]   运行中"
    echo "[容器]   $CONTAINER_NAME"
    echo "[镜像]   $(docker inspect --format='{{.Config.Image}}' $CONTAINER_NAME 2>/dev/null)"
    echo "[时区]   $(docker exec $CONTAINER_NAME printenv TZ 2>/dev/null)"
    echo "[Locale] $(docker exec $CONTAINER_NAME printenv LANG 2>/dev/null)"
    echo "[代理]   $(docker exec $CONTAINER_NAME printenv https_proxy 2>/dev/null)"
    echo "[出口IP] $(docker exec $CONTAINER_NAME curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null || echo '无法获取')"
    echo "[运行时间] $(docker inspect --format='{{.State.StartedAt}}' $CONTAINER_NAME 2>/dev/null)"
  else
    echo "[状态]   未运行"
    echo ""
    echo "可用命令:"
    echo "  $0 us|jp|uk|sg  - 创建并启动容器"
    echo "  $0 shell        - 进入已运行的容器"
  fi

  echo ""
  echo "--- 宿主机信息 ---"
  echo "[macOS 时区] $(sudo systemsetup -gettimezone 2>/dev/null || echo $TZ)"
  echo "[代理端口]   $PROXY_PORT (确认代理软件已开启)"
  echo "========================"
  echo ""
}

stop_container() {
  echo ">>> 停止并移除容器 [$CONTAINER_NAME]..."
  docker stop "$CONTAINER_NAME" 2>/dev/null && echo "  已停止" || echo "  容器未运行"
  docker rm "$CONTAINER_NAME" 2>/dev/null && echo "  已移除" || true
}

enter_shell() {
  if docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>/dev/null | grep -q "$CONTAINER_NAME"; then
    echo ">>> 进入容器 [$CONTAINER_NAME]..."
    docker exec -it "$CONTAINER_NAME" bash
  else
    echo "错误: 容器未运行，请先执行 $0 us|jp|uk|sg 创建容器"
    exit 1
  fi
}

create_container() {
  local tz="$1"
  local locale="$2"
  local region="$3"

  # 停止已有容器
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true

  echo ">>> 创建 [$region] 环境容器..."
  echo ""
  echo "  时区:   $tz"
  echo "  Locale: $locale"
  echo "  代理:   http://${PROXY_HOST}:${PROXY_PORT}"
  echo "  工作区: $WORKSPACE → /workspace"
  echo ""

  # 确保工作目录存在
  mkdir -p "$WORKSPACE"

  # 拉取镜像（如果本地没有）
  if ! docker image inspect "$IMAGE" &>/dev/null 2>&1; then
    echo "[1/3] 拉取镜像 $IMAGE ..."
    docker pull "$IMAGE"
  else
    echo "[1/3] 镜像已存在: $IMAGE"
  fi

  # 创建并启动容器
  echo "[2/3] 创建容器..."
  docker run -dit \
    --name "$CONTAINER_NAME" \
    --hostname "dev-${region}" \
    -e TZ="$tz" \
    -e LANG="$locale" \
    -e LC_ALL="$locale" \
    -e LANGUAGE="${locale%%_*}" \
    -e http_proxy="http://${PROXY_HOST}:${PROXY_PORT}" \
    -e https_proxy="http://${PROXY_HOST}:${PROXY_PORT}" \
    -e HTTP_PROXY="http://${PROXY_HOST}:${PROXY_PORT}" \
    -e HTTPS_PROXY="http://${PROXY_HOST}:${PROXY_PORT}" \
    -e no_proxy="localhost,127.0.0.1" \
    -e NO_PROXY="localhost,127.0.0.1" \
    -v "$WORKSPACE:/workspace" \
    -w /workspace \
    --restart unless-stopped \
    "$IMAGE" \
    bash -c "sleep infinity"

  echo "[3/3] 配置容器内环境..."

  # 容器内初始化
  docker exec "$CONTAINER_NAME" bash -c '
    # 安装基础工具
    apt-get update -qq && apt-get install -y -qq \
      git curl wget locales sudo vim \
      > /dev/null 2>&1

    # 生成 locale
    sed -i "s/# ${LANG}/${LANG}/" /etc/locale.gen 2>/dev/null
    locale-gen > /dev/null 2>&1

    # 配置 git（使用英文）
    git config --global init.defaultBranch main

    # 安装 Claude Code
    npm install -g @anthropic-ai/claude-code > /dev/null 2>&1 || true

    # 安装 Codex CLI
    npm install -g @openai/codex > /dev/null 2>&1 || true

    echo "  容器内工具安装完成"
  '

  echo ""
  echo ">>> 容器创建成功！"
  echo ""
  echo "使用方式:"
  echo "  进入容器:  $0 shell"
  echo "  或直接:    docker exec -it $CONTAINER_NAME bash"
  echo ""
  echo "容器内运行 Claude Code:"
  echo "  docker exec -it $CONTAINER_NAME claude"
  echo ""
  echo "容器内运行 Codex:"
  echo "  docker exec -it $CONTAINER_NAME codex"
  echo ""

  # 验证
  echo "--- 验证 ---"
  echo "[时区]   $(docker exec $CONTAINER_NAME date +%Z)"
  echo "[Locale] $(docker exec $CONTAINER_NAME locale | grep LANG)"
  echo "[出口IP] $(docker exec $CONTAINER_NAME curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null || echo '无法获取（检查代理）')"
  echo ""
}

generate_compose() {
  local tz="$1"
  local locale="$2"
  local region="$3"

  local COMPOSE_FILE="${WORKSPACE}/docker-compose.ai-env.yml"

  cat > "$COMPOSE_FILE" << EOF
# AI Coding 隔离环境 - $region
# 用法: docker compose -f docker-compose.ai-env.yml up -d
services:
  ai-coding:
    image: $IMAGE
    container_name: $CONTAINER_NAME
    hostname: dev-${region}
    environment:
      - TZ=$tz
      - LANG=$locale
      - LC_ALL=$locale
      - http_proxy=http://${PROXY_HOST}:${PROXY_PORT}
      - https_proxy=http://${PROXY_HOST}:${PROXY_PORT}
      - no_proxy=localhost,127.0.0.1
    volumes:
      - ${WORKSPACE}:/workspace
    working_dir: /workspace
    restart: unless-stopped
    command: sleep infinity
EOF

  echo "  已生成: $COMPOSE_FILE"
  echo "  启动:   docker compose -f $COMPOSE_FILE up -d"
  echo "  停止:   docker compose -f $COMPOSE_FILE down"
}

# ============ 主逻辑 ============

case "$REGION" in
  check)
    check_runtime
    print_status
    exit 0
    ;;
  stop)
    check_runtime
    stop_container
    exit 0
    ;;
  shell)
    check_runtime
    enter_shell
    exit 0
    ;;
  us|jp|uk|sg|cn)
    check_runtime
    create_container "${TZ_MAP[$REGION]}" "${LOCALE_MAP[$REGION]}" "$REGION"
    generate_compose "${TZ_MAP[$REGION]}" "${LOCALE_MAP[$REGION]}" "$REGION"
    ;;
  *)
    echo "用法: $0 {us|jp|uk|sg|cn|stop|shell|check}"
    echo ""
    echo "  us    - 创建美国环境容器"
    echo "  jp    - 创建日本环境容器"
    echo "  uk    - 创建英国环境容器"
    echo "  sg    - 创建新加坡环境容器"
    echo "  cn    - 创建中国环境容器"
    echo "  stop  - 停止并移除容器"
    echo "  shell - 进入已运行的容器"
    echo "  check - 查看容器状态"
    echo ""
    echo "前提条件:"
    echo "  - 已安装 Docker Desktop / OrbStack / Colima"
    echo "  - macOS 代理软件已开启（端口 $PROXY_PORT）"
    echo "  - 工作目录: $WORKSPACE"
    exit 1
    ;;
esac
