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
    log "自动推算并行度: CPU=${NCPU} 核, 内存=${MEM_GB} GB -> -j${QT_JOBS}"
else
    log "使用指定并行度: -j${QT_JOBS}"
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

        # 用「包装脚本目录 + 调整 PATH」的方式接入 ccache，而不是
        #   export CC="ccache gcc"
        # 后者把「带空格的命令串」塞进 CC/CXX，CMake 在某些场景（尤其
        # moc 的 predef 生成 `$CC -dM -E -c ...`）会把它当可执行文件直接
        # exec，导致 ccache 把后续的 `-std=gnu++17` 等参数当成自己的选项：
        #   /usr/bin/ccache: invalid option -- 't'
        # 走 PATH 前缀则 CC/CXX 仍是干净的 /usr/bin/gcc，一切正常。
        CCACHE_BIN_DIR="$QT_BUILD_DIR/.ccache-bin"
        mkdir -p "$CCACHE_BIN_DIR"
        CCACHE_REAL="$(command -v ccache)"
        for _c in gcc g++ cc c++ clang clang++; do
            _p="$(command -v "$_c" 2>/dev/null || true)"
            [[ -n "$_p" ]] && ln -sf "$CCACHE_REAL" "$CCACHE_BIN_DIR/$_c"
        done
        export PATH="$CCACHE_BIN_DIR:$PATH"
        log "ccache 已启用: $CCACHE_DIR (max=${CCACHE_MAXSIZE}), 包装目录=$CCACHE_BIN_DIR"
        log "  gcc -> $(command -v gcc)"
        log "  g++ -> $(command -v g++)"
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
        #   ⚠️ Qt6 的 wayland 是 qtbase 里的 PUBLIC feature，且 **没有** 被
        #   qt_configure_add_summary_entry 登记进 config.summary。config.summary
        #   里出现的 "wayland" 字样属于别的栏目（如 "Qt Wayland" 标题或注释），
        #   并不代表 feature 启用 —— 所以**不能在 configure 后用 summary 判定**，
        #   那样只会产生假警报（实测：grep 命中了 summary 里的 wayland 字样，
        #   随后 _check_yes 找不到 "enabled: yes" 行 → 误报 [缺失]）。
        #   正确判据是「平台插件 libqwayland*.so 是否真的产出」，那是编译后的事，
        #   放到本脚本 install 之后统一核验（见下方 "Wayland 平台插件核验"）。
        if [[ "${QT_ENABLE_WAYLAND:-}" == "true" ]]; then
            log "  [略]   Wayland（不在 config.summary 判定，改由 install 后的"
            log "         plugins/platforms/libqwayland*.so 核验）"
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
#   Qt5 的 configure（qmake 体系）默认生成 Makefile → 用 make/gmake
#   Qt6 的 configure 包装器**强制 -G Ninja** → 生成 build.ninja，
#   此时必须用 ninja，否则报 "No targets specified and no makefile found"。
#   这里不靠大版本判断，直接看构建目录里实际生成了什么，最稳。
# ---------------------------------------------------------------------------
if [[ -f "$QT_BUILD_DIR/build.ninja" ]]; then
    BUILD_TOOL="ninja"
elif [[ -f "$QT_BUILD_DIR/Makefile" ]]; then
    BUILD_TOOL="make"; command -v gmake >/dev/null 2>&1 && BUILD_TOOL="gmake"
else
    warn "构建目录中既无 build.ninja 也无 Makefile，尝试按编译器推测"
    if [[ "$QT_MAJOR" == "6" ]] && command -v ninja >/dev/null 2>&1; then
        BUILD_TOOL="ninja"
    else
        BUILD_TOOL="make"; command -v gmake >/dev/null 2>&1 && BUILD_TOOL="gmake"
    fi
fi

log "开始编译 (${BUILD_TOOL} -j${QT_JOBS}) ..."
START_TS=$(date +%s)

"$BUILD_TOOL" -j"${QT_JOBS}" 2>&1 | tee build.log
BUILD_SEC=$(( $(date +%s) - START_TS ))
log "编译完成，耗时 $(( BUILD_SEC / 60 )) 分钟"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
log "开始安装到 $QT_PREFIX ..."
START_TS=$(date +%s)
"$BUILD_TOOL" install 2>&1 | tee install.log
INSTALL_SEC=$(( $(date +%s) - START_TS ))
log "安装完成，耗时 ${INSTALL_SEC}s"

# ---------------------------------------------------------------------------
# 编译后核验：Wayland 平台插件是否真的产出
#   这是 Wayland feature 的**唯一可靠判据**（config.summary 判定不了，见上）。
#
#   ⚠️ 但要注意**模块归属**：Qt6 里 QPA 平台插件 libqwayland*.so 属于
#   **独立模块 qtwayland**，不在 qtbase 内。因此：
#     - qtbase 单模块构建：本来就不该有 libqwayland*.so，缺失属正常 → 只做提示；
#     - qt-everywhere 全量构建：qtwayland 不能被 skip，缺失才是真问题 → 告警。
#   仅 modern 线（QT_ENABLE_WAYLAND=true）检查；一律不中断构建。
# ---------------------------------------------------------------------------
if [[ "$QT_PLATFORM" == linux-* || -n "${QT_LINUX_FLAVOR:-}" ]]; then
    if [[ "${QT_ENABLE_WAYLAND:-}" == "true" ]]; then
        WL_PLUGINS=$(find "$QT_PREFIX/plugins/platforms" -maxdepth 1 -name 'libqwayland*.so' 2>/dev/null | wc -l)
        # qtwayland 是否在本次构建范围内
        WAYLAND_MODULE_IN_SCOPE="false"
        if [[ "${QT_SOURCE_PACKAGE:-qtbase}" == "qt-everywhere" ]]; then
            if [[ ",${QT_SKIP_MODULES:-}," != *",qtwayland,"* ]]; then
                WAYLAND_MODULE_IN_SCOPE="true"
            fi
        fi

        if [[ "$WL_PLUGINS" -gt 0 ]]; then
            log "Wayland 平台插件核验通过：plugins/platforms/ 下发现 ${WL_PLUGINS} 个 libqwayland*.so"
            find "$QT_PREFIX/plugins/platforms" -maxdepth 1 -name 'libqwayland*.so' 2>/dev/null | sed 's/^/    /'
        elif [[ "$WAYLAND_MODULE_IN_SCOPE" == "true" ]]; then
            warn "Wayland 平台插件核验**未通过**：本次为 qt-everywhere 且未 skip qtwayland，"
            warn "  但 plugins/platforms/ 下没有 libqwayland*.so。"
            warn "  请检查 libwayland-dev / 相关依赖是否装成功，或 qtwayland 是否真的被编出来。"
            warn "  产物仍会继续打包上传。"
        else
            log "  [提示] 本次源码粒度=${QT_SOURCE_PACKAGE:-qtbase}，不含 qtwayland 模块，"
            log "         platforms 插件在 qtbase 内本就不产出 libqwayland*.so（正常）。"
            log "         要获得 Wayland 平台插件请构建 qt-everywhere 且不要 skip qtwayland。"
        fi
    fi
fi

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