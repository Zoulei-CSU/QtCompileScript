# 用 Docker 编译 Qt —— 使用手册

本目录提供**两套开箱即用的 Qt 编译环境**，与 `.github/workflows/` 里的 CI 两条线一一对应：

| 目录里的文件 | 基础镜像 | glibc | 对应 CI 工作流 | 适用 |
|---|---|---|---|---|
| `Dockerfile.modern` | Ubuntu 22.04 | 2.35 | `qt5-modern.yml` / `qt6-modern.yml` | Qt5、Qt6 都能编；产物适合较新发行版 |
| `Dockerfile.legacy` | AlmaLinux 8 | 2.28 | `qt5-legacy.yml` | 只编 Qt5；产物兼容面更宽（Debian 10+ / Ubuntu 18.10+ / RHEL 8+） |

> **镜像里不含 Qt、也不编译 Qt。** 它只提供一套「依赖齐全、拿来就能编」的环境。
> 原因：Qt 全量编译要 35 分钟到几小时、源码包数 GB，塞进镜像层既不划算也没必要。
> 镜像构建完成后，你进入容器，自己下载源码、configure、make。

---

## 一、前置要求

- **Docker Engine 20.10+**（推荐 24+），带 Docker Compose v2（`docker compose`）。
  - 旧的独立 `docker-compose` v1 也能用，脚本会自动识别。
- **磁盘空间**：每个镜像约 2–3 GB；再算上源码（约 1 GB）与构建产物（数 GB），
  建议预留 **30 GB** 以上。
- **至少 4 核 + 8 GB 内存**；Qt 全量编译建议 8 核 + 16 GB。
  `-j` 并行度按核数设置，否则会因为内存不足触发 OOM（见第七节）。

---

## 二、快速开始（三行命令）

```bash
cd docker

./build.sh                # 构建两条线（也可只构建一条：./build.sh modern）
./run.sh modern           # 进入现代线容器（Ubuntu 22.04）
# 或者
./run.sh legacy           # 进入老系统线容器（AlmaLinux 8）
```

进入容器后就是一个可编译的 bash。接下来按**第四节**下载源码并编译。

若你更习惯原生 compose：

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml run --rm modern
```

---

## 三、构建产物与挂载约定

`run.sh` / `docker-compose.yml` 会把下面这些目录挂进容器，**编译产物会自动落到宿主机**，
容器删掉也不丢：

| 宿主机路径 | 容器内路径 | 可写 | 用途 |
|---|---|---|---|
| 仓库根目录 | `/work/repo` | 只读 | 取 `.github/scripts/` 等脚本 |
| `docker/src/` | `/src` | 可写 | **放 Qt 源码包与解包目录** |
| `docker/build/` | `/build` | 可写 | **构建目录（configure 在这里跑）** |
| 命名卷 `qtinstall-<线>` | `/opt/qt` | 可写 | **安装前缀（make install 落这里）** |
| 命名卷 `ccache-<线>` | `/ccache` | 可写 | ccache 缓存，**跨容器复用**，第二次编译飞快 |

> 命名卷里的内容用 `docker volume ls` 能看到；想完整导出安装结果，见第五节的
> 「导出到宿主机」。

---

## 四、在容器内编译 Qt（核心步骤）

以下命令都在**容器内**执行。以现代线编 **Qt 5.15.19 全量**为例。

### 4.1 下载并解包源码

```bash
# 进 /src 操作（这个目录映射到宿主机 docker/src/，源码会留在本地复用）
cd /src

# 版本号按需改。5.15.x 用 single 包（qt-everywhere-opensource-src）
VER=5.15.19
BASE=https://download.qt.io/archive/qt/5.15/${VER}/single

wget -c "${BASE}/qt-everywhere-opensource-src-${VER}.tar.xz"
tar -xJf "qt-everywhere-opensource-src-${VER}.tar.xz"

# 得到 /src/qt-everywhere-src-5.15.19
```

> **国内网络慢**：可换成镜像站，例如
> `https://mirrors.tuna.tsinghua.edu.cn/qt/archive/qt/5.15/${VER}/single/`
> （清华镜像，路径结构与官方一致）。
>
> **想编 Qt6**：路径是 `archive/qt/6.8/6.8.3/single/qt-everywhere-src-6.8.3.tar.xz`，
> 包名同样是 `qt-everywhere-opensource-src-<ver>`。

### 4.2 打 qtscript 的 LTO 补丁（**编 Qt5 且用 `-ltcg` 时必做**）

