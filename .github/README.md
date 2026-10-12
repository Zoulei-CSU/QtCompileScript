# Qt 编译工作流使用说明

本仓库提供基于 GitHub Actions 的 Qt 源码编译工作流。在仓库页面手动触发，
选择参数后自动完成「下载源码 → 编译 → 打包 → 发布 Release」全流程。

---

## 一、如何触发

1. 打开仓库页面 → 顶部 **Actions** 标签
2. 左侧列表中选择要用的工作流：

   | 工作流 | 用途 |
   |---|---|
   | **Qt5 Build (Modern)** | 编译 Qt5，支持 Linux(新系统) / Windows / macOS |
   | **Qt5 Build (Legacy / AlmaLinux8 glibc2.28)** | 编译可在老系统（麒麟/统信/RHEL8 等）运行的 Qt5 产物 |
   | **Qt6 Build (Modern)** | 编译 Qt6（6.8 LTS），CMake 构建体系 |

3. 点击右侧 **Run workflow** 按钮，在弹出面板中选择参数
4. 点击绿色 **Run workflow** 开始执行

产物会自动：
- 上传为 Actions Artifact（保留 30 天）
- 发布到 GitHub **Release**（可在 Releases 页面下载）

---

## 二、默认行为

| 项目 | 默认值 | 说明 |
|---|---|---|
| 源码包 | `qt-everywhere` | 全量源码包（含全部模块），编译 2–5 小时 |
| 构建类型 | `release` | 最快、体积最小 |
| 跳过模块 | `qtdoc,qt3d,qtwebengine,qtwebview` | 避开最耗时的重型模块 |
| 打包模式 | `dev-lite` | 剔除 doc/examples 源码，**保留全部开发文件**（include/.prl/.cmake/mkspecs） |
| 跳过编译 | `tests` / `examples` | configure 时 `-nomake tests -nomake examples -no-compile-examples` |
| ccache | 开启 | 二次编译可显著加速 |
| 发布 Release | 是 | tag 自动生成 |
| Linux 特性 | openssl + libpq + iconv + fontconfig + xcb + Wayland | 见第五节 |
| Linux 输出 | strip + `tar.xz` | 剥离符号表，xz 高压缩比 |


---

## 二·补充、产物是「开发包」，不是「运行包」

**本工作流产出的 Qt 可以直接用于开发编译**（配合 qmake 或 CMake 使用），因此：

**✅ 一定包含**（开发必需，绝不剔除）：

| 内容 | 用途 |
|---|---|
| `include/` | 头文件，编译自己的 Qt 项目必需 |
| `lib/*.so` / `*.a` / `*.dylib` / `*.lib` | 链接库 |
| `lib/*.prl` | qmake 模块依赖描述 |
| `lib/cmake/Qt6*/` | CMake 包配置（`find_package(Qt6)` 依赖） |
| `mkspecs/` | 平台规格（qmake 必需） |
| `bin/`（qmake、moc、uic、rcc、windeployqt…） | 构建工具 |
| `plugins/` `qml/` `translations/` | 运行时插件与 QML 模块 |

**❌ 只剔除**（体积大且与开发无关）：

| 内容 | 说明 |
|---|---|
| `doc/` | Qt 自带 HTML 文档（数百 MB，可在线查） |
| `examples/` `demos/` 源码 | 示例源码，已通过 `-nomake examples` 不编译 |
| `*.o` | 编译中间产物（正常不含） |

> 打包脚本内含**安全校验**：若发现 `include/` 被误删会直接报错退出，避免打出无法开发的废包。
> 需要「原样全量包」（含文档与示例）时，把 `pack_mode` 选为 `dev-full`。

---

## 三、Linux 三条线的固定策略

Linux 编译按「系统新旧」分流，入口工作流已把差异固化，无需手工调参：

| | **Legacy / AlmaLinux8** | **Modern (Qt5)** | **Modern (Qt6)** |
|---|---|---|---|
| Runner | `almalinux:8` 容器 | `ubuntu-22.04` | `ubuntu-22.04` |
| glibc | 2.28（老系统兼容） | 2.35+ | 2.35+ |
| 编译器 | gcc-toolset-9/10/11/12/13 | gcc / clang | gcc / clang |
| libpng | **内置** `-qt-libpng` | 系统 `-system-libpng` | 系统 `-system-libpng` |
| Wayland | **关闭**（保持最大兼容） | **开启**（qtwayland 模块） | **开启** `-feature-wayland` |
| iconv | `-iconv` 启用 | `-iconv` 启用 | Qt6 内置，无需开关 |
| ICU | `-no-icu` | `-no-icu` | `-no-icu` |
| OpenSSL | `-openssl-linked` | `-openssl-linked` | `-openssl-linked` |
| libpq | `-sql-psql` | `-sql-psql` | `-sql-psql` |
| fontconfig | 自动检测（构建后校验） | 自动检测（构建后校验） | 自动检测（构建后校验） |

