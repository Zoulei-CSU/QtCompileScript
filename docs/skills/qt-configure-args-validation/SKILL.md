---
name: qt-configure-args-validation
description: Build, validate and VERIFY Qt5/Qt6 `configure` argument strings — offline validation catches the option mismatches that make Qt abort with "Unknown command line option 'X'", "Enabling/Disabling unknown feature 'X'", or "Forcing to ON breaks its condition"; post-build verification reads the produced DLL/SO import tables to prove a feature (OpenSSL, libpq, Wayland, xcb, fontconfig) actually got linked. Trigger whenever you generate, edit, or debug Qt configure arguments (workflows, CI scripts, build automation), when a Qt build fails at the configure step, when a build succeeds but you must confirm a "启用/开启" requirement really took effect, or when you need to know which configure options are Qt5-only vs Qt6-only.
agent_created: true
---

# Qt configure 参数生成与离线校验

场景：你在写/改 CI 或构建脚本，要拼出一串 `configure` 参数去编 Qt5 或 Qt6。
**不要靠记忆拼**——拼错一个选项，configure 会立刻 `FATAL_ERROR` 退出，
而且**只报第一个错**，后面的雷你得再跑一轮才发现（一轮 CI = 几十分钟）。

## 🚫 铁律：不要在本机复现（用户强制要求）
- **绝对不要把本机当试验场**：不下源码、不编译、不装依赖、不做"等价小实验"
  （哪怕是 `mktemp` 里 `g++ -c` 一个 hello world 也不行）。
- **禁止擅自下载任何工具/二进制**到本机（例如去下 ccache 官方二进制来复现 bug）。
- **本机只允许**：改脚本 → `git commit` → `git push` → 触发 GitHub Actions →
  读云端 run 的状态/步骤/日志/产物。
- 想确认某个修复是否有效：**推一次、跑一次、看云端日志**，不要在本地重现。
- 无法在云端可靠验证时，明确告诉用户"此项未在云端验证"并请求其验证，
  **不要**退回本地试跑。
- 为什么：本地环境与 runner 不同，本地"能过"不代表 CI 能过；且用户明确禁止本机试验。

## 先记住三条硬规则

1. **`qtConfAddError` 是 `message(FATAL_ERROR)`，遇第一个非法选项即中断。**
   报错信息只反映第一个问题，不代表后面没有别的错。修完必须重新校验整串。
2. **`-D<str>` 不是 CMake 变量，而是"预处理器宏定义"**
   （`qt_commandline_prefix(D defines)`）。想透传 CMake 变量必须写
   `<选项...> -- -DCMAKE_XXX=yyy`，`--` 之后的参数才 verbatim 交给 CMake。
   写 `-DCMAKE_GENERATOR_PLATFORM=x64` 不会报错，但会被当成宏定义（静默错误）。
3. **`-skip` / 模块自己的选项只在顶层（qt-everywhere）构建生效。**
   用 `qtbase` 单模块源码时：
   - `-skip xxx` → 仅 warning `only effective in top-level builds`
   - 别的模块的选项（如 `-no-qml-debug` 属 qtdeclarative）→ 直接 `Unknown command line option`
   所以这类参数要按**源码粒度**门控。

## Qt5 vs Qt6 选项差异表（踩过的坑）

| 选项 | Qt5 | Qt6 | 备注 |
|---|---|---|---|
| `-no-compile-examples` | ✅ | ❌ | Qt6 用 `-nomake examples` 即可 |
| `-verbose` | ✅ | ❌ | Qt6 用 `-- -DCMAKE_VERBOSE_MAKEFILE=ON` 或忽略 |
| `-mp` | ✅ | ❌ | Qt6 并行交给生成器（Ninja `-j`） |
| `-platform <mkspec>` | ✅ | ❌ | Qt6 用 `-DCMAKE_...` / 工具链文件；mkspec 机制已废弃 |
| `-opengl dynamic` | ✅ | ❌ | Qt6 只有 `-opengl <es2\|desktop\|dynamic>` 形式，无 ANGLE |
| `-no-angle` | ✅ | ❌ | Qt6 无 `angle` 选项；ANGLE 已移除 |
| `-iconv` | ✅ | ❌ | Qt6 内置 iconv，无此开关 |
| `-gui` / `-widgets` | ✅ | ❌ | Qt6 用 `-no-feature-gui` 之类 |
| `-feature-wayland` / `-no-feature-wayland` | ❌ | ✅ | Qt5 的 wayland 是**独立模块 qtwayland**，靠"不 skip qtwayland"启用 |
| `-lclcase` `-nomake` `-ltcg` `-icu/-no-icu` | ✅ | ✅ | 两边都有 |
| `-libpng`（配 `-qt-` / `-system-` 前缀） | ✅ | ✅ | 三方库统一支持 `-qt-xxx` / `-system-xxx` |
| `-sql-<driver>` | ✅ | ✅ | 如 `-sql-psql` |
| `-xcb` / `-xcb-xlib` | ✅ | ✅ | Qt6 也有 |
| `-openssl-linked` / `-openssl-runtime` | ✅ | ✅ | 语义相同 |
| `-no-qml-debug` | ✅ | — | 属 **qtdeclarative**，仅 everywhere 顶层可用 |