这是个容易踩的坑：Qt5 加了 `-ltcg`（= `-flto`）后，**qtscript 模块必然链接失败**：

```
undefined reference to `cti_vm_throw'
gmake: *** [Makefile:999: module-qtscript-make_first] Error 2
```

原因（Qt 官方 bug [QTBUG-42989](https://bugreports.qt.io/browse/QTBUG-42989)，
官方标记为「不修」）：`cti_vm_throw` 是用全局内联汇编写成的、**只被汇编代码引用**，
GCC 在 LTO 下看不到 C++ 引用就把它当死代码丢了。

仓库里已经准备好补丁脚本，**直接用**：

```bash
cd /src/qt-everywhere-src-5.15.19
bash /work/repo/.github/scripts/patch-qtscript-lto.sh .
```

看到这样的输出就是成功了：

```
[patch-qtscript-lto] 已为 1 处 cti_vm_throw 声明加上 __attribute__((used))
[patch-qtscript-lto] 补丁应用成功
```

> **不想用 `-ltcg`？** 那就不需要打补丁。去掉 `-ltcg` 即可完全规避这个问题
> （代价：产物略大、失去跨模块内联优化）。

### 4.3 configure

```bash
cd /build
mkdir -p qt5 && cd qt5

SRC=/src/qt-everywhere-src-5.15.19
PREFIX=/opt/qt/5.15.19

"${SRC}/configure" \
  -opensource -confirm-license -prefix "${PREFIX}" \
  -release -shared \
  -skip qtdoc -skip qt3d -skip qtwebengine -skip qtwebview -skip qtlocation -skip qtwayland \
  -nomake tests -nomake examples -no-compile-examples \
  -qt-libpng -iconv -no-icu \
  -xcb -xcb-xlib -opengl desktop -no-angle -ltcg \
  -openssl-linked -sql-psql
```

**参数是怎么来的？** 这串参数与 CI 里 `qt5-legacy.yml` 生成的**完全一致**，
由 `.github/scripts/gen-configure-args.sh` 生成。逐项说明：

| 参数 | 含义 |
|---|---|
| `-opensource -confirm-license` | 开源版 + 自动接受许可（无交互） |
| `-prefix /opt/qt/5.15.19` | 安装前缀（`make install` 落这里 → 映射到命名卷） |
| `-release -shared` | Release + 动态库 |
| `-skip ...` | 跳过重型模块。**`qtlocation` 依赖 mapbox-gl-native，编译极慢且常失败**；`qtwebengine` 依赖 Chromium，更慢。老系统线固定跳 `qtwayland`（关 Wayland） |
| `-nomake tests/examples`<br>`-no-compile-examples` | 不编测试与示例（`-no-compile-examples` 是 **Qt5 独有**，Qt6 传了会报错） |
| `-qt-libpng` | 用源码内置 libpng（老系统线的系统 png 版本偏低，内置最稳） |
| `-iconv -no-icu` | 启用 iconv、关闭 ICU（`-iconv` 是 **Qt5 独有**，Qt6 已内置） |
| `-xcb -xcb-xlib` | X11 后端 |
| `-opengl desktop -no-angle` | **锁定桌面 OpenGL**。`-no-angle` 是 **Qt5 独有**（Qt6 已移除 ANGLE，写了会报 `Unknown command line option`） |
| `-ltcg` | 链接期优化（**需先打 4.2 的补丁**） |
| `-openssl-linked -sql-psql` | 硬链接 OpenSSL、启用 PostgreSQL 驱动（本项目的硬需求） |

> **更省事的做法**：直接用仓库脚本生成参数，避免手工抄错。
> 脚本通过环境变量接收输入，并把结果写到 `$GITHUB_OUTPUT` 或 stdout：
>
> ```bash
> export QT_MAJOR=5 QT_VERSION=5.15.19
> export QT_PLATFORM=linux-almalinux8-gcc-toolset-11   # 现代线写 linux-gcc
> export QT_BUILD_TYPE=release QT_ARCH=x86_64
> export QT_SOURCE_PACKAGE=qt-everywhere
> export QT_PREFIX=/opt/qt/5.15.19
> export QT_OPENSSL_LINKED=true
> export QT_LINUX_FLAVOR=legacy        # 现代线改成 modern
> export QT_ENABLE_WAYLAND=false       # 现代线可以改 true
> export QT_USE_SYSTEM_PNG=false
> export QT_SKIP_MODULES=qtdoc,qt3d,qtwebengine,qtwebview,qtlocation
>
> bash /work/repo/.github/scripts/gen-configure-args.sh
> ```
>
> 输出里 `configure_args=...` 那一行就是完整参数串，复制出来用即可。

### 4.4 编译与安装

```bash
# 并行度：一般取 CPU 核数。内存紧张时降到核数的一半（见第七节）。
JOBS=$(nproc)

