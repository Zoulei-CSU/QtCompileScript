#!/usr/bin/env bash
# =============================================================================
# gen-configure-args.sh —— 根据工作流输入生成 Qt configure 参数串
#
# 设计原则：
#   1. 所有输入通过环境变量传入（QTS_ 前缀），便于在 Actions 和本地复用。
#   2. Qt5 与 Qt6 的 configure 语义不同 -> 走不同分支（Qt6 用 CMake 风格参数）。
#   3. 默认忽略重型模块（qtdoc/qt3d/qtwebengine/qtwebview）。
#   4. 输出：把参数串写入 $GITHUB_OUTPUT（CI）或 stdout（本地）。
#
# 输入环境变量：
#   QT_MAJOR            5 | 6
#   QT_VERSION          例如 5.15.17 / 6.8.3
#   QT_PLATFORM         例如 linux-gcc / linux-clang / linux-centos7-* / macos-clang
#   QT_BUILD_TYPE       release | debug | debug-and-release (Qt5) / Release|Debug|RelWithDebInfo (Qt6)
#   QT_ARCH             x86_64 | arm64
#   QT_STATIC           true | false
#   QT_SKIP_MODULES     逗号分隔，例如 qtdoc,qt3d,qtwebengine,qtwebview
#   QT_EXTRA_ARGS       追加的原始 configure 参数
#   QT_PREFIX           安装前缀
#   QT_OPENSSL_LINKED   true | false（是否 -openssl-linked）
#   QT_SQL_DRIVERS      逗号分隔，例如 psql,oci（可选）
#   QT_THIRDPARTY_INCDIR / LIBDIR  三方库根目录（可选，Windows 常用）
#   QT_LINUX_FLAVOR     legacy | modern（Linux 专用，决定 wayland/png/依赖策略）
#   QT_ENABLE_WAYLAND   true | false（Linux modern 线启用 Wayland）
#   QT_USE_SYSTEM_PNG   true | false（true=系统 libpng；false=内置 -qt-libpng）
#
# ---------------------------------------------------------------------------
# 【Qt5 / Qt6 选项差异速查】—— 每一项都会导致 configure 直接 FATAL_ERROR，务必遵守
# ---------------------------------------------------------------------------
# 仅 Qt5 有（Qt6 传了会报 "Unknown command line option"）：
#     -no-compile-examples   -verbose   -mp   -platform <mkspec>
#     -opengl dynamic        -gui       -widgets      -no-angle（Qt6 无 angle）
# 仅 Qt6 有 / 语义不同：
#     -feature-wayland / -no-feature-wayland   （Qt5 的 wayland 是独立模块 qtwayland，
#                                                靠"不 skip qtwayland"来启用）
# 两个版本都有的：-opensource -confirm-license -prefix -release -debug -shared -static
#     -nomake -ltcg -icu/-no-icu -opengl <api> -xcb -xcb-xlib -libpng[qt|system]
#     -iconv(Qt5) -sql-<driver> -openssl-linked -skip(仅顶层构建)
# ⚠️ `-D<str>` 在 Qt 里是"预处理器宏定义"，不是 CMake 变量！
#     想透传 CMake 变量必须写成 `<选项...> -- -DCMAKE_XXX=yyy`（见下方 CM_PT）。
#     例：Qt6 macOS 的 -DCMAKE_OSX_ARCHITECTURES 必须放在 `--` 之后。
# ⚠️ `-skip` / `-no-qml-debug` 只在 qt-everywhere 顶层构建生效，qtbase 单模块下会报警告
#     （`-skip`）或直接报未知选项（`-no-qml-debug` 属 qtdeclarative），故按源码粒度门控。
# =============================================================================
set -euo pipefail

