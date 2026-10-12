#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_linked_libs.py —— 验证构建出的 Qt 二进制「真的」链接了某个第三方库。

为什么需要它：
  configure 的参数校验（validate.py）只能保证「参数合法」，不能保证「特性真正
  生效」。例如 `-openssl-linked` 在 Qt6 里若找不到 OpenSSL，只会降级/告警而非
  报错；configure 报告又常常被日志系统截断（Windows 上 configure.log 经
  Tee-Object 落盘，job 日志里未必完整回显）。
  直接从产物二进制读导入表，是唯一「不可抵赖」的证据。

支持：
  * PE  (.dll / .exe)   —— 解析 Import Directory Table
  * ELF  (.so / 可执行) —— 解析 PT_DYNAMIC 的 DT_NEEDED
输入可以是：单个二进制文件 / 已解压的安装目录 / 打包好的 .zip

用法：
  verify_linked_libs.py <path> [--find OpenSSL,PSQL] [--all]
  verify_linked_libs.py qtinstall/ --find openssl
  verify_linked_libs.py Qt-6.8.3-linux-gcc-release.tar.xz --find wayland
  verify_linked_libs.py bin/Qt6Network.dll --all

退出码：0 = 找到全部 --find 关键词；1 = 有缺失；2 = 用法/解析错误。
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
import tarfile
import zipfile

# --------------------------------------------------------------------------- #
# PE：导入表
# --------------------------------------------------------------------------- #
def pe_imports(data: bytes) -> list[str]:
    if len(data) < 0x40 or data[:2] != b"MZ":
        raise ValueError("不是 PE 文件（缺少 MZ）")
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if data[e_lfanew:e_lfanew + 4] != b"PE\0\0":
        raise ValueError("不是 PE 文件（缺少 PE 签名）")
    coff = e_lfanew + 4
    num_sections = struct.unpack_from("<H", data, coff + 2)[0]
    opt_size = struct.unpack_from("<H", data, coff + 16)[0]
    opt = coff + 20
    magic = struct.unpack_from("<H", data, opt)[0]
    pe32p = magic == 0x20B
    dd_off = opt + (112 if pe32p else 96)
    imp_rva = struct.unpack_from("<I", data, dd_off + 8)[0]

    sections = []
    sh = opt + opt_size
    for i in range(num_sections):
        off = sh + i * 40
        vsz = struct.unpack_from("<I", data, off + 8)[0]
        va = struct.unpack_from("<I", data, off + 12)[0]
        raw_sz = struct.unpack_from("<I", data, off + 16)[0]
        raw_ptr = struct.unpack_from("<I", data, off + 20)[0]
        sections.append((va, max(vsz, raw_sz), raw_ptr))

    def rva2off(rva: int):
        for va, size, ptr in sections:
            if va <= rva < va + size:
                return ptr + (rva - va)
        return None

    if not imp_rva:
        return []
    off = rva2off(imp_rva)
    if off is None:
        return []
    names = []
    while off + 20 <= len(data):
        ent = data[off:off + 20]
        if ent == b"\0" * 20:
            break
        name_rva = struct.unpack_from("<I", ent, 12)[0]
        if not name_rva:
            break
        no = rva2off(name_rva)
        if no is None:
            break
        end = data.find(b"\0", no)
        names.append(data[no:end].decode("ascii", "replace"))
        off += 20
    return names