make -j"${JOBS}"
make install
```

> `configure` 会打印一份 `config.summary`，记录**本次全部配置快照**
> （每个 feature 开/关、每个三方库用系统还是内置）——建议保留，方便日后溯源。

### 4.5 验证结果

```bash
# 1) 确认关键库真的被链接（直接读 .so 的导入表，不靠"configure 说 OK"）
python3 /work/repo/.github/scripts/verify-linked-libs.py "${PREFIX}/lib" \
  --find openssl,psql,xcb,fontconfig

# 2) 检查 config.summary 里的关键项
grep -iE 'openssl|postgresql|fontconfig|xcb|libpng' "${PREFIX}/config.summary" 2>/dev/null || true
```

---

## 五、导出到宿主机

安装前缀在**命名卷**里，宿主机看不到。三种导出方式：

**方式 A：从容器里直接拷出来**（最直接）

```bash
# 在宿主机执行（容器还在跑，或用一个临时容器）
docker run --rm \
  -v qtinstall-modern:/opt/qt \
  -v "$PWD":/out \
  alpine \
  tar -cJf /out/qt-5.15.19.tar.xz -C /opt/qt 5.15.19

# alpine 需要压缩工具；或直接用同款镜像：
docker run --rm -v qtinstall-modern:/opt/qt -v "$PWD":/out qt-build:modern \
  tar -cJf /out/qt-5.15.19.tar.xz -C /opt/qt 5.15.19
```

**方式 B：改挂载到宿主机目录**（边编边看）

把 `docker-compose.yml` 里 `/opt/qt` 那行换成：

```yaml
      - ./qtinstall:/opt/qt          # 换成宿主机目录
```

然后 `-prefix` 指向 `/opt/qt/5.15.19`，产物就直接落在 `docker/qtinstall/` 下了。

> 挂载宿主机目录比命名卷慢一些（尤其 macOS/Windows 的文件同步），
> 但换来"看得见、能直接拷"。

**方式 C：用仓库的打包脚本**（产出一致，推荐）

```bash
# 在容器内
export QT_PREFIX=/opt/qt/5.15.19
export QT_OUTPUT_DIR=/work/out            # 记得在 compose 里挂出 /work/out
export QT_ARTIFACT_NAME=Qt-5.15.19-linux-modern-release
export QT_VERSION=5.15.19
export QT_PACK_MODE=dev-lite              # dev-lite 剔除 doc/examples 源码，保留开发文件

bash /work/repo/.github/scripts/package-qt.sh
```

会得到 `Qt-5.15.19-linux-modern-release.tar.xz` + `.sha256` + `BUILD-INFO.txt`。
`dev-lite` 会**保留** `include/`、`*.prl`、`lib/cmake/`、`mkspecs/`（开发包必需），
只剔除文档与示例源码。

---

## 六、编译 Qt6 有什么不同

Qt6 的 `configure` 是 CMake 包装器，**选项与 Qt5 有实质差异**，照抄 Qt5 的参数会失败。
最小可用示例（现代线）：

```bash
cd /build && mkdir -p qt6 && cd qt6
SRC=/src/qt-everywhere-src-6.8.3

"${SRC}/configure" \
  -opensource -confirm-license -prefix /opt/qt/6.8.3 \
  -release -shared \
  -skip qtdoc -skip qt3d -skip qtwebengine -skip qtwebview -skip qtlocation \
  -nomake tests -nomake examples \
  -no-icu -opengl desktop \
  -openssl-linked -sql-psql