> ⚠️ **为何基线是 glibc 2.28 而非 2.17**：GitHub Actions 已把 Node20-based action
> 强制跑在 Node.js 24 上，而 Node 24 要求 glibc ≥ 2.27/2.28。CentOS7（glibc 2.17）
> 内 `actions/checkout`、`actions/cache`、`actions/upload-artifact` 等全部起不来
> （`CXXABI_1.3.9` / `GLIBC_2.27 not found`）。该组合无解，业界（PyTorch/NumPy/
> manylinux）均已放弃 CentOS7/AL2。因此本线基线上移到 **glibc 2.28**：
> 覆盖 Debian 10+ / Ubuntu 18.10+ / Fedora 29+ / RHEL 8+ / CentOS 8+。
>
> Legacy 线只编译 Qt5（Qt6 老系统线尚未启用，需单独验证 gcc-toolset 组合）。
> Qt6 的 GBK/GB18030 中文编码由 `qt5compat` 模块提供，脚本会自动保证其不被 skip。

构建完成后会解析 `config.summary` 核对上述硬需求是否真的启用了，
未满足的项会以 `::warning` 列出（不中断构建）。

---

## 四、风险提示（工作流会主动警告）

以下组合会触发 `::warning`，醒目组合还会直接报 `::error`：

| 组合 | 风险 |
|---|---|
| `qt-everywhere` | 编译 2–5 小时，接近或超出 6 小时 job 上限 |
| `debug` / `debug-and-release` | 耗时 2–3 倍，产物体积 3–5 倍，易超 2GB 资产上限 |
| `pack_mode=dev-full` | 原样打包（含 doc/examples），产物可能超 GitHub Release 单资产 2GB 上限 |
| `static_build` | 体积显著增大，注意 LGPL 合规 |
| **`qt-everywhere` + `debug`** | **直接报错：预计超 6 小时，几乎必然失败** |

---

## 五、产物命名

```
Qt-<版本>-<系统>-<编译器>[-glibc228][-legacy|-modern][-arm64][-static]-<构建类型>.tar.xz|.tar.gz|.zip
```

示例：
```
Qt-5.15.17-linux-gcc-modern-release.tar.xz
Qt-5.15.17-linux-almalinux8-gcc-toolset-11-glibc228-legacy-release.tar.xz
Qt-5.15.17-windows-msvc2022-release.zip
Qt-6.8.3-macos-clang-arm64-release.tar.gz
```

> Linux 输出统一为 `tar.xz`（strip 后高压缩）；macOS 为 `tar.gz`；Windows 为 `zip`。

每个 Release 附带：
- `*.sha256` — 校验文件
- `BUILD-INFO.txt` — 完整 configure 参数 + 编译机器硬件信息 + 耗时

---

## 六、硬件信息打印

每次编译开始前，工作流会打印编译机器的：

- CPU 型号 / 核心数 / 频率 / 指令集
- 内存总量与可用量（并给出 `make -j` 建议值）
- 磁盘容量与可用空间（低于 40GB 会警告）
- 编译器版本（gcc / clang / cl.exe / MSVC 各版本探测）
- CMake / Ninja / ccache / perl / python 版本

Linux/macOS 版：`.github/scripts/print-host-info.sh`
Windows 版：`.github/scripts/print-host-info.ps1`

也可以在本机直接运行，用于评估本机能否编译：

```bash
bash .github/scripts/print-host-info.sh
```

---

## 七、目录结构

```
.github/
├── workflows/
│   ├── qt5-modern.yml       # Qt5 新系统线入口（Linux 新系统 / Windows / macOS）
│   ├── qt5-legacy.yml       # Qt5 老系统线入口（AlmaLinux8 / glibc 2.28）
│   ├── qt6-modern.yml       # Qt6 新系统线入口（CMake 体系）
│   └── reusable-build.yml   # 核心复用工作流（被上述三者调用）
└── scripts/
    ├── print-host-info.{sh,ps1}      # 硬件信息打印
    ├── gen-configure-args.{sh,ps1}   # configure 参数生成（核心逻辑）
    ├── build-qt.{sh,ps1}             # configure + build + install + summary 校验
    └── package-qt.{sh,ps1}           # 瘦身(doc/examples) + strip + 打包 + 校验
```

