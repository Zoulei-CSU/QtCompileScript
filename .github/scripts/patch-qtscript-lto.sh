#!/usr/bin/env bash
# =============================================================================
# patch-qtscript-lto.sh —— 修复 qtscript 在 -ltcg(-flto) 下的链接失败
#
# 背景（Qt 官方已知 bug）：
#   QTBUG-42989 / Gentoo #652158 / #581024
#   「undefined symbol 'cti_vm_throw' in gcc with lto enabled」
#
#   src/3rdparty/javascriptcore/JavaScriptCore/jit/JITStubs.cpp 里，
#   cti_vm_throw 等函数是用**全局内联汇编**定义的，只被汇编代码引用。
#   GCC 在 LTO 模式下看不到普通 C++ 引用，把 `ctiVMThrowTrampoline`
#   里对 cti_vm_throw 的调用当作死引用，导致链接期报：
#       undefined reference to `cti_vm_throw'
#
#   官方把该问题标为 "Out of scope / Fix Version: None"（不修）。
#   业界通用做法（Gentoo / openEuler / PyTorch 生态）：
#   给这些函数加 `__attribute__((used))`，强制保留符号。
#
# 处理方式：对 JITStubs.h 做**幂等的**字符串替换（不依赖 patch 命令的
#   模糊匹配，避免上下文漂移导致打不上）。已打过则跳过。
#
# 用法：
#   bash patch-qtscript-lto.sh <源码根目录>        # 如 qt-src/qt-everywhere-src-5.15.19
#   （无参数时默认在 qt-src/* 下自动查找）
#
# 退出码：0 = 已处理/无需处理；1 = 关键文件存在但改动失败
# =============================================================================
set -euo pipefail

log()  { echo "[patch-qtscript-lto] $*"; }
warn() { echo "::warning title=qtscript LTO 补丁::$*"; }

SRC_ROOT="${1:-}"

# 传入的是「解包目录名」（如 qt-everywhere-src-5.15.19）时，补上 qt-src/ 前缀；
# 也兼容直接传完整相对/绝对路径的情况。
if [[ -n "$SRC_ROOT" && ! -d "$SRC_ROOT" && -d "qt-src/$SRC_ROOT" ]]; then
    SRC_ROOT="qt-src/$SRC_ROOT"
fi

# 未指定源码根（或仍不存在）时，自动探测
if [[ -z "$SRC_ROOT" || ! -d "$SRC_ROOT" ]]; then
    SRC_ROOT="$(find qt-src -maxdepth 1 -mindepth 1 -type d -print -quit 2>/dev/null || true)"
fi

if [[ -z "$SRC_ROOT" || ! -d "$SRC_ROOT" ]]; then
    log "未找到源码目录，跳过（可能源码尚未解包）"
    exit 0
fi

log "源码根: $SRC_ROOT"

HDR="$SRC_ROOT/qtscript/src/3rdparty/javascriptcore/JavaScriptCore/jit/JITStubs.h"

if [[ ! -f "$HDR" ]]; then
    log "未发现 qtscript JITStubs.h（源码包可能不含 qtscript，或已 skip）→ 跳过"
    exit 0
fi

log "目标文件: $HDR"

# 幂等检查：已含 __attribute__((used)) 就退出
if grep -q 'cti_vm_throw(STUB_ARGS_DECLARATION) __attribute__((used))' "$HDR" 2>/dev/null || \
   grep -q 'cti_vm_throw(STUB_ARGS_DECLARATION) attribute((used))' "$HDR" 2>/dev/null; then
    log "补丁已存在，无需重复处理"
    exit 0
fi

# 用 Python 做精确、幂等的替换（避免 sed 平台差异与转义问题）
PY_BIN=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY_BIN="$c"; break; fi
done
if [[ -z "$PY_BIN" ]]; then
    warn "容器内没有 python，无法打补丁 → 若启用了 -ltcg，qtscript 将链接失败"
    exit 0
fi

"$PY_BIN" - "$HDR" <<'PYEOF'
import io
import re
import sys

path = sys.argv[1]
with io.open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
    src = fh.read()

orig = src

# 形态 1（上游原始）：EncodedJSValue JIT_STUB cti_vm_throw(STUB_ARGS_DECLARATION);
# 形态 2（部分发行版已打）：... attribute((used));
# 目标：统一加上 __attribute__((used))
pat = re.compile(
    r'^(\s*EncodedJSValue\s+JIT_STUB\s+cti_vm_throw\(STUB_ARGS_DECLARATION\))'
    r'\s*(?:__attribute__\(\(used\)\)|attribute\(\(used\)\))?\s*;',
    re.MULTILINE,
)

def repl(m):
    return m.group(1) + " __attribute__((used));"

src, n = pat.subn(repl, src)

if n == 0:
    # 兜底：放宽到只匹配函数名（避免缩进/写法差异导致漏改）
    pat2 = re.compile(
        r'^(.*\bcti_vm_throw\(STUB_ARGS_DECLARATION\))'
        r'\s*(?:__attribute__\(\(used\)\)|attribute\(\(used\)\))?\s*;',
        re.MULTILINE,
    )
    src, n = pat2.subn(repl, src)

if n == 0:
    print("[patch-qtscript-lto] 未匹配到 cti_vm_throw 声明，可能源码格式已变")
    sys.exit(2)

if src == orig:
    print("[patch-qtscript-lto] 内容无变化（可能已打过补丁）")
    sys.exit(0)

with io.open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
    fh.write(src)

print("[patch-qtscript-lto] 已为 %d 处 cti_vm_throw 声明加上 __attribute__((used))" % n)
PYEOF

rc=$?
if [[ "$rc" -eq 0 ]]; then
    log "补丁应用成功"
    # 打印证据行，便于日志核对
    grep -n 'cti_vm_throw' "$HDR" | sed 's/^/  /' || true
elif [[ "$rc" -eq 2 ]]; then
    warn "未匹配到目标声明；若启用 -ltcg 可能仍失败。请人工检查 $HDR"
    exit 0
else
    warn "打补丁失败（退出码 $rc）"
    exit 0
fi