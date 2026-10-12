#!/usr/bin/env bash
# =============================================================================
# build.sh —— 构建 Qt 可编译环境的 Docker 镜像
#
# 用法：
#   ./build.sh              # 构建两条线（modern + legacy）
#   ./build.sh modern       # 只构建现代线（Ubuntu 22.04）
#   ./build.sh legacy       # 只构建老系统线（AlmaLinux 8）
#
# 可选环境变量：
#   USER_UID / USER_GID     映射到容器内的非 root 用户（默认取当前用户）
#   GCC_TOOLSET             老系统线工具链（默认 gcc-toolset-11）
#   NO_CACHE=1              不用构建缓存，全量重建
#
# 说明：
#   - 本脚本只构建镜像，**不在镜像里编译 Qt**。
#   - 依赖默认用 BuildKit 以获得更好的缓存与 --build-arg 支持。
# =============================================================================
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOCKER_DIR"

TARGET="${1:-all}"

# 默认让容器内用户与当前宿主机用户对齐，避免挂载目录里的文件属主错乱
export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"
export GCC_TOOLSET="${GCC_TOOLSET:-gcc-toolset-11}"

# BuildKit：支持 ARG 在 USER 指令中展开、并行构建、更好的缓存
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"
export COMPOSE_DOCKER_CLI_BUILD="${COMPOSE_DOCKER_CLI_BUILD:-1}"

log() { printf '\n\033[1;36m[build.sh]\033[0m %s\n' "$*"; }

# 选择 docker compose 命令（v2 插件 / v1 独立二进制）
if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    echo "错误：未找到 docker compose（v1 或 v2）。请先安装 Docker。" >&2
    exit 1
fi

log "Docker 版本: $(docker --version)"
log "Compose    : $("${COMPOSE[@]}" version --short 2>/dev/null || echo 'unknown')"
log "构建目标   : $TARGET"
log "USER_UID/GID: ${USER_UID}/${USER_GID}"
log "GCC_TOOLSET: ${GCC_TOOLSET}"

BUILD_ARGS=()
if [[ "${NO_CACHE:-0}" == "1" ]]; then
    BUILD_ARGS+=(--no-cache)
    log "NO_CACHE=1 → 全量重建"
fi

case "$TARGET" in
    modern|legacy)
        log "开始构建 $TARGET ..."
        "${COMPOSE[@]}" -f docker-compose.yml build "${BUILD_ARGS[@]}" "$TARGET"
        ;;
    all|"")
        log "开始构建两条线（可并行，取决于机器资源）..."
        "${COMPOSE[@]}" -f docker-compose.yml build "${BUILD_ARGS[@]}"
        ;;
    *)
        echo "用法: $0 [modern|legacy|all]" >&2
        exit 1
        ;;
esac

log "构建完成。镜像列表："
docker images --filter 'reference=qt-build:*' --format '  {{.Repository}}:{{.Tag}}\t{{.Size}}\t(created {{.CreatedSince}})'

cat <<'EOF'

下一步：
  ./run.sh modern      # 进入现代线容器（Ubuntu 22.04）
  ./run.sh legacy      # 进入老系统线容器（AlmaLinux 8）

容器内的完整编译步骤见 docker/README.md。
EOF