> 注意 `-no-xxx` 走的是 `--?(disable|no)-(.*)` 分支，需要 `xxx` 本身是注册过的
> **commandline option**（如 `icu`、`angle`、`libpng`）。而 `-no-feature-xxx` 走
> feature 分支，查 `commandline_known_features`。两者不能混用：
> Qt6 里 `-no-icu` 合法，但要想关掉某个 feature 得用 `-no-feature-<name>`。

## 强制开启 feature 会**报错**（不是警告）

`-feature-wayland`、`-sql-psql` 这类会让 Qt 强制把 feature 置 ON。若其 `CONDITION`
不满足（例如没有 libwayland / libpq），`QtFeature.cmake` 会
`qt_configure_add_report_error("Feature ...: Forcing to ON breaks its condition")`
→ **configure 失败**。所以"开 feature 的开关"和"装依赖"必须成对出现。

## 校验流程（离线，不跑 configure）

用 Qt 官方源码里的选项定义当"字典"，逐 token 校验。**别用文档网页**——
`doc.qt.io` 的 configure-options 页是节选，`config_help.txt` 也可能滞后
（实测 Qt6.8 的 config_help.txt 就没列 `-opensource` / `-confirm-license`，
但它俩是合法的）。**权威来源是 `qt_cmdline.cmake`**。

```bash
# Qt6：通用选项 + 各模块选项（用 qt_cmdline.cmake，权威）
for f in qt_cmdline.cmake \
         src/corelib/qt_cmdline.cmake src/gui/qt_cmdline.cmake \
         src/network/qt_cmdline.cmake src/sql/qt_cmdline.cmake \
         src/plugins/sqldrivers/qt_cmdline.cmake src/widgets/qt_cmdline.cmake ; do
  curl -s "https://raw.githubusercontent.com/qt/qtbase/6.8/$f"
done | grep -oE 'qt_commandline_option\([A-Za-z0-9.+-]+' | sed 's/.*(//' | sort -u
# Qt6 显式在解析器里处理的：skip / skip-tests / skip-examples
# 再加前缀式：D I L F R

# Qt5：直接看 config_help.txt（含全部选项）
curl -s "https://raw.githubusercontent.com/qt/qtbase/5.15/config_help.txt"
# 模块级选项（如 qml-debug）在各自仓库：
#   https://raw.githubusercontent.com/qt/qtdeclarative/<branch>/src/qml/qt_cmdline.cmake

# Qt6 里 feature 名（用于 -feature-xxx 合法性）：
curl -s "https://raw.githubusercontent.com/qt/qtbase/6.8/src/gui/configure.cmake" \
  | grep -n 'qt_feature("'
```

然后把生成的参数串逐 token 比对：

- 以 `--` 分割：`--` 之前的每个 `-xxx` 必须是已知选项；之后的必须是 `-DXXX=yyy`
- `-no-feature-X` / `-feature-X` → X 必须在 feature 集合里
- `-no-X` → X 必须在 option 集合里
- `-qt-X` / `-system-X` → X 必须在 option 集合里
- `-DXXX=` 出现在 `--` 之前 → 报错（宏定义语义，几乎肯定是 bug）

完整可用实现见 `scripts/validate.py`（自包含：先联网拉字典，再校验）。

## 排查真实失败时的动作顺序

1. 从 run log 里找出**第一条** `CMake Error`（后面可能还有雷，别只看一条）。
2. 确认报错选项属哪个大版本 → 查上面的差异表 → 加版本门控。
3. **顺手把同串里其它"待验证"选项也一起核对**（因为第一错会挡住后面全部）。
   特别是：架构/平台类参数（`-DCMAKE_*`）、feature 开关（`-feature-x` / `-sql-x`）、
   模块专属选项（`-no-qml-debug`）。
