#!/usr/bin/env python3
"""离线校验 Qt5/Qt6 configure 参数串是否只含合法选项。

用法:
    python3 validate.py 6 "-opensource -confirm-license -prefix /opt/Qt -release -shared ..."
    python3 validate.py 5 "$(cat args.txt)"
    echo "-release -shared -nomake tests" | python3 validate.py 6 -

退出码: 0 = 全部合法, 1 = 存在非法选项。

权威数据来源（首次运行会下载并缓存到 ~/.cache/qt-cmdline-dict/）：
  Qt6: qtbase/<branch> 下各 qt_cmdline.cmake 中的 qt_commandline_option() 定义
  Qt5: qtbase/<branch>/config_help.txt
"""
import os
import re
import subprocess
import sys
import urllib.request

CACHE = os.path.expanduser("~/.cache/qt-cmdline-dict")

QT6_CMDLINE_FILES = [
    "qt_cmdline.cmake",
    "src/corelib/qt_cmdline.cmake",
    "src/gui/qt_cmdline.cmake",
    "src/network/qt_cmdline.cmake",
    "src/sql/qt_cmdline.cmake",
    "src/plugins/sqldrivers/qt_cmdline.cmake",
    "src/widgets/qt_cmdline.cmake",
    "src/printsupport/qt_cmdline.cmake",
    "src/tools/qt_cmdline.cmake",
    "src/testlib/qt_cmdline.cmake",
]

# Qt6 解析器里显式处理、不走 qt_commandline_option() 的选项
QT6_EXTRA_OPTS = {"skip", "skip-tests", "skip-examples"}

# 前缀式：-D<val> 是"预处理器宏定义"，-I/-L/-F/-R 是路径
PREFIX_OPTS = {"D", "I", "L", "F", "R"}


def _fetch(url, dest):
    if os.path.isfile(dest):          # 空文件也算已解析过（如 404），避免反复重试
        return open(dest, encoding="utf-8", errors="replace").read()
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            data = r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        if e.code == 404:             # 该分支下文件不存在，缓存空结果
            open(dest, "w", encoding="utf-8").close()
            return ""
        print(f"!! 下载失败 {url}: {e}", file=sys.stderr)
        return ""
    except Exception as e:                                    # noqa: BLE001
        print(f"!! 下载失败 {url}: {e}", file=sys.stderr)
        return ""
    with open(dest, "w", encoding="utf-8") as f:
        f.write(data)
    return data


def qt6_dict(branch="6.8"):
    opts = set()
    for f in QT6_CMDLINE_FILES:
        url = f"https://raw.githubusercontent.com/qt/qtbase/{branch}/{f}"
        txt = _fetch(url, os.path.join(CACHE, f"q6_{branch}_{f.replace('/', '_')}"))
        opts |= set(re.findall(r"qt_commandline_option\(([A-Za-z0-9.+-]+)", txt))
    return opts | QT6_EXTRA_OPTS | PREFIX_OPTS


def qt5_dict(branch="5.15"):
    url = f"https://raw.githubusercontent.com/qt/qtbase/{branch}/config_help.txt"
    txt = _fetch(url, os.path.join(CACHE, f"q5_{branch}_config_help.txt"))
    opts = set()
    for line in txt.split("\n"):
        m = re.match(r"\s+(-[a-zA-Z0-9][a-zA-Z0-9<>|_.-]*)", line)
        if m:
            opts.add(re.split(r"[.\s]", m.group(1))[0].lstrip("-"))
    return opts | PREFIX_OPTS


def qt6_features(branch="6.8"):
    """从 configure.cmake 里抓 qt_feature("name") 作为已知 feature 集合。"""
    feats = set()
    for f in ("src/gui/configure.cmake", "src/corelib/configure.cmake", "configure.cmake"):
        url = f"https://raw.githubusercontent.com/qt/qtbase/{branch}/{f}"
        txt = _fetch(url, os.path.join(CACHE, f"q6feat_{branch}_{f.replace('/', '_')}"))
        feats |= set(re.findall(r'qt_feature\("([A-Za-z0-9_+-]+)"', txt))
    return feats


class Result:
    def __init__(self):
        self.problems = []

    def add(self, msg):
        self.problems.append(msg)


def validate(major, args_str, opts, feats):
    r = Result()
    after_dd = False
    for t in args_str.split():
        if t == "--":
            after_dd = True
            continue

        if after_dd:
            if not re.match(r"^-D[A-Za-z_][A-Za-z0-9_]*=", t):
                r.add(f"`--` 之后应只放 CMake 变量，却出现: {t}")
            continue

        if not t.startswith("-"):
            continue                                  # 选项的值（desktop / win32-msvc …）

        if re.match(r"^-D[A-Za-z_]", t) and "=" in t:
            r.add(f"CMake 变量必须放在 `--` 之后（-D 在 Qt 里是# define 语义）: {t}")
            continue

        m = re.match(r"^-no-feature-(.*)$", t)
        if m:
            if feats and m.group(1) not in feats:
                r.add(f"未知 feature: {t}")
            continue
        if t.startswith("-feature-"):
            name = t[len("-feature-"):]
            if feats and name not in feats:
                r.add(f"未知 feature: {t}")
            continue

        m = re.match(r"^-no-(.*)$", t)
        if m:
            if m.group(1) not in opts:
                r.add(f"未知选项: {t}")
            continue

        m = re.match(r"^-(qt|system)-(.+)$", t)
        if m:
            if m.group(2) not in opts:
                r.add(f"未知三方库选项: {t}")
            continue

        if re.match(r"^-[ILFR]", t):
            continue                                  # -Ipath / -Lpath 连写形式
        if t.startswith("-sql-"):
            continue                                  # 通配形式 -sql-<driver>

        if t[1:] not in opts:
            r.add(f"未知选项: {t}")
    return r


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    major = argv[1].strip()
    raw = argv[2]
    if raw == "-":
        raw = sys.stdin.read()

    if major == "6":
        opts, feats = qt6_dict(), qt6_features()
    elif major == "5":
        opts, feats = qt5_dict(), set()
    else:
        print("major 必须是 5 或 6", file=sys.stderr)
        return 2

    print(f"Qt{major} 字典: {len(opts)} 个选项, {len(feats)} 个 feature")
    print(f"待校验: {raw.strip()}\n")
    r = validate(major, raw, opts, feats)
    if r.problems:
        print(f"❌ 发现 {len(r.problems)} 个问题：")
        for p in r.problems:
            print("   -", p)
        return 1
    print("✅ 全部合法")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
