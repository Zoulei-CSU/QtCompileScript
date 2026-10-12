#!/usr/bin/env bash
# =============================================================================
# package-qt.sh —— 精简安装树 + 打包 + 生成校验文件 (Linux / macOS)
#
# 输入环境变量：
#   QT_PREFIX        安装前缀
#   QT_VERSION       版本号
#   QT_PLATFORM      平台标识
#   QT_BUILD_TYPE    构建类型
#   QT_SOURCE_PACKAGE qtbase | qt-everywhere
#   QT_PACK_MODE     dev-lite（剔除 doc/examples 源码）| dev-full（原样打包）
#                    兼容旧值：runtime-only = dev-lite；full = dev-full
#   QT_OUTPUT_DIR    产物输出目录（默认 $PWD/dist）
#   QT_ARTIFACT_NAME 产物基名（不含扩展名）
#   QT_CONFIGURE_ARGS / QT_BUILD_SECONDS  用于写入 BUILD-INFO.txt
# =============================================================================
set -euo pipefail

QT_PREFIX="${QT_PREFIX:?QT_PREFIX 未设置}"
QT_VERSION="${QT_VERSION:-unknown}"
QT_PLATFORM="${QT_PLATFORM:-unknown}"
QT_BUILD_TYPE="${QT_BUILD_TYPE:-release}"
QT_SOURCE_PACKAGE="${QT_SOURCE_PACKAGE:-qtbase}"
QT_PACK_MODE="${QT_PACK_MODE:-dev-lite}"
QT_OUTPUT_DIR="${QT_OUTPUT_DIR:-$PWD/dist}"
QT_ARTIFACT_NAME="${QT_ARTIFACT_NAME:-Qt-${QT_VERSION}-${QT_PLATFORM}-${QT_BUILD_TYPE}}"

log() { printf '\n\033[1;34m[package-qt]\033[0m %s\n' "$*"; }

mkdir -p "$QT_OUTPUT_DIR"

# ---------------------------------------------------------------------------
# 瘦身（可选）：这是【开发包】，必须保留 include/.prl/.cmake/mkspecs 等开发文件，
#   仅剔除"体积巨大且与开发无关"的纯文档与示例源码。
#
#   两种模式：
#     dev-lite  （默认）: 剔除 doc/ 与 examples/demos 源码，保留所有开发/运行文件
#     dev-full          : 保留全部文件，原样打包（含文档与示例）
#
#   无论哪种模式，以下都【绝不删除】：
#     include/           头文件（开发必需）
#     *.prl *.la         qmake 项目文件
#     lib/cmake/**       CMake 配置（find_package(Qt6) 依赖）
#     mkspecs/           平台规格
#     lib/*.so bin/ plugins/ qml/
# ---------------------------------------------------------------------------
case "$QT_PACK_MODE" in
    runtime-only|dev-lite|lite)
        log "瘦身模式(dev-lite)：仅剔除 doc/ 与 examples/demos 源码，保留全部开发文件"

        # Qt 自带的 HTML 文档（数百 MB，纯查阅用途，可在线查）
        # 只删顶层 doc/ 与 qdoc 生成目录，不动 include 下的任何东西
        find "$QT_PREFIX" -maxdepth 3 -type d -name "doc" -exec rm -rf {} + 2>/dev/null || true

        # 示例 / 演示 的源码目录（注意：只删目录名精确匹配的）
        find "$QT_PREFIX" -maxdepth 3 -type d \( -name "examples" -o -name "demos" \) \
            -exec rm -rf {} + 2>/dev/null || true

        # 编译中间产物（若安装树里意外混入）
        find "$QT_PREFIX" -type f \( -name "*.o" -o -name "*.obj" \) -delete 2>/dev/null || true

        log "瘦身后体积: $(du -sh "$QT_PREFIX" | cut -f1)"
        ;;
    full|dev-full)
        log "完整模式(dev-full)：保留全部文件（含文档与示例）"
        ;;
    *)
        log "警告: 未知 pack_mode '$QT_PACK_MODE'，按完整模式处理"
        ;;
esac

# ---------------------------------------------------------------------------
# 安全校验：确保开发必需文件没有被误删（缺失则直接报错，避免打出废包）
# ---------------------------------------------------------------------------
if [[ ! -d "$QT_PREFIX/include" ]]; then
    printf '\n\033[1;31m[package-qt][致命]\033[0m include/ 目录缺失！产物将无法用于开发编译。\n'
    printf '\033[1;31m  请检查是否有步骤误删头文件。\033[0m\n'
    exit 1
fi
log "开发文件校验通过：include/ 存在"

# ---------------------------------------------------------------------------
# 清理符号表（Linux，仅动态库 .so）
#   注意：--strip-unneeded 对 .so 安全（不影响链接与运行）；
#         绝不对 .a 静态库或 .o 目标文件 strip（会破坏链接）。
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" == "Linux" ]] && command -v strip >/dev/null 2>&1; then
    log "剥离动态库符号表（strip --strip-unneeded，仅 .so）..."
    STRIPPED=0
    # 用 find -exec 避免进程替换在部分环境下失效
    find "$QT_PREFIX" -type f \( -name "*.so" -o -name "*.so.*" \) -print0 2>/dev/null \
        | while IFS= read -r -d '' f; do
            if file "$f" 2>/dev/null | grep -q "ELF.*shared object"; then
                if strip --strip-unneeded "$f" 2>/dev/null; then
                    echo "$f"
                fi
            fi
        done > /tmp/stripped-list.txt 2>/dev/null || true
    STRIPPED=$(wc -l < /tmp/stripped-list.txt 2>/dev/null || echo 0)
    log "已剥离 ${STRIPPED} 个文件"