# --------------------------------------------------------------------------- #
# ELF：DT_NEEDED
# --------------------------------------------------------------------------- #
def elf_needed(data: bytes) -> list[str]:
    if data[:4] != b"\x7fELF":
        raise ValueError("不是 ELF 文件")
    is64 = data[4] == 2
    little = data[5] == 1
    en = "<" if little else ">"

    if is64:
        e_phoff = struct.unpack_from(en + "Q", data, 0x20)[0]
        e_phentsize = struct.unpack_from(en + "H", data, 0x36)[0]
        e_phnum = struct.unpack_from(en + "H", data, 0x38)[0]
    else:
        e_phoff = struct.unpack_from(en + "I", data, 0x1C)[0]
        e_phentsize = struct.unpack_from(en + "H", data, 0x2A)[0]
        e_phnum = struct.unpack_from(en + "H", data, 0x2C)[0]

    PT_LOAD, PT_DYNAMIC = 1, 2
    loads, dyn_off, dyn_size = [], None, 0
    for i in range(e_phnum):
        p = e_phoff + i * e_phentsize
        p_type = struct.unpack_from(en + "I", data, p)[0]
        if is64:
            p_offset = struct.unpack_from(en + "Q", data, p + 0x08)[0]
            p_vaddr = struct.unpack_from(en + "Q", data, p + 0x10)[0]
            p_filesz = struct.unpack_from(en + "Q", data, p + 0x20)[0]
        else:
            p_offset = struct.unpack_from(en + "I", data, p + 0x04)[0]
            p_vaddr = struct.unpack_from(en + "I", data, p + 0x08)[0]
            p_filesz = struct.unpack_from(en + "I", data, p + 0x10)[0]
        if p_type == PT_LOAD:
            loads.append((p_vaddr, p_filesz, p_offset))
        elif p_type == PT_DYNAMIC:
            dyn_off, dyn_size = p_offset, p_filesz

    if dyn_off is None:
        return []

    def vaddr2off(v):
        for base, size, off in loads:
            if base <= v < base + size:
                return off + (v - base)
        return None

    entsize = 16 if is64 else 8
    fmt = en + ("qQ" if is64 else "iI")
    strtab_v = strsz = None
    needed_offsets = []
    for o in range(dyn_off, dyn_off + dyn_size, entsize):
        tag, val = struct.unpack_from(fmt, data, o)
        if tag == 0:                       # DT_NULL
            break
        if tag == 1:                       # DT_NEEDED
            needed_offsets.append(val)
        elif tag == 5:                     # DT_STRTAB
            strtab_v = val
        elif tag == 10:                    # DT_STRSZ
            strsz = val

    if not needed_offsets or strtab_v is None:
        return []
    strtab_off = vaddr2off(strtab_v)
    if strtab_off is None:
        return []
    out = []
    for noff in needed_offsets:
        s = strtab_off + noff
        end = data.find(b"\0", s)
        out.append(data[s:end].decode("utf-8", "replace"))
    return out


def read_deps(data: bytes) -> list[str]:
    if data[:2] == b"MZ":
        return pe_imports(data)
    if data[:4] == b"\x7fELF":
        return elf_needed(data)
    return []


# --------------------------------------------------------------------------- #
# 收集目标文件
# --------------------------------------------------------------------------- #
BIN_EXT = (".dll", ".exe", ".so", ".so.1", ".dylib")


def looks_like_binary(name: str, data: bytes) -> bool:
    base = os.path.basename(name)
    if ".so" in base or base.endswith((".dll", ".exe", ".dylib")):
        return True
    return data[:2] == b"MZ" or data[:4] == b"\x7fELF"


def walk_dir(root: str):
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            p = os.path.join(dirpath, f)
            if ".so" in f or f.endswith((".dll", ".exe", ".dylib")):
                yield os.path.relpath(p, root), lambda p=p: open(p, "rb").read()


def walk_zip(path: str):
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if n.endswith("/"):
                continue
            if ".so" in os.path.basename(n) or n.endswith((".dll", ".exe", ".dylib")):
                yield n, (lambda n=n: zipfile.ZipFile(path).read(n))


def walk_tar(path: str):
    with tarfile.open(path, "r:*") as t:
        for m in t.getmembers():
            if not m.isfile():
                continue
            b = os.path.basename(m.name)
            if ".so" in b or b.endswith((".dll", ".exe", ".dylib")):
                yield m.name, (lambda m=m: t.extractfile(m).read())


