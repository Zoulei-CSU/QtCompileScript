#!/usr/bin/env bash
# =============================================================================
# build-qt.sh —— Linux / macOS 上 configure + build + install Qt
#
# 输入环境变量：
#   QT_SRC_DIR       源码根目录（解包后的 qt-everywhere-src-X.Y.Z）
#   QT_BUILD_DIR     构建目录
#   QT_PREFIX        安装前缀
#   QT_MAJOR         5 | 6
#   QT_CONFIGURE_ARGS  configure 参数串（由 gen-configure-args.sh 生成）
#   QT_JOBS          并行度（默认按 CPU/内存自动推算）
#   QT_USE_CCACHE    true | false
#   QT_SOURCE_PACKAGE qtbase | qt-everywhere
# =============================================================================
set -euo pipefail

QT_SRC_DIR="${QT_SRC_DIR:?QT_SRC_DIR 未设置}"
QT_BUILD_DIR="${QT_BUILD_DIR:-$PWD/build}"
QT_CONFIGURE_ARGS="${QT_CONFIGURE_ARGS:-}"
QT_MAJOR="${QT_MAJOR:-5}"
QT_PREFIX="${QT_PREFIX:-/opt/Qt}"
QT_USE_CCACHE="${QT_USE_CCACHE:-true}"
QT_SOURCE_PACKAGE="${QT_SOURCE_PACKAGE:-qtbase}"
QT_PLATFORM="${QT_PLATFORM:-}"
QT_LINUX_FLAVOR="${QT_LINUX_FLAVOR:-}"
QT_ENABLE_WAYLAND="${QT_ENABLE_WAYLAND:-}"

log() { printf '\n\033[1;34m[build-qt]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[build-qt][警告]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 并行度推算：min(CPU 核心数, 可用内存GB / 2)
# Qt 单文件编译在 4GB 内存/任务左右，保守取 2GB/任务
# ---------------------------------------------------------------------------
if [[ -z "${QT_JOBS:-}" ]]; then
    NCPU=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    if [[ "$(uname -s)" == "Darwin" ]]; then
        MEM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    else
        MEM_GB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 / 1024 ))
    fi
    MEM_LIMIT=$(( MEM_GB / 2 ))
    (( MEM_LIMIT < 1 )) && MEM_LIMIT=1
    QT_JOBS=$(( NCPU < MEM_LIMIT ? NCPU : MEM_LIMIT ))
    log "自动推算并行度: CPU=${NCPU} 核, 内存=${MEM_GB} GB -> make -j${QT_JOBS}"
else
    log "使用指定并行度: make -j${QT_JOBS}"
fi

# ---------------------------------------------------------------------------
# ccache 配置
# ---------------------------------------------------------------------------
if [[ "${QT_USE_CCACHE,,}" == "true" ]]; then
    if command -v ccache >/dev/null 2>&1; then
        export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
        export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"
        export CCACHE_COMPRESS=1
        export CCACHE_COMPRESSLEVEL=6
        export CCACHE_SLOPPINESS=time_macros,include_file_ctime,include_file_mtime
        mkdir -p "$CCACHE_DIR"
        # 关键：把编译器指向 ccache 包装
        CC_COMPILER=$(command -v gcc || command -v clang || true)
        CXX_COMPILER=$(command -v g++ || command -v clang++ || true)
        if [[ -n "$CC_COMPILER" && -n "$CXX_COMPILER" ]]; then
            ln -sf "$(command -v ccache)" "$(dirname "$CC_COMPILER")/ccache-gcc" 2>/dev/null || true
            export CC="ccache $CC_COMPILER"
            export CXX="ccache $CXX_COMPILER"
            log "ccache 已启用: $CCACHE_DIR (max=${CCACHE_MAXSIZE})"
        fi
        ccache --show-stats || true
    else
        warn "指定启用 ccache 但未找到 ccache 命令，已跳过"
    fi
fi