fi

# ---------------------------------------------------------------------------
# 生成 BUILD-INFO.txt
# ---------------------------------------------------------------------------
BUILD_INFO="$QT_OUTPUT_DIR/BUILD-INFO.txt"
{
    echo "===== Qt 编译信息 / BUILD INFO ====="
    echo "版本      : $QT_VERSION"
    echo "平台      : $QT_PLATFORM"
    echo "构建类型  : $QT_BUILD_TYPE"
    echo "源码粒度  : $QT_SOURCE_PACKAGE"
    echo "打包模式  : $QT_PACK_MODE"
    echo "构建时间  : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "Runner    : ${RUNNER_OS:-?} / ${RUNNER_ARCH:-?} / ${RUNNER_NAME:-?}"
    echo "Commit    : ${GITHUB_SHA:-local}"
    echo "RunID     : ${GITHUB_RUN_ID:-local} #${GITHUB_RUN_NUMBER:-0}"
    echo "编译耗时  : ${QT_BUILD_SECONDS:-n/a} 秒"
    echo ""
    echo "---- configure 参数 ----"
    echo "${QT_CONFIGURE_ARGS:-n/a}"
    echo ""
    echo "---- 硬件环境 ----"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "CPU       : $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo '?')"
        echo "核心数    : $(sysctl -n hw.ncpu 2>/dev/null || echo '?')"
        echo "内存      : $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024/1024/1024 )) GB"
    else
        echo "CPU       : $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //' || echo '?')"
        echo "核心数    : $(nproc 2>/dev/null || echo '?')"
        echo "内存      : $(awk '/MemTotal/{printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo '?')"
    fi
} > "$BUILD_INFO"

# ---------------------------------------------------------------------------
# 打包：Linux 用 tar.xz（高压缩比，产物更小）；macOS 用 tar.gz（兼容性优先）
#   可用 QT_ARCHIVE_FORMAT=tar.xz|tar.gz 强制指定，否则按平台自动选择。
# ---------------------------------------------------------------------------
if [[ -n "${QT_ARCHIVE_FORMAT:-}" ]]; then
    ARCHIVE_EXT="$(echo "$QT_ARCHIVE_FORMAT" | sed 's/^tar//; s/^\.//')"
else
    case "$(uname -s)" in
        Linux)  ARCHIVE_EXT="xz" ;;
        Darwin) ARCHIVE_EXT="gz" ;;
        *)      ARCHIVE_EXT="gz" ;;
    esac
fi
ARCHIVE="$QT_OUTPUT_DIR/${QT_ARTIFACT_NAME}.tar.${ARCHIVE_EXT}"
log "打包 -> $(basename "$ARCHIVE")（格式：tar.${ARCHIVE_EXT}）"

# 以安装前缀的父目录为根，保留一层顶层目录名
PREFIX_PARENT="$(dirname "$QT_PREFIX")"
PREFIX_BASE="$(basename "$QT_PREFIX")"

if [[ "$ARCHIVE_EXT" == "xz" ]]; then
    # 只排除编译中间产物 .o（正常情况下安装树里不该有）；
    # 其余全部保留（include/.prl/.cmake/mkspecs/*.so 等开发运行文件）
    tar -cJf "$ARCHIVE" --exclude="*.o" \
        -C "$PREFIX_PARENT" "$PREFIX_BASE" 2>/dev/null \
        || tar -cJf "$ARCHIVE" --exclude="*.o" \
            -C "$PREFIX_PARENT" "$PREFIX_BASE"
else
    tar -czf "$ARCHIVE" --exclude="*.o" \
        -C "$PREFIX_PARENT" "$PREFIX_BASE"
fi

ARC_SIZE=$(du -h "$ARCHIVE" | cut -f1)
log "打包完成: $ARCHIVE ($ARC_SIZE)"

if [[ "$(uname -s)" == "Linux" ]]; then
    MAX_BYTES=$((2 * 1024 * 1024 * 1024 - 1024 * 1024))
    ARC_BYTES=$(stat -c%s "$ARCHIVE")
elif [[ "$(uname -s)" == "Darwin" ]]; then
    MAX_BYTES=$((2 * 1024 * 1024 * 1024 - 1024 * 1024))
    ARC_BYTES=$(stat -f%z "$ARCHIVE")
else
    MAX_BYTES=0; ARC_BYTES=0
fi

if (( MAX_BYTES > 0 && ARC_BYTES > MAX_BYTES )); then
    printf '\n\033[1;31m[package-qt][严重警告]\033[0m 产物 %s 超过 GitHub Release 单资产 2GB 上限！\n' "$ARC_SIZE"
    printf '\033[1;31m  建议：改用 pack_mode=dev-lite，或手动 split 分卷后再上传。\033[0m\n'
fi

# ---------------------------------------------------------------------------
# SHA256 校验
# ---------------------------------------------------------------------------
log "生成 SHA256 校验文件"
( cd "$QT_OUTPUT_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256" 2>/dev/null \
    || shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256" )

log "产物目录内容:"
ls -lh "$QT_OUTPUT_DIR"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "archive=$ARCHIVE"
        echo "archive_name=$(basename "$ARCHIVE")"
        echo "artifact_name=${QT_ARTIFACT_NAME}"
        echo "archive_ext=tar.${ARCHIVE_EXT}"
    } >> "$GITHUB_OUTPUT"
fi