脚本均可脱离 Actions 在本地运行，便于调试。例如生成本机
configure 参数：

```bash
# Qt5 新系统线（Wayland + 系统 libpng）
QT_MAJOR=5 QT_VERSION=5.15.17 QT_PLATFORM=linux-gcc \
QT_LINUX_FLAVOR=modern QT_ENABLE_WAYLAND=true QT_USE_SYSTEM_PNG=true \
QT_PREFIX="$HOME/Qt/5.15.17" bash .github/scripts/gen-configure-args.sh

# Qt5 老系统线（AlmaLinux8，内置 png，关 Wayland）
QT_MAJOR=5 QT_VERSION=5.15.17 QT_PLATFORM=linux-almalinux8-gcc-toolset-11 \
QT_LINUX_FLAVOR=legacy QT_ENABLE_WAYLAND=false QT_USE_SYSTEM_PNG=false \
QT_PREFIX="$HOME/Qt/5.15.17" bash .github/scripts/gen-configure-args.sh
```

---

## 八、已知限制

1. **CentOS7 已于 2024-06 EOL**，工作流内已自动将 yum 源指向
   `vault.centos.org`。若日后 vault 也下线，需改用替代镜像。
2. **Qt5 早期版本（≤5.15.2）源码包命名不同**（`qt-everywhere-src-*`，
   不带 `opensource`）。工作流会依次尝试多种命名，无需手工干预。
3. **macOS 跨架构**：`arm64` 产物需在 arm64 runner（macos-14）上构建，
   `x86_64` 用 macos-13。工作流按 `arch` 自动选择 runner。
4. **容器内无法复用 Actions 缓存**，因此 Legacy 线默认关闭 ccache。
5. **Legacy 线基线为 glibc 2.28（AlmaLinux 8）**，不再是 glibc 2.17。
   原因是 GitHub 已强制 Node-based action 走 Node.js 24，而 Node 24 要求
   glibc ≥ 2.27/2.28，CentOS7（2.17）内 `checkout`/`cache`/`upload-artifact`
   全部无法运行。若确需 glibc 2.17，须改为"宿主 job 做 checkout/cache/upload、
   容器 job 只编译"的双 job 结构（本仓库暂未实现）。
6. **Legacy 线固定关闭 Wayland 并使用内置 libpng**（保持最大兼容；
   AlmaLinux 8 虽有 libwayland-devel，但本线不启用）。
7. **Qt6 无 Legacy 线**（尚未启用）：需单独验证 gcc-toolset 与 Qt6 的版本组合。
8. **全量 qt-everywhere 耗时接近上限**：4 核 runner 上 2–5 小时，接近 6 小时
   job 上限；单个 job 上限设为 350 分钟，为上传产物预留约 10 分钟。
   Windows 的 msvc/mingw 全量构建尤其容易触顶，请优先评估。
9. **`-openssl-linked` 会让产物硬依赖 OpenSSL 动态库**，而产包里**不含**这些库。
   实测（Qt 6.8.3 / Windows / msvc2022）：`bin/Qt6Network.dll` 的导入表里直接写着
   `libssl-3-x64.dll`、`libcrypto-3-x64.dll`。也就是说目标机必须自行部署
   OpenSSL 3 x64，否则程序启动即报缺少 DLL。
   若不想有硬依赖，可改用 `-openssl-runtime`（运行时动态加载，仍需 DLL，但不是硬导入）。

## 九、产物验证方法

编译成功 ≠ 特性生效。例如 `-openssl-linked` 在找不到 OpenSSL 时 Qt6 不会报错，
只会静默降级。要确认某个特性**真的**编进去了，直接读产物二进制的导入表：

```bash
# Windows 产物：解析 PE Import Directory
python3 .github/scripts/verify-linked-libs.py dist/Qt-6.8.3-windows-msvc2022-release.zip \
    --find openssl,psql

# Linux 产物：解析 ELF DT_NEEDED（结果与 readelf -d 一致）
python3 .github/scripts/verify-linked-libs.py dist/Qt-5.15.17-linux-gcc-release.tar.xz \
    --find openssl,psql,wayland,fontconfig
```

输入可以是单个 `.dll`/`.so`、已解压的安装目录、`.zip` 或 `.tar.xz`；
全部关键词命中返回 0，有缺失返回 1（便于在 CI 里当断言用）。
同一脚本也以技能形式存在：`qt-configure-args-validation`。