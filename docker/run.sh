#!/usr/bin/env bash
# =============================================================================
# run.sh —— 进入 Qt 可编译环境（或在其内执行一条命令）
#
# 用法：
#   ./run.sh                        # 进入现代线容器（交互式 shell）
#   ./run.sh modern                 # 同上，显式指定
#   ./run.sh legacy                 # 进入老系统线容器
#   ./run.sh modern -- make -j8     # 在现代线容器内执行一条命令后退出
#   ./run.sh legacy -- bash -lc 'gcc --version'
#
# 可选环境变量：
#   USER_UID / USER_GID    与构建时保持一致（默认取当前用户）
#   GCC_TOOLSET            老系统线工具链版本
#   CPUS / MEM             限制容器 CPU/内存（例如 CPUS=8 MEM=16g）
#   SHELL_DETACH=1         后台常驻容器（不进入，供 docker exec 复用）
#
# 挂载（与 docker-compose.yml 一致）：
#   <仓库>   → /work/repo   (只读)
#   ./src    → /src         (放源码/解包目录)
#   ./build  → /build       (构建目录)
#   <命名卷> → /opt/qt      (安装前缀，跨次复用)
#   <命名卷> → /ccache      (ccache 缓存)
# =============================================================================
set -euo pipefail

DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOCKER_DIR"

TARGET="modern"
if [[ $# -gt 0 && "$1" != "--" ]]; then
    TARGET="$1"; shift
fi
# 去掉可能的分隔符 --
if [[ $# -gt 0 && "$1" == "--" ]]; then
    shift
fi
CMD=("$@")

case "$TARGET" in
    modern|legacy) ;;
    *)
        echo "用法: $0 [modern|legacy] [-- <命令> ...]" >&2
        exit 1
        ;;
esac

export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"
export GCC_TOOLSET="${GCC_TOOLSET:-gcc-toolset-11}"

if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    echo "错误：未找到 docker compose（v1 或 v2）。" >&2
    exit 1
fi

# 确保挂载目录存在（避免 Docker 自动创建成 root 所有）
mkdir -p src build

IMAGE="qt-build:${TARGET}"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "错误：镜像 $IMAGE 不存在。请先执行 ./build.sh $TARGET" >&2
    exit 1
fi

# 资源限制（可选）
# 注意：bash 4.2/4.3（如 CentOS7 宿主机）在 `set -u` 下展开空数组会报错，
# 这里用「非空才声明」的方式规避，而不是留一个空数组。
HAVE_LIMITS=0
if [[ -n "${CPUS:-}" || -n "${MEM:-}" ]]; then
    HAVE_LIMITS=1
    LIMIT_ARGS=()
    [[ -n "${CPUS:-}" ]] && LIMIT_ARGS+=(--cpus "${CPUS}")
    [[ -n "${MEM:-}"  ]] && LIMIT_ARGS+=(--memory "${MEM}")
fi

REPO_ROOT="$(cd "$DOCKER_DIR/.." && pwd)"

VOL_ARGS=(
    -v "${REPO_ROOT}:/work/repo:ro"
    -v "${DOCKER_DIR}/src:/src"
    -v "${DOCKER_DIR}/build:/build"
    -v "qtinstall-${TARGET}:/opt/qt"
    -v "ccache-${TARGET}:/ccache"
)

ENV_ARGS=(
    -e "QT_FLAVOR=${TARGET}"
    -e "CCACHE_DIR=/ccache"
    -e "CCACHE_MAXSIZE=${CCACHE_MAXSIZE:-5G}"
)
[[ "$TARGET" == "legacy" ]] && ENV_ARGS+=(-e "GCC_TOOLSET=${GCC_TOOLSET}")

# ---- 后台常驻模式：只起容器不进入，之后可 docker exec -it qt-build-<x> bash ----
if [[ "${SHELL_DETACH:-0}" == "1" && ${#CMD[@]} -eq 0 ]]; then
    NAME="qt-build-${TARGET}"
    if docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
        echo "容器 $NAME 已在运行。进入：docker exec -it $NAME bash"
        exit 0
    fi
    echo "启动常驻容器 $NAME ..."
    docker run -d --name "$NAME" \
        ${LIMIT_ARGS[@]+"${LIMIT_ARGS[@]}"} "${VOL_ARGS[@]}" "${ENV_ARGS[@]}" \
        -w /work "$IMAGE" sleep infinity >/dev/null
    echo "已启动。进入：docker exec -it $NAME bash"
    exit 0
fi

# ---- 一次性执行 / 交互式 ----
TTY_ARGS=(-it)
if [[ ! -t 0 || ${#CMD[@]} -gt 0 ]]; then
    # 非终端或带命令时不需要 -t（避免 CI 里报 "the input device is not a TTY"）
    TTY_ARGS=()
    [[ -t 0 ]] && TTY_ARGS=(-i)
fi

# 交互式且无命令时，用镜像默认 CMD（legacy 是 bash -l）；有命令则直接执行。
if [[ ${#CMD[@]} -gt 0 ]]; then
    exec docker run --rm "${TTY_ARGS[@]}" \
        ${LIMIT_ARGS[@]+"${LIMIT_ARGS[@]}"} "${VOL_ARGS[@]}" "${ENV_ARGS[@]}" \
        -w /work "$IMAGE" "${CMD[@]}"
else
    exec docker run --rm "${TTY_ARGS[@]}" \
        ${LIMIT_ARGS[@]+"${LIMIT_ARGS[@]}"} "${VOL_ARGS[@]}" "${ENV_ARGS[@]}" \
        -w /work "$IMAGE"
fi