cmake --build . --parallel "$(nproc)"
cmake --install .
```

**Qt5 ↔ Qt6 关键差异**（这几条最容易踩）：

| 项 | Qt5 | Qt6 |
|---|---|---|
| `-no-compile-examples` | ✅ 有 | ❌ **没有**，传了报 `Unknown command line option` |
| `-verbose` / `-mp` | ✅ 有 | ❌ 没有；并行交给生成器（`cmake --build --parallel`） |
| `-platform win32-msvc` | ✅ 有 | ❌ mkspec 机制已废弃 |
| `-no-angle` | ✅ 有（Qt5 带 ANGLE） | ❌ **ANGLE 已移除**，传了会报错 |
| `-iconv` | ✅ 有 | ❌ 已内置，无此开关 |
| `-feature-wayland` | ❌ 用「不 skip qtwayland」 | ✅ `-feature-wayland` / `-no-feature-wayland` |
| 构建工具 | Makefiles（`make`） | **强制 Ninja**（`configure` 自动加 `-G Ninja`） |
| **qtscript** | 存在（LTO 需打补丁） | 已移除，无此问题 |
| `qt5compat` | — | **绝不能 skip**（中文 GBK/GB18030 编码依赖它） |

> **同一份 CMake 抽象层**：Qt6 里 `configure` 会自动追加 `-G Ninja`，
> 所以构建目录里是 `build.ninja`、**没有 Makefile**。别硬写 `make -j`，
> 否则会得到极具迷惑性的 `No targets specified and no makefile found`。
> 稳妥做法是探测：有 `build.ninja` 就用 `cmake --build`。

---

## 七、常见问题（FAQ）

### Q1：`make -jN` 被 OOM Killer 杀掉 / 卡死

Qt 大文件（尤其 `qtwebengine`、`qtdeclarative` 里的巨型 TU）单文件编译就吃 2–4 GB 内存。
并行度设太高会把内存打满。

**处方**：把 `-j` 降到 `内存GB / 3` 左右，例如 16 GB 机器用 `-j5`；或只编单模块
（`-skip` 掉大部分模块）。若你在 WSL2/Docker Desktop 里，还要检查
分配给 Docker 的内存上限（默认可能只有 2 GB）。

### Q2：`configure` 报 `Unknown command line option '-xxx'`

**九成是把 Qt5 的选项传给了 Qt6**（或反之）。对照第六节的差异表逐项核对。
注意 Qt 的 configure **只报第一个错就退出**，修完要重新校验整串 ——
本仓库的 `docs/skills/qt-configure-args-validation/` 里有个离线校验脚本可以先跑：

```bash
python3 /work/repo/docs/skills/qt-configure-args-validation/scripts/validate.py \
  --major 5 --args "-release -shared -opengl desktop -no-angle -ltcg"
```

### Q3：`undefined reference to 'cti_vm_throw'`（编 Qt5 时）

LTO 与 qtscript 的已知冲突 → 回到 **4.2** 打补丁，或去掉 `-ltcg`。

### Q4：`configure` 说 OpenSSL/PostgreSQL 是 `no`，但明明装了开发包

先确认开发包真的在：

```bash
pkg-config --modversion openssl
pkg-config --modversion libpq
ls /usr/include/libpq-fe.h /usr/include/openssl/ssl.h
```

若都正常但 Qt 仍找不到，多半是 `configure` 的探测路径问题。
可以显式指路（注意 `-I/-L` 是 configure 选项，不需要放进 `--` 之后）：

```bash
"${SRC}/configure" ... -I/usr/include -L/usr/lib64 ...
```

### Q5：编出来的 Qt 在目标机器上跑不起来 / 报 `GLIBC_2.xx not found`

说明**产物的 glibc 基线比目标机高**。选线原则：

- 目标机是较新的发行版（Ubuntu 22.04+、Debian 12+）→ 用 **modern 线**（glibc 2.35）。
- 目标机较老（Debian 10 / Ubuntu 18.10 / RHEL 8 / 麒麟、统信等）→ 用 **legacy 线**（glibc 2.28）。
- 查看产物依赖的最低 glibc 版本：
  ```bash
  objdump -T /opt/qt/5.15.19/lib/libQt5Core.so.5 | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -3
  ```

> 为什么不再提供 glibc 2.17（CentOS7）的镜像？
> CentOS7 已于 2024-06 EOL，且 GitHub Actions 把 Node20 系 action 强制跑在 Node 24 上，
> Node 24 要求 glibc ≥ 2.27/2.28，CentOS7 根本跑不了（连 `actions/checkout` 都起不来）。
> 该组合无解，业界（PyTorch / NumPy / manylinux_2_28）已统一抬到 2.28 基线。

### Q6：想让第二次编译快很多

`/ccache` 是命名卷，**跨容器持久**，且镜像里已经把 ccache 接进 `PATH`
（用软链包装目录，不是 `CC="ccache gcc"` —— 后者会让 Qt 认不出编译器）。

确认它生效：

```bash
ccache --show-stats
which gcc        # 应指向 /usr/lib/ccache/gcc（Ubuntu）或 /usr/lib64/ccache/gcc（AlmaLinux）
```

注意：**源码内容变化、编译器版本变化、`-ltcg` 有无变化都会让缓存失效**。
同配置重编同一份源码，命中率才会高。

### Q7：`docker run` 后文件属主变成 root

`build.sh`/`run.sh` 默认把容器内用户 UID/GID 设成**当前宿主机用户**，
一般不会有这个问题。若你手工 `docker build` 且没传 `--build-arg USER_UID=$(id -u)`，
就会出现 root 属主。修正：

```bash
./build.sh modern      # 重新构建时会自动带上当前 UID/GID
```

### Q8：老系统线里 `gcc` 版本不对 / 找不到 `gcc-toolset`

AlmaLinux 8 的 `gcc-toolset` 走 SCL 机制，需要激活。本镜像**已配置自动激活**
（通过 `/etc/profile.d/` + `BASH_ENV`），正常情况下你直接 `gcc --version` 就是 11.x。

若异常，手动激活：

```bash
scl enable gcc-toolset-11 bash     # 进入激活后的子 shell
# 或
source /opt/rh/gcc-toolset-11/enable
gcc --version
```

换工具链版本则在构建时传参：

```bash
GCC_TOOLSET=gcc-toolset-12 ./build.sh legacy
```

### Q9：Qt6 的 `configure` 停在 `Configuring submodule 'qttools'` 后报 CMake Error

典型报错：

```
CMake Error at /usr/lib/llvm-14/lib/cmake/clang/ClangTargets.cmake:750 (message):
  The imported target "clangBasic" references the file
     "/usr/lib/llvm-14/lib/libclangBasic.a"
  but this file does not exist.