QT_MAJOR="${QT_MAJOR:?QT_MAJOR 未设置}"
QT_VERSION="${QT_VERSION:?QT_VERSION 未设置}"
QT_PLATFORM="${QT_PLATFORM:-linux-gcc}"
QT_BUILD_TYPE="${QT_BUILD_TYPE:-release}"
QT_ARCH="${QT_ARCH:-x86_64}"
QT_STATIC="${QT_STATIC:-false}"
QT_SOURCE_PACKAGE="${QT_SOURCE_PACKAGE:-qtbase}"
QT_SKIP_MODULES="${QT_SKIP_MODULES:-qtdoc,qt3d,qtwebengine,qtwebview}"
QT_EXTRA_ARGS="${QT_EXTRA_ARGS:-}"
QT_PREFIX="${QT_PREFIX:-/opt/Qt/${QT_VERSION}}"
QT_OPENSSL_LINKED="${QT_OPENSSL_LINKED:-true}"
QT_SQL_DRIVERS="${QT_SQL_DRIVERS:-}"
QT_THIRDPARTY_INCDIR="${QT_THIRDPARTY_INCDIR:-}"
QT_THIRDPARTY_LIBDIR="${QT_THIRDPARTY_LIBDIR:-}"
QT_LINUX_FLAVOR="${QT_LINUX_FLAVOR:-}"
QT_ENABLE_WAYLAND="${QT_ENABLE_WAYLAND:-}"
QT_USE_SYSTEM_PNG="${QT_USE_SYSTEM_PNG:-}"

log() { printf '[gen-configure-args] %s\n' "$*" >&2; }

ARGS=()
# 需要透传给 CMake 的变量（-Dxxx=yyy）
#   Qt6 会以 `-- -Dxxx=yyy` 形式追加到末尾；
#   注意：Qt 的 `-D<str>` 语义是"预处理器宏定义"，直接写 -Dxxx=yyy 会被当成宏，
#   必须放在 `--` 之后才会作为 CMake 变量透传。
CM_PT=()

# ---------------------------------------------------------------------------
# 通用：许可证与基础开关（Qt5 / Qt6 都需要）
# ---------------------------------------------------------------------------
ARGS+=(-opensource -confirm-license -prefix "$QT_PREFIX")

# ---------------------------------------------------------------------------
# 构建类型
#    Qt5 使用 -release / -debug / -debug-and-release
#    Qt6 使用 -release / -debug（Qt6 已取消 debug-and-release 组合）
# ---------------------------------------------------------------------------
case "${QT_BUILD_TYPE,,}" in
    release)
        ARGS+=(-release)
        ;;
    debug)
        ARGS+=(-debug)
        ;;
    debug-and-release|debug_and_release)
        if [[ "$QT_MAJOR" == "5" ]]; then
            ARGS+=(-debug-and-release)
        else
            log "警告: Qt6 不支持 debug-and-release，已回退为 -release"
            ARGS+=(-release)
        fi
        ;;
    *)
        log "警告: 未知 build_type '$QT_BUILD_TYPE'，回退 -release"
        ARGS+=(-release)
        ;;
esac

# ---------------------------------------------------------------------------
# 静态 / 动态库
# ---------------------------------------------------------------------------
if [[ "${QT_STATIC,,}" == "true" ]]; then
    ARGS+=(-static)
    if [[ "$QT_MAJOR" == "6" ]]; then
        # Qt6 静态构建需要显式指定静态运行时（Windows/MSVC 场景）
        ARGS+=(-static-runtime)
    fi
else
    ARGS+=(-shared)
fi

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 跳过模块
#   基础列表由 QT_SKIP_MODULES 传入（默认 qtdoc/qt3d/qtwebengine/qtwebview）。
#   额外规则：
#     - legacy 线（Qt5，无 wayland）：追加跳过 qtwayland
#     - modern 线：确保 qtwayland 不被跳过（Wayland 支持必需）
#     - Qt6：确保 qt5compat 不被跳过（GBK/GB18030 中文编码依赖它）
# ---------------------------------------------------------------------------
_skips_raw="$QT_SKIP_MODULES"

