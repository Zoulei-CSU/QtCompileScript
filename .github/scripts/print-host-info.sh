#!/usr/bin/env bash
# =============================================================================
# print-host-info.sh —— 打印编译机器的硬件资源与软件环境信息
#
# 用途：在编译开始前，把 runner 的 CPU / 内存 / 磁盘 / 编译器版本等信息
#       输出到日志和 BUILD-INFO.txt，便于事后排查性能问题与复现构建。
#
# 用法：bash print-host-info.sh [输出文件路径]（可选，默认只打印到 stdout）
# =============================================================================
set -uo pipefail

OUT_FILE="${1:-}"

hr() { printf '%s\n' "------------------------------------------------------------------------"; }

# 同时输出到 stdout 和（可选的）文件
emit() {
    printf '%s\n' "$*"
    if [[ -n "$OUT_FILE" ]]; then
        printf '%s\n' "$*" >> "$OUT_FILE"
    fi
}

emit "================================================================================"
emit " 编译主机环境信息 / BUILD HOST INFORMATION"
emit " 生成时间 Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
emit "================================================================================"

# -------- 基本信息 --------
hr
emit "[基本] OS / 内核"
emit "  uname        : $(uname -a)"
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    emit "  发行版       : ${PRETTY_NAME:-unknown}"
    emit "  glibc        : $(ldd --version 2>/dev/null | head -n1 || echo 'n/a')"
fi
emit "  CI Runner    : ${RUNNER_OS:-?} / ${RUNNER_ARCH:-?} / ${RUNNER_NAME:-?}"
emit "  GitHub Job   : ${GITHUB_JOB:-?}  (run ${GITHUB_RUN_ID:-?} #${GITHUB_RUN_NUMBER:-?})"

# -------- CPU --------
hr
emit "[硬件] CPU"
if command -v nproc >/dev/null 2>&1; then
    emit "  逻辑核心数   : $(nproc)"
fi
if [[ -r /proc/cpuinfo ]]; then
    emit "  物理核心数   : $(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')"
    emit "  型号         : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
    emit "  CPU 频率     : $(grep -m1 'cpu MHz' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //') MHz"
    emit "  标志(节选)   : $(grep -m1 'flags' /proc/cpuinfo | cut -d: -f2- | tr -s ' ' | cut -c1-160)"
fi

# -------- 内存 --------
hr
emit "[硬件] 内存"
if command -v free >/dev/null 2>&1; then
    free -h | sed 's/^/  /'
    # 用 /proc/meminfo 计算（避免 free 输出被本地化成中文时 awk 匹配失败）
    TOTAL_MEM_MB=$(( $(awk '/^MemTotal:/{print $2}' /proc/meminfo) / 1024 ))
    SUGGEST=$(( TOTAL_MEM_MB / 2048 ))
    (( SUGGEST < 1 )) && SUGGEST=1
    emit "  -> 用于 make -j 的建议值: ${SUGGEST} (约每 2GB 内存 1 个编译任务)"
elif [[ -r /proc/meminfo ]]; then
    grep -E 'MemTotal|MemAvailable|SwapTotal' /proc/meminfo | sed 's/^/  /'
fi

# -------- 磁盘 --------
hr
emit "[硬件] 磁盘"
df -h 2>/dev/null | sed 's/^/  /' | head -n 20

# -------- 编译器 --------
hr
emit "[软件] 编译器 / 构建工具"
emit "  gcc          : $(gcc --version 2>/dev/null | head -n1 || echo '未安装')"
emit "  g++          : $(g++ --version 2>/dev/null | head -n1 || echo '未安装')"
emit "  clang        : $(clang --version 2>/dev/null | head -n1 || echo '未安装')"
emit "  make         : $(make --version 2>/dev/null | head -n1 || echo '未安装')"
emit "  cmake        : $(cmake --version 2>/dev/null | head -n1 || echo '未安装')"
emit "  ninja        : $(ninja --version 2>/dev/null | sed 's/^/v/' || echo '未安装')"
emit "  ccache       : $(ccache --version 2>/dev/null | head -n1 || echo '未安装')"
emit "  perl         : $(perl --version 2>/dev/null | sed -n '2p' || echo '未安装')"
emit "  python3      : $(python3 --version 2>/dev/null || echo '未安装')"

# -------- 磁盘可用空间预检 --------
hr
emit "[预检] 磁盘可用空间（Qt 全量编译峰值可能 > 40GB）"
AVAIL_KB=$(df -Pk . 2>/dev/null | awk 'NR==2{print $4}')
if [[ -n "${AVAIL_KB:-}" ]]; then
    AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
    emit "  当前工作目录可用: ${AVAIL_GB} GB"
    if (( AVAIL_GB < 40 )); then
        emit "  !! 警告: 可用空间不足 40GB，qt-everywhere 全量编译可能失败（No space left on device）"
    fi
fi

hr
emit "================================================================================ 环境信息结束 ================================================================"