4. 全串重跑离线校验，再改 CI。
5. 依赖与开关成对检查：`-feature-wayland` ⇒ 装了 libwayland-dev；
   `-sql-psql` ⇒ 装了 libpq-dev；`-openssl-linked` ⇒ 有 OpenSSL（含库，不只头文件）。

## 构建阶段的两个经典陷阱（与参数无关，但一样致命）

### 陷阱 A：Qt6 configure 强制 `-G Ninja`，但你却跑 `make`

Qt6 的 `configure` 是个 CMake 包装器，它会**自己追加 `-G Ninja`**（实测日志）：
```
cmake ... '-DFEATURE_sql_psql=ON' '-G' 'Ninja' /path/to/qtbase
```
所以构建目录里是 `build.ninja`，**没有 Makefile**。若构建脚本硬写
`make -j`，会在 configure 完全成功之后才报：
```
gmake: *** No targets specified and no makefile found.  Stop.
```
**这个报错极具迷惑性**——它出现在"编译"步骤，但真正的原因是生成器不匹配，
且 configure 日志看起来一切正常。

**正确做法：探测构建目录实际产物，不要靠大版本猜。**
```bash
if [[ -f "$BUILD_DIR/build.ninja" ]]; then BUILD_TOOL=ninja
elif [[ -f "$BUILD_DIR/Makefile" ]]; then BUILD_TOOL=make
else  # 兜底：Qt6 且 ninja 可用则 ninja
  ...
fi
"$BUILD_TOOL" -j"$JOBS"
"$BUILD_TOOL" install
```
> 跨平台脚本尤其要注意**功能对齐**：Windows 版用 nmake/ninja 分支、
> bash 版写死 make，就会出现"Windows 过、Linux 挂"的诡异现象。

### 陷阱 B：`config.summary` 里**没有 feature 条目** ≠ 未启用（且 grep 容易误判）

想验证某个 feature 是否真开了，去 grep `config.summary` 是常见做法，
但**只有被 `qt_configure_add_summary_entry(ARGS "<name>")` 登记过的
feature 才会以 "启用/未启用" 的 summary 条目形式出现**。

实例：`wayland` 在 qtbase 里是 PUBLIC feature
（`qt_feature("wayland" PUBLIC ... CONDITION TARGET Wayland::Client)`），
但 **qtbase 从头到尾没有为它加 summary entry**。

⚠️ **这里有个反直觉的坑（实测踩过）**：`config.summary` 里**仍然会出现
"wayland" 这个字样**（属别的栏目，如 `Qt Wayland` 之类的标题/模块行/注释）。
于是最朴素的判定写法会**假命中**：

```bash
# ❌ 错误写法：grep 命中了 summary 里别处的 wayland 字样 → 进入校验分支
if grep -qiE 'wayland' "$SUMMARY_FILE"; then
    _check_yes "Wayland" "Wayland" || true   # 找不到 "enabled: yes" 行 → 误报 [缺失]
fi
```

正确做法：**不要用 config.summary 判定这类未登记 feature**，改用"产物佐证"——
wayland 就看 install 后 `plugins/platforms/libqwayland-*.so` 是否真的产出：

```bash
WL=$(find "$QT_PREFIX/plugins/platforms" -maxdepth 1 -name 'libqwayland*.so' 2>/dev/null | wc -l)
[[ "$WL" -gt 0 ]] && echo "Wayland 插件已产出 ($WL)：" || echo "未产出 Wayland 插件"
```

⚠️ **但"产物佐证"必须带上模块归属判断（实测踩过）**：
Qt6 的 QPA 平台插件 `libqwayland*.so` 属于**独立模块 `qtwayland`**，
**不在 qtbase 里**。所以：
- **qtbase 单模块构建**：`plugins/platforms/` 只会有
  `libqminimal / libqoffscreen / libqxcb / libqeglfs / libqminimalegl /
  libqlinuxfb / libqvnc`，**本来就不该有 `libqwayland*.so`**。
  此时 `-feature-wayland` 只启用 qtbase 内部对 wayland 的支持
  （装了 `FindWayland.cmake` / `wayland-scanner.prf` 等构建期支撑文件，
  但不出 QPA 插件）——**缺失是正常的，不要告警**。
- **qt-everywhere 全量且未 skip qtwayland**：才应产出 `libqwayland*.so`，
  缺失才是真问题。