_has_module() { case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac }
_add_skip() { _skips_raw="${_skips_raw:+${_skips_raw},}$1"; }
_del_skip() {
    local out="" m
    IFS=',' read -r -a _arr <<< "$_skips_raw"
    for m in "${_arr[@]}"; do
        m="$(echo "$m" | xargs)"
        [[ -z "$m" || "$m" == "$1" ]] && continue
        out="${out:+${out},}$m"
    done
    _skips_raw="$out"
}

if [[ "$QT_PLATFORM" == linux-centos7-* || "$QT_PLATFORM" == linux-legacy* ]]; then
    # legacy：Qt5 靠跳过 qtwayland 关闭 wayland
    if [[ "$QT_MAJOR" == "5" ]] && ! _has_module "$_skips_raw" qtwayland; then
        _add_skip qtwayland
        log "legacy 线: 追加 -skip qtwayland（关闭 Wayland）"
    fi
elif [[ "$QT_PLATFORM" == linux-* ]]; then
    # modern：不允许跳过 qtwayland
    if _has_module "$_skips_raw" qtwayland; then
        _del_skip qtwayland
        log "modern 线: 已从 skip 列表移除 qtwayland（Wayland 必需）"
    fi
fi

# Qt6 必须保留 qt5compat（GBK/GB18030 中文编码）
if [[ "$QT_MAJOR" == "6" ]] && _has_module "$_skips_raw" qt5compat; then
    _del_skip qt5compat
    log "Qt6: 已从 skip 列表移除 qt5compat（中文 GBK 编码必需）"
fi

if [[ -n "$_skips_raw" ]]; then
    # -skip 只在顶层构建（qt-everywhere）生效；
    # 单模块源码（qtbase）下传 -skip 只会产生 "only effective in top-level builds" 警告。
    if [[ "$QT_SOURCE_PACKAGE" == "qt-everywhere" ]]; then
        IFS=',' read -r -a _skips <<< "$_skips_raw"
        for m in "${_skips[@]}"; do
            m="$(echo "$m" | xargs)"   # trim
            [[ -n "$m" ]] && ARGS+=(-skip "$m")
        done
    else
        log "非顶层构建（$QT_SOURCE_PACKAGE）：忽略 -skip 列表（该选项仅在 qt-everywhere 顶层生效）"
    fi
fi

# ---------------------------------------------------------------------------
# 减少无用产物
#   -nomake tests/examples : Qt5 / Qt6 均支持
#   -no-compile-examples   : Qt5 独有；Qt6 configure 会报 "Unknown command line option"
# ---------------------------------------------------------------------------
ARGS+=(-nomake tests -nomake examples)
if [[ "$QT_MAJOR" == "5" ]]; then
    ARGS+=(-no-compile-examples)
fi