# ---------------------------------------------------------------------------
# 准备构建目录
# ---------------------------------------------------------------------------
log "源码目录: $QT_SRC_DIR"
log "构建目录: $QT_BUILD_DIR"
log "安装前缀: $QT_PREFIX"
log "源码包粒度: $QT_SOURCE_PACKAGE"

if [[ ! -d "$QT_SRC_DIR" ]]; then
    echo "错误: 源码目录不存在: $QT_SRC_DIR" >&2
    exit 1
fi

# qtbase 单独包时，configure 在 qtbase/ 子目录；everywhere 在根目录
# 定位 configure 脚本所在目录：
#   - qtbase-everywhere-src-* 包：根目录就是 qtbase，configure 在根
#   - qt-everywhere-src-* 包：根目录有顶层 configure；若要只编 qtbase 则进 qtbase/ 子目录
if [[ -x "$QT_SRC_DIR/configure" || -f "$QT_SRC_DIR/configure.bat" ]]; then
    CONFIGURE_DIR="$QT_SRC_DIR"
elif [[ -d "$QT_SRC_DIR/qtbase" && ( -x "$QT_SRC_DIR/qtbase/configure" || -f "$QT_SRC_DIR/qtbase/configure.bat" ) ]]; then
    CONFIGURE_DIR="$QT_SRC_DIR/qtbase"
    if [[ "$QT_SOURCE_PACKAGE" == "qtbase" ]]; then
        log "仅编译 qtbase 子目录: $CONFIGURE_DIR"
    fi
else
    warn "未在 $QT_SRC_DIR 中找到 configure，尝试直接用 cmake 构建"
    CONFIGURE_DIR="$QT_SRC_DIR"
fi

mkdir -p "$QT_BUILD_DIR"
cd "$QT_BUILD_DIR"

# ---------------------------------------------------------------------------
# Configure
# ---------------------------------------------------------------------------
log "开始 configure ..."
START_TS=$(date +%s)

# shellcheck disable=SC2086
if [[ -x "$CONFIGURE_DIR/configure" ]]; then
    "$CONFIGURE_DIR/configure" $QT_CONFIGURE_ARGS 2>&1 | tee configure.log
else
    # Qt6 也可能没有顶层 configure，直接 cmake
    warn "未找到 configure 脚本，改用 cmake 直接配置"
    cmake -S "$CONFIGURE_DIR" -B "$QT_BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$QT_PREFIX" \
        -DQT_BUILD_TESTS=OFF -DQT_BUILD_EXAMPLES=OFF \
        $QT_CONFIGURE_ARGS 2>&1 | tee configure.log
fi

CONFIGURE_SEC=$(( $(date +%s) - START_TS ))
log "configure 完成，耗时 ${CONFIGURE_SEC}s"

# ---------------------------------------------------------------------------
# 校验 config.summary：确认 Linux 硬需求项确实被启用
#   硬需求（Linux）：OpenSSL / PostgreSQL(libpq) / Fontconfig / libpng / xcb
#   新系统线还需 Wayland。校验失败只告警，不中断（避免因措辞差异误判失败，
#   真正的失败会在编译或运行期暴露；这里给出显式的"未满足"提示便于排查）。
# ---------------------------------------------------------------------------
SUMMARY_FILE=""
for cand in "$QT_BUILD_DIR/config.summary" \
            "$CONFIGURE_DIR/config.summary" \
            "$QT_BUILD_DIR/config.opt" \
            "$CONFIGURE_DIR/config.opt"; do
    if [[ -f "$cand" ]]; then
        SUMMARY_FILE="$cand"
        break
    fi
done