所以校验逻辑应写成（伪代码）：
```bash
if 插件存在; then 通过
elif 源码粒度==qt-everywhere 且 qtwayland 未被 skip; then 告警（真问题）
else 提示"本次粒度不含 qtwayland，缺失正常"; fi   # 别告警
```

排查方法：`grep -n 'qt_configure_add_summary_entry' <module>/configure.cmake`
确认目标 feature 是否登记。**没登记就别在校验里判它**（连 `grep <feature> summary`
这种"存在性"判断也别做，因为它可能因别处同名文字而假命中）。

## 构建后验证：产物**真的**链接了这个库吗？

**离线校验只保证「参数合法」，不保证「特性生效」。** 典型陷阱：

- `-openssl-linked` 若没找到 OpenSSL，Qt6 **不报错**，只是降级 → configure 全绿，
  产物里却没有 OpenSSL。
- configure 报告经常拿不到：Windows 上 `configure.bat` 的输出经
  `Tee-Object -FilePath configure.log` 落盘，job 日志里**未必完整回显**
  （实测拿不到）；Linux 上 `config.summary` 的位置随构建方式而变。
- `-feature-wayland` 这类强制开启会报错，但 `-sql-*` / `-openssl-*` 是"能开就开"。

**唯一不可抵赖的证据：直接读产物二进制的导入表。**

```bash
python scripts/verify_linked_libs.py <路径> --find openssl,psql,wayland
# 路径可以是：单个 dll/so、已解压的安装目录、.zip、.tar.xz
```

覆盖：
- **PE**（`.dll`/`.exe`）→ 解析 Import Directory Table
- **ELF**（`.so`）→ 解析 `PT_DYNAMIC` 的 `DT_NEEDED`（与 `readelf -d` 结果一致）

判读方法（Qt6 实测样例）：

| 想确认 | 看哪个文件 | 期望看到 |
|---|---|---|
| OpenSSL 链接成功 | `bin/Qt6Network.dll`（Linux: `lib/libQt6Network.so.6`） | `libcrypto-3-x64.dll` / `libcrypto.so.3` |
| PostgreSQL 驱动 | `plugins/sqldrivers/qsqlpsql.{dll,so}` | `LIBPQ.dll` / `libpq.so.5` |
| TLS 后端 | `plugins/tls/qopensslbackend.*` | 该文件存在 + 上面那条 |
| Wayland 平台插件 | `plugins/platforms/libqwayland-*.so` | `libwayland-client.so.0` |
| xcb 平台插件 | `plugins/platforms/libqxcb.so` | `libxcb.so.1` |
| 字体 | `lib/libQt6Gui.so.6` | `libfontconfig.so.1` |

**注意**：`-qt-<lib>`（内建）与 `-system-<lib>` 在导入表上表现不同——内建的不会
出现系统库名。所以"没查到"要先确认这一项本来就是系统库版本。

**另一个副作用要提醒用户**：`-openssl-linked` 会让 `Qt6Network.dll` **硬依赖**
`libssl-3-x64.dll` / `libcrypto-3-x64.dll`，而 Qt 产物**不含**这些 DLL。
目标机必须自己部署，否则程序起不来。想避免硬依赖就用 `-openssl-runtime`
（运行时动态加载，仍需 DLL，但不是硬导入）。

完整实现见 `scripts/verify_linked_libs.py`。

## CI 脚本自身的三个坑（不关乎 configure，但一样会浪费一轮 CI）

### 坑 1：`set -o pipefail` + `cmd | head` ⇒ 莫名的 `exit code 141`

`141 = 128 + 13`，是 **SIGPIPE**。典型现场：

```bash
set -euo pipefail
cat /etc/os-release | head -3      # ← 这一步让整个 job 报 141
```

`head` 读够 3 行就关掉管道，`cat` 再往已关闭的管道写 → 被 SIGPIPE 杀掉 → 退出 141。
`pipefail` 令整条管道取**第一个非零**退出码 → 判失败。**步骤报错位置在 `head` 上，
但真凶是上游命令被信号杀死**，看日志很难想到。

规避（任选，优先前两种）：
```bash
grep -m3 -E '^(NAME|VERSION|ID)=' /etc/os-release      # ✅ 首选：grep 自己限流
find dir -maxdepth 1 -mindepth 1 -type d -print -quit  # ✅ 替代 find | head -n1
{ ldd --version | head -n1 || true; }                  # ⚠️ 兜底：显式吞掉退出码
```
> 注意 `$(cmd | head -1)` 写在**命令替换**里时，退出码取自 `head`（0），
> pipefail 不参与 → 多数情况能过，但别依赖这个巧合，统一改掉最省心。