# ---------------------------------------------------------------------------
# 平台相关
# ---------------------------------------------------------------------------
case "$QT_PLATFORM" in
    linux-centos7-*|linux-legacy*)
        # -------------------------------------------------------------------
        # 老系统线（CentOS7 / glibc 2.17）
        #   固定策略：不开 wayland、用内置 png、iconv、fontconfig、openssl、libpq
        # -------------------------------------------------------------------
        log "Linux 老系统线（legacy / glibc 2.17）"

        # 老系统默认用源码内置 libpng（系统 png 版本过低）
        if [[ "${QT_USE_SYSTEM_PNG,,}" == "true" ]]; then
            log "警告: legacy 线不建议使用系统 libpng，已强制改为内置 -qt-libpng"
        fi
        ARGS+=(-qt-libpng)

        # 显式关闭 Wayland（CentOS7 无 libwayland-devel；老系统不跑 Wayland 会话）
        if [[ "$QT_MAJOR" == "6" ]]; then
            ARGS+=(-no-feature-wayland)
        fi
        # Qt5 的 wayland 是独立模块，通过 -skip qtwayland 关闭
        # 由 skip 列表统一控制（legacy 线的 skip 列表须含 qtwayland）

        # iconv：Qt5 显式启用；Qt6 已内置无开关
        if [[ "$QT_MAJOR" == "5" ]]; then
            ARGS+=(-iconv -no-icu)
        else
            ARGS+=(-no-icu)
        fi

        if [[ "$QT_MAJOR" == "5" ]]; then
            ARGS+=(-xcb -xcb-xlib -opengl desktop -no-angle -ltcg)
        else
            ARGS+=(-opengl desktop)
        fi
        ;;

    linux-gcc|linux-clang|linux-modern*)
        # -------------------------------------------------------------------
        # 新系统线（Ubuntu 22.04+ / glibc 2.35+）
        #   wayland 开启、系统 libpng、iconv、fontconfig、openssl、libpq
        # -------------------------------------------------------------------
        log "Linux 新系统线（modern）"

        # png：默认用系统 libpng；如需内置可传 QT_USE_SYSTEM_PNG=false
        if [[ "${QT_USE_SYSTEM_PNG,,}" == "false" ]]; then
            ARGS+=(-qt-libpng)
        else
            ARGS+=(-system-libpng)
        fi

        # Wayland：新系统默认开启
        if [[ "${QT_ENABLE_WAYLAND,,}" == "false" ]]; then
            log "Wayland 被显式关闭"
            if [[ "$QT_MAJOR" == "6" ]]; then
                ARGS+=(-no-feature-wayland)
            fi
        else
            if [[ "$QT_MAJOR" == "6" ]]; then
                ARGS+=(-feature-wayland)
            fi
            # Qt5 的 wayland 由保留 qtwayland 模块实现（不在此处加参数）
            log "Wayland 已启用（Qt$QT_MAJOR）"
        fi

        # iconv：Qt5 显式启用；Qt6 已内置无开关
        if [[ "$QT_MAJOR" == "5" ]]; then
            ARGS+=(-iconv -no-icu -xcb -xcb-xlib -opengl desktop -no-angle -ltcg)
        else
            ARGS+=(-no-icu -opengl desktop)
        fi
        ;;

    macos-clang|macos-*)
        # macOS 架构
        #   Qt6 走 CMake：CMAKE_OSX_* 需要放在 `--` 之后透传（写入 CM_PT）
        #   Qt5 不走 CMake，且官方明确不支持 arm64/universal 构建，
        #       因此不传 -DCMAKE_OSX_*（否则会被当作预处理器宏定义）；
        #       目标架构由 runner 自身架构决定（macos-13=x86_64 / macos-14=arm64）。
        if [[ "$QT_MAJOR" == "6" ]]; then
            CM_PT+=(-DCMAKE_OSX_ARCHITECTURES="$QT_ARCH")
            if [[ "$QT_ARCH" == "arm64" ]]; then
                CM_PT+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0)
            else
                CM_PT+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=10.15)
            fi
        else
            log "Qt5 macOS：跳过 -DCMAKE_OSX_*（Qt5 不支持该透传，架构随 runner）"
        fi
        # -no-qml-debug 是 qtdeclarative 的选项，仅在 qt-everywhere 顶层构建时可用
        if [[ "$QT_MAJOR" == "5" && "$QT_SOURCE_PACKAGE" == "qt-everywhere" ]]; then
            ARGS+=(-no-qml-debug)
        fi
        ;;
    windows-msvc*|windows-mingw*)
        if [[ "$QT_MAJOR" == "5" ]]; then
            # Qt5：-platform 选 mkspec；-mp 多进程；-opengl dynamic 允许 ANGLE 回退
            ARGS+=(-platform win32-msvc -mp -no-icu)
            ARGS+=(-qt-zlib -qt-freetype -qt-harfbuzz -qt-libpng -qt-libjpeg -qt-sqlite)
            ARGS+=(-opengl dynamic -gui -widgets)
        else
            # Qt6：没有 -mp（并行由 Ninja 处理）、没有 -platform（mkspec 机制已废弃）
            #       架构由 MSVC 开发环境（vcvars x64）决定，无需 CMake 变量透传
            ARGS+=(-no-icu)
            ARGS+=(-qt-zlib -qt-freetype -qt-harfbuzz -qt-libpng -qt-libjpeg -qt-sqlite)
        fi
        ;;
    *)
        log "警告: 未识别的平台 '$QT_PLATFORM'，仅使用通用参数"
        ;;