```

根因：**系统里有 clang 的 CMake config，却没有对应的静态库**（config 与库不配套）。
Qt6 的 `qttools` 会 `qt_find_package(WrapLibClang 8)`（非 `MARK_OPTIONAL`），
`find_package(Clang CONFIG)` 一旦命中悬空的 config 就会 `FATAL_ERROR`。

本仓库的 `Dockerfile.modern` **已经装了 `libclang-dev`**，正常不会遇到。
若你手工基于 bare `ubuntu:22.04` 起镜像，补装即可：

```bash
sudo apt-get update && sudo apt-get install -y libclang-dev
```

自检是否配套（本仓库镜像构建期会做同一件事）：

```bash
t=$(find /usr/lib/cmake /usr/lib/llvm-* -name ClangTargets.cmake 2>/dev/null | head -1)
p=$(dirname "$(dirname "$(dirname "$(dirname "$t")")")")   # 该文件位于 <prefix>/lib/cmake/clang/
ls "$p/lib/libclangBasic.a" && echo "配套 OK" || echo "悬空：需要 libclang-dev"
```

> 注：**老系统线（`Dockerfile.legacy` / AlmaLinux 8）不需要**这个包 ——
> 那里根本没装 clang，`find_package(Clang)` 直接 not found，qttools 只会告警并
> 关掉 qdoc，不会失败。

---

## 八、与 CI 的关系

这套 Docker 环境**刻意与 CI 保持一致**：

- 依赖清单：与 `.github/workflows/reusable-build.yml` 的
  「安装依赖 (Ubuntu)」/「安装依赖 (老系统容器)」逐条对应。
- configure 参数：与 `.github/scripts/gen-configure-args.sh` 生成的一致 ——
  这个脚本在 CI 与容器里都能跑，是**同一个真相来源**。
- 补丁：CI 用的 `patch-qtscript-lto.sh` 在容器里原样可用。

**用途差异**：

| | CI（GitHub Actions） | 本 Docker |
|---|---|---|
| 目的 | 自动出产物、发 Release | 本地调试 / 定制编译 / 无网环境 |
| 触发 | 点按钮 / API | 你自己敲命令 |
| 源码 | 每次下载（有缓存） | 你放在 `/src`，可长期复用 |
| 好处 | 免维护、结果可复现 | 改参数不用等 CI、能用 ccache 反复试 |

> **两者不是替代关系**：日常出包走 CI；需要反复试错、或要编 CI 没覆盖的组合时，
> 用 Docker 在本地快速迭代。

---

## 九、文件清单

```
docker/
├── README.md               ← 本文档
├── Dockerfile.modern       Ubuntu 22.04 可编译环境（glibc 2.35）
├── Dockerfile.legacy       AlmaLinux 8 可编译环境（glibc 2.28）
├── docker-compose.yml      两条线的 compose 定义
├── build.sh                构建镜像（./build.sh [modern|legacy|all]）
└── run.sh                  进入容器或执行命令（./run.sh [modern|legacy] [-- 命令]）
```

构建后宿主机还会多出（已在 `.gitignore` 忽略）：

```
docker/src/                 Qt 源码包与解包目录
docker/build/               构建目录
```