### 坑 2：`workflow_dispatch` 的 inputs schema 有**索引延迟**

刚 `git push` 完立刻调 `POST /repos/{r}/actions/workflows/{f}/dispatches`，
可能返回 **422 Unprocessable Entity**——不是输入错了，是 GitHub 还没重新索引
工作流定义。等几秒重试即可。自查方法：`GET` 同路径看 `inputs` 字段是否已含新键。

### 坑 3：读 job 日志会被 302 丢认证

`GET /repos/{r}/actions/jobs/{id}/logs` 会 **302 到带签名的 blob 存储地址**。
`urllib`/`requests` 自动跟随重定向时会把 `Authorization` 头带过去，而签名 URL
**不接受**该头 → **401 not authenticated**。
解法：禁止自动重定向，手工取 `Location`，再**不带认证头**拉取签名 URL。
（这也意味着签名 URL 本身即可公开读取，用完即弃。）

### 顺带：`gcc-toolset` / `devtoolset` 与 CRB 仓库

AlmaLinux 8（glibc 2.28）替代 CentOS7（glibc 2.17）做"老系统线"时：
- GitHub 已强制 Node20 系 action 跑 **Node 24**，要求 glibc ≥2.27/2.28，
  CentOS7 无解 → 抬高基线到 2.28 是业界通行做法（manylinux_2_28 / PyTorch）。
- 装依赖前先 `dnf config-manager --set-enabled powertools || ... crb`：
  `libdbusmenu-devel` / `libxkbcommon-x11-devel` / `libXcomposite-devel`
  只在 CRB/PowerTools 里，不启用会**整条 `dnf install` 失败**。
- `gcc-toolset-11` 等替代 `devtoolset-9`，激活方式不变（`scl enable`）。

## 陷阱 C：`-ltcg`（`-flto`）+ qtscript ⇒ `undefined reference to cti_vm_throw`

Qt5 带 `-ltcg` 编全量时，**qtscript 模块必然链接失败**：

```
ld: .../ltrans0.ltrans.o: in function `ctiVMThrowTrampoline':
    undefined reference to `cti_vm_throw'
gmake[3]: *** [Makefile:669: ../../lib/libQt5Script.so.5.15.19] Error 1
```

**定位要领**：失败步骤是"编译"，但报错模块是 qtscript —— 日志里往往**同时**滚动着
别的模块（如 qtlocation/mapbox-gl-native）的输出，极易误判。
**认准 `gmake: *** [Makefile:999: module-<名>-make_first] Error 2` 这一行**，
`module-` 后面才是真凶。

**根因（Qt 官方已知 bug，标记 Out of scope / Fix Version: None）**：
- QTBUG-42989；Gentoo #652158、#581024。
- `qtscript/src/3rdparty/javascriptcore/JavaScriptCore/jit/JITStubs.h` 中，
  `cti_vm_throw` 等由**全局内联汇编**定义，**只被汇编代码引用**；
  GCC 在 LTO 下看不到 C++ 引用 → 视作死代码丢弃 → 链接期符号缺失。
- **只在有 `-ltcg`/`-flto` 时触发**；关掉 LTO 即可规避。

**两条出路**：
1. 去掉 `-ltcg`（改动最小、最稳，代价是产物略大且无跨模块内联）。
2. 打补丁：给声明加 `__attribute__((used))` 强制保留符号
   （Gentoo/openEuler/PyTorch 生态通行做法）：
   ```c
   // 之前
   EncodedJSValue JIT_STUB cti_vm_throw(STUB_ARGS_DECLARATION);
   // 之后
   EncodedJSValue JIT_STUB cti_vm_throw(STUB_ARGS_DECLARATION) __attribute__((used));
   ```
   建议脚本化，且用**正则替换而非 `patch` 命令**（上游上下文漂移会让 patch 打不上），
   正则同时容忍"已打过 attribute"形态 → 天然幂等；文件缺失/模块被 skip 时安静跳过。
   参考实现：`patch-qtscript-lto.sh`。

**注意适用范围**：`-ltcg` 与 qtscript 都**只属 Qt5**（Qt6 已移除 qtscript），
所以补丁/开关不需要 Qt6 分支判断。