esac

# ---------------------------------------------------------------------------
# fontconfig（Linux 专用）
#   说明：通常由 configure 自动检测，显式写 -fontconfig 有可能被拒。
#   这里不显式写开关，改为在构建后校验 config.summary 中的 Fontconfig == yes。
#   仅做提示，实际依赖由系统包 libfontconfig-dev 提供。
# ---------------------------------------------------------------------------
if [[ "$QT_PLATFORM" == linux-* ]]; then
    log "fontconfig: 依赖系统包自动启用（构建后将校验 summary）"
fi

# ---------------------------------------------------------------------------
# OpenSSL 链接方式
# ---------------------------------------------------------------------------
if [[ "${QT_OPENSSL_LINKED,,}" == "true" ]]; then
    ARGS+=(-openssl-linked)
else
    ARGS+=(-openssl-runtime)
fi

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# SQL 驱动
#   Linux 线默认必须启用 psql（libpq），这是本项目的硬需求；
#   QT_SQL_DRIVERS 可在此基础上追加 oci 等其它驱动。
# ---------------------------------------------------------------------------
_sql_drivers="$QT_SQL_DRIVERS"
if [[ "$QT_PLATFORM" == linux-* ]]; then
    # 确保 psql 在列表中（去重）
    case ",$_sql_drivers," in
        *,psql,*) : ;;   # 已包含
        *) _sql_drivers="${_sql_drivers:+${_sql_drivers},}psql" ;;
    esac
    log "Linux 线强制启用 SQL 驱动: $_sql_drivers"
fi

if [[ -n "$_sql_drivers" ]]; then
    IFS=',' read -r -a _drv <<< "$_sql_drivers"
    for d in "${_drv[@]}"; do
        d="$(echo "$d" | xargs)"
        [[ -n "$d" ]] && ARGS+=(-sql-"$d")
    done
fi

# ---------------------------------------------------------------------------
# 三方库路径（Windows 上你通过 -I / -L 传入 oci / libpq / openssl）
# ---------------------------------------------------------------------------
if [[ -n "$QT_THIRDPARTY_INCDIR" ]]; then
    IFS=',' read -r -a _inc <<< "$QT_THIRDPARTY_INCDIR"
    for i in "${_inc[@]}"; do
        i="$(echo "$i" | xargs)"
        [[ -n "$i" ]] && ARGS+=(-I"$i")
    done
fi
if [[ -n "$QT_THIRDPARTY_LIBDIR" ]]; then
    IFS=',' read -r -a _lib <<< "$QT_THIRDPARTY_LIBDIR"
    for l in "${_lib[@]}"; do
        l="$(echo "$l" | xargs)"
        [[ -n "$l" ]] && ARGS+=(-L"$l")
    done
fi

# ---------------------------------------------------------------------------
# 用户追加参数（原样附加，注意不要与上面冲突）
# ---------------------------------------------------------------------------
if [[ -n "$QT_EXTRA_ARGS" ]]; then
    # 注意：此处刻意不做 word splitting 之外的解析，允许用户传带引号的串
    # shellcheck disable=SC2206
    _extra=( $QT_EXTRA_ARGS )
    ARGS+=("${_extra[@]}")
fi

# ---------------------------------------------------------------------------
# CMake 变量透传（必须放最后，用 `--` 与 configure 选项分隔）
# ---------------------------------------------------------------------------
if [[ ${#CM_PT[@]} -gt 0 ]]; then
    ARGS+=(--)
    ARGS+=("${CM_PT[@]}")
    log "CMake 透传参数: ${CM_PT[*]}"
fi

# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------
ARGS_STR="${ARGS[*]}"
log "生成的 configure 参数："
log "  $ARGS_STR"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "configure_args=$ARGS_STR"
        echo "prefix=$QT_PREFIX"
    } >> "$GITHUB_OUTPUT"
else
    printf '%s\n' "$ARGS_STR"
fi