def collect(path: str):
    if os.path.isdir(path):
        return list(walk_dir(path))
    low = path.lower()
    if low.endswith(".zip"):
        return list(walk_zip(path))
    if low.endswith((".tar.xz", ".tar.gz", ".tar.bz2", ".tgz", ".tar")):
        return list(walk_tar(path))
    return [(os.path.basename(path), lambda: open(path, "rb").read())]


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
# 关注的关键第三方栈（关键词 -> 人类可读名）
STACKS = [
    ("openssl", ["libssl", "libcrypto", "ssleay"]),
    ("psql", ["libpq", "LIBPQ", "postgres"]),
    ("wayland", ["libwayland", "wayland-client", "wayland-egl"]),
    ("xcb", ["libxcb", "xcb-"]),
    ("fontconfig", ["fontconfig"]),
    ("freetype", ["freetype"]),
    ("icu", ["libicu", "icuuc", "icui18n"]),
    ("png", ["libpng", "png16"]),
    ("dbus", ["libdbus-1", "libdbus.so"]),
    ("vulkan", ["vulkan"]),
    ("ssl_backend", ["qopensslbackend", "qschannelbackend"]),
]


def main() -> int:
    ap = argparse.ArgumentParser(description="验证 Qt 产物是否真的链接了指定的第三方库")
    ap.add_argument("path", help="二进制 / 安装目录 / zip / tar.*")
    ap.add_argument("--find", default="", help="逗号分隔的关键词，全部命中才返回 0，如 openssl,psql")
    ap.add_argument("--all", action="store_true", help="打印每个二进制的完整依赖列表")
    ap.add_argument("--summary", action="store_true", help="只看第三方栈汇总（默认行为）")
    args = ap.parse_args()

    if not os.path.exists(args.path):
        print(f"!! 路径不存在: {args.path}", file=sys.stderr)
        return 2

    try:
        targets = collect(args.path)
    except Exception as e:                                            # noqa: BLE001
        print(f"!! 无法读取 {args.path}: {e}", file=sys.stderr)
        return 2

    if not targets:
        print("!! 没找到任何二进制文件", file=sys.stderr)
        return 2

    hit: dict[str, list[tuple[str, str]]] = {k: [] for k, _ in STACKS}
    scanned = 0
    for name, loader in targets:
        try:
            data = loader()
        except Exception:                                             # noqa: BLE001
            continue
        if not looks_like_binary(name, data):
            continue
        try:
            deps = read_deps(data)
        except Exception:                                             # noqa: BLE001
            continue
        if not deps:
            continue
        scanned += 1
        for dep in deps:
            low = dep.lower()
            for key, pats in STACKS:
                if any(p.lower() in low for p in pats):
                    hit[key].append((name, dep))
        if args.all:
            print(f"--- {name} ({len(deps)} 项依赖) ---")
            for d in sorted(deps):
                print("   ", d)

    print(f"\n扫描了 {scanned} 个二进制（共 {len(targets)} 个候选）\n")
    print("=== 第三方栈命中情况 ===")
    for key, _ in STACKS:
        entries = hit[key]
        if not entries:
            continue
        uniq = sorted({d for _, d in entries})
        who = sorted({n for n, _ in entries})[:5]
        mark = "✅"
        print(f"  {mark} {key:<12} {', '.join(uniq)}")
        print(f"      出现在: {', '.join(who)}{' ...' if len(entries) > 5 else ''}")

    if args.find:
        wanted = [w.strip().lower() for w in args.find.split(",") if w.strip()]
        missing = []
        for w in wanted:
            # 直配 stack key，或在任意依赖名里出现
            ok = bool(hit.get(w))
            if not ok:
                ok = any(w in d.lower() for key in hit for _, d in hit[key])
            if ok:
                print(f"\n[OK]   --find {w} 命中")
            else:
                print(f"\n[缺失] --find {w} 未在导入表/DT_NEEDED 中出现")
                missing.append(w)
        if missing:
            print("\n结论: 以下特性可能未真正生效（参数合法 ≠ 特性启用）:",
                  ", ".join(missing))
            return 1
        print("\n结论: 全部指定特性均已链接进产物 ✅")
    return 0


if __name__ == "__main__":
    sys.exit(main())