if [[ -n "$SUMMARY_FILE" ]]; then
    log "校验 config.summary: $SUMMARY_FILE"
    cp -f "$SUMMARY_FILE" "$QT_PREFIX/../config.summary" 2>/dev/null || true

    _check_yes() {
        local label="$1" pattern="$2" required="${3:-true}"
        # 在该行里找 yes / enabled / 存在
        if grep -iE "$pattern" "$SUMMARY_FILE" | grep -qiE '(yes|enabled|true|\buse\b)'; then
            log "  [OK]   $label"
            return 0
        fi
        if [[ "$required" == "true" ]]; then
            warn "  [缺失] $label —— 未在 config.summary 中检测到启用状态！"
            VALIDATION_FAILED="${VALIDATION_FAILED:-} $label"
        else
            log "  [略]   $label（可选项，未启用）"
        fi
        return 1
    }

    if [[ "$QT_PLATFORM" == linux-* || -n "$QT_LINUX_FLAVOR" ]]; then
        # OpenSSL
        _check_yes "OpenSSL" "OpenSSL" || true
        # PostgreSQL / libpq
        _check_yes "PostgreSQL (libpq)" "PostgreSQL|psql" || true
        # Fontconfig
        _check_yes "Fontconfig" "Fontconfig" || true
        # libpng（可能是 system 或 bundled，二者其一即可）
        if grep -iE 'libpng|PNG' "$SUMMARY_FILE" | grep -qiE '(yes|enabled|bundled|system|qt)'; then
            log "  [OK]   libpng"
        else
            warn "  [缺失] libpng —— 未检测到 PNG 支持！"
            VALIDATION_FAILED="${VALIDATION_FAILED:-} libpng"
        fi
        # xcb
        _check_yes "xcb" "xcb" || true
        # Wayland（modern 线才要求）
        if [[ "${QT_ENABLE_WAYLAND:-}" == "true" ]]; then
            _check_yes "Wayland" "Wayland" || true
        fi
    fi

    if [[ -n "${VALIDATION_FAILED:-}" ]]; then
        warn "以下硬需求在 config.summary 中未确认启用:${VALIDATION_FAILED}"
        warn "请检查对应开发包是否安装（openssl-devel / libpq-devel / fontconfig-devel / libpng-devel / libxcb / libwayland）"
    else
        log "config.summary 校验通过：Linux 硬需求均已启用"
    fi
else
    warn "未找到 config.summary，跳过硬需求校验"
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
log "开始编译 (make -j${QT_JOBS}) ..."
START_TS=$(date +%s)

MAKE_CMD="make"
command -v gmake >/dev/null 2>&1 && MAKE_CMD="gmake"
# macOS 上 xcode 的 make 也能用

"$MAKE_CMD" -j"${QT_JOBS}" 2>&1 | tee build.log
BUILD_SEC=$(( $(date +%s) - START_TS ))
log "编译完成，耗时 $(( BUILD_SEC / 60 )) 分钟"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
log "开始安装到 $QT_PREFIX ..."
START_TS=$(date +%s)
"$MAKE_CMD" install 2>&1 | tee install.log
INSTALL_SEC=$(( $(date +%s) - START_TS ))
log "安装完成，耗时 ${INSTALL_SEC}s"

# ---------------------------------------------------------------------------
# ccache 统计
# ---------------------------------------------------------------------------
if [[ "${QT_USE_CCACHE,,}" == "true" ]] && command -v ccache >/dev/null 2>&1; then
    log "ccache 统计:"
    ccache --show-stats || true
fi

# ---------------------------------------------------------------------------
# 结果摘要
# ---------------------------------------------------------------------------
log "================ 构建摘要 ================"
log "  configure : ${CONFIGURE_SEC}s"
log "  build     : ${BUILD_SEC}s"
log "  install   : ${INSTALL_SEC}s"
log "  安装体积  : $(du -sh "$QT_PREFIX" 2>/dev/null | cut -f1 || echo 'n/a')"
log "=========================================="

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "build_seconds=$BUILD_SEC"
        echo "configure_seconds=$CONFIGURE_SEC"
        echo "install_seconds=$INSTALL_SEC"
    } >> "$GITHUB_OUTPUT"
fi