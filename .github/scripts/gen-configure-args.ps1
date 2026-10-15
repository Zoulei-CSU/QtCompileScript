# =============================================================================
# gen-configure-args.ps1 —— 根据工作流输入生成 Qt configure 参数串 (Windows)
#
# 与 gen-configure-args.sh 逻辑对齐，供 Windows runner 使用。
#
# 输入环境变量（与 shell 版同名）：
#   QT_MAJOR QT_VERSION QT_PLATFORM QT_BUILD_TYPE QT_ARCH QT_STATIC
#   QT_SKIP_MODULES QT_EXTRA_ARGS QT_PREFIX QT_OPENSSL_LINKED
#   QT_SQL_DRIVERS QT_THIRDPARTY_INCDIR QT_THIRDPARTY_LIBDIR
#   QT_SOURCE_PACKAGE（qtbase | qt-everywhere，决定 -skip 是否生效）
#   QT_OPENSSL_INCDIR QT_OPENSSL_LIBDIR（Windows Qt5：OpenSSL 路径，由探测步骤提供）
#   QT_PSQL_INCDIR QT_PSQL_LIBDIR      （Windows Qt5：PostgreSQL 路径，由探测步骤提供）
#
# ---------------------------------------------------------------------------
# 【Qt5 / Qt6 选项差异速查】—— 传错会导致 configure FATAL_ERROR
# ---------------------------------------------------------------------------
# 仅 Qt5 有：-no-compile-examples  -verbose  -mp  -platform <mkspec>
#           -gui  -widgets  -no-angle
# 仅 Qt6 有：-feature-wayland / -no-feature-wayland
# 两边都有：-opengl <es2|desktop|dynamic>（Windows 默认 dynamic；本项目显式 desktop）
# ⚠️ `-D<str>` 是"预处理器宏定义"而非 CMake 变量；透传 CMake 变量须用 `-- -DXXX=yyy`。
# ⚠️ `-skip` 仅在 qt-everywhere 顶层构建生效，故按 QT_SOURCE_PACKAGE 门控。
# =============================================================================
[CmdletBinding()]
param(
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

function Get-EnvOr {
    param([string]$Name, [string]$Default)
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v
}

function Write-Log {
    param([string]$Msg)
    Write-Host "[gen-configure-args] $Msg"
}

# 生成 `VAR=value` 形式的 configure 赋值参数。
#   ⚠ 引号策略：这些参数最终经 build-qt.ps1 的 `cmd /c "configure.bat <args>"` 执行，
#     cmd 对内嵌引号的处理非常不可靠（开头引号会被吞、多个引号会错配）。
#     因此：只有当值里真的含空格时才加引号；不含空格就裸传。
#     配合 detect-win-deps.ps1 输出的 8.3 短路径（无空格），绝大多数情况都不会带引号，
#     从根上避开 cmd 的引号陷阱。
function New-Assign {
    param([string]$Name, [string]$Value)
    if ($Value -match '\s') { return "$Name=`"$Value`"" }
    return "$Name=$Value"
}

$QT_MAJOR        = Get-EnvOr "QT_MAJOR" "5"
$QT_VERSION      = Get-EnvOr "QT_VERSION" "5.15.17"
$QT_PLATFORM     = Get-EnvOr "QT_PLATFORM" "windows-msvc2022"
$QT_BUILD_TYPE   = Get-EnvOr "QT_BUILD_TYPE" "release"
$QT_ARCH         = Get-EnvOr "QT_ARCH" "x86_64"
$QT_STATIC       = Get-EnvOr "QT_STATIC" "false"
$QT_SOURCE_PACKAGE = Get-EnvOr "QT_SOURCE_PACKAGE" "qtbase"
$QT_SKIP_MODULES = Get-EnvOr "QT_SKIP_MODULES" "qtdoc,qt3d,qtwebengine,qtwebview,qtlocation"
$QT_EXTRA_ARGS   = Get-EnvOr "QT_EXTRA_ARGS" ""
$QT_PREFIX       = Get-EnvOr "QT_PREFIX" "D:\Qt\$QT_VERSION"
$QT_OPENSSL      = Get-EnvOr "QT_OPENSSL_LINKED" "true"
$QT_SQL_DRIVERS  = Get-EnvOr "QT_SQL_DRIVERS" ""
$QT_TP_INC       = Get-EnvOr "QT_THIRDPARTY_INCDIR" ""
$QT_TP_LIB       = Get-EnvOr "QT_THIRDPARTY_LIBDIR" ""
# Windows Qt5 专用：由 detect-win-deps.ps1 探测出的 OpenSSL / PostgreSQL 路径。
#   Qt6 走 CMake FindOpenSSL/FindPostgreSQL，会自动找到，无需这两个值；
#   Qt5 走 qmake，只认全局搜索路径，必须显式喂 *_INCDIR / *_LIBDIR。
$QT_OPENSSL_INC  = Get-EnvOr "QT_OPENSSL_INCDIR" ""
$QT_OPENSSL_LIB  = Get-EnvOr "QT_OPENSSL_LIBDIR" ""
$QT_PSQL_INC     = Get-EnvOr "QT_PSQL_INCDIR" ""
$QT_PSQL_LIB     = Get-EnvOr "QT_PSQL_LIBDIR" ""

$args = New-Object System.Collections.Generic.List[string]
# 需要透传给 CMake 的变量（-Dxxx=yyy）。Qt6 以 `-- -Dxxx=yyy` 追加到末尾。
# 注意：Qt 的 `-D<str>` 语义是"预处理器宏定义"，直接写 -Dxxx=yyy 会被当成宏。
$cmPt = New-Object System.Collections.Generic.List[string]

# -------- 通用 --------
$args.Add("-opensource"); $args.Add("-confirm-license")
$args.Add("-prefix"); $args.Add($QT_PREFIX)

# -------- 构建类型 --------
switch ($QT_BUILD_TYPE.ToLower()) {
    "release" { $args.Add("-release") }
    "debug"   { $args.Add("-debug") }
    "debug-and-release" {
        if ($QT_MAJOR -eq "5") { $args.Add("-debug-and-release") }
        else { Write-Log "警告: Qt6 不支持 debug-and-release，回退 -release"; $args.Add("-release") }
    }
    default { Write-Log "警告: 未知 build_type '$QT_BUILD_TYPE'，回退 -release"; $args.Add("-release") }
}

# -------- 静态/动态 --------
if ($QT_STATIC.ToLower() -eq "true") {
    $args.Add("-static")
    if ($QT_MAJOR -eq "6") { $args.Add("-static-runtime") }
} else {
    $args.Add("-shared")
}

# -------- 跳过模块 --------
# -skip 只在顶层构建（qt-everywhere）生效；单模块源码（qtbase）下传 -skip
# 只会产生 "only effective in top-level builds" 警告，故此处按源码粒度门控。
if ($QT_SOURCE_PACKAGE -eq "qt-everywhere" -and $QT_SKIP_MODULES -ne "") {
    foreach ($m in ($QT_SKIP_MODULES -split ",")) {
        $t = $m.Trim()
        if ($t -ne "") { $args.Add("-skip"); $args.Add($t) }
    }
} elseif ($QT_SKIP_MODULES -ne "") {
    Write-Log "非顶层构建（$QT_SOURCE_PACKAGE）：忽略 -skip 列表（该选项仅在 qt-everywhere 顶层生效）"
}

# -------- 精简产物 --------
# -nomake tests/examples : Qt5 / Qt6 均支持
# -no-compile-examples   : Qt5 独有；Qt6 configure 会报 "Unknown command line option"
$args.Add("-nomake"); $args.Add("tests")
$args.Add("-nomake"); $args.Add("examples")
if ($QT_MAJOR -eq "5") { $args.Add("-no-compile-examples") }

# -------- 平台 --------
if ($QT_PLATFORM -like "windows-*") {
    if ($QT_MAJOR -eq "5") {
        # Qt5：-verbose 打印详细日志；-platform 选 mkspec；-mp 多进程；
        #       -opengl desktop 锁定桌面 OpenGL（用 opengl32.dll），不打包 ANGLE。
        #       注意：不用 dynamic —— dynamic 会带回 ANGLE 回退分支，
        #       产物多一份 ANGLE 库且渲染走 D3D 翻译层；本项目明确要 Desktop。
        $args.Add("-verbose")
        $args.Add("-platform"); $args.Add("win32-msvc")
        $args.Add("-mp"); $args.Add("-no-icu")
        $args.Add("-qt-zlib"); $args.Add("-qt-freetype"); $args.Add("-qt-harfbuzz")
        $args.Add("-qt-libpng"); $args.Add("-qt-libjpeg"); $args.Add("-qt-sqlite")
        $args.Add("-opengl"); $args.Add("desktop")
        $args.Add("-no-angle")
        $args.Add("-gui"); $args.Add("-widgets")
    } else {
        # Qt6：没有 -verbose / -mp（并行交给 Ninja 生成器），也没有 -platform
        #      （mkspec 机制已废弃）。架构由 MSVC 开发环境（vcvars x64）决定。
        #      OpenGL：Windows 上 Qt6 默认是 dynamic（运行时加载 opengl32），
        #      仍支持 -opengl <es2|desktop|dynamic>；本项目锁定 desktop。
        #      注意 ANGLE 在 Qt6 已移除，无需（也不应）再写 -no-angle。
        $args.Add("-no-icu")
        $args.Add("-qt-zlib"); $args.Add("-qt-freetype"); $args.Add("-qt-harfbuzz")
        $args.Add("-qt-libpng"); $args.Add("-qt-libjpeg"); $args.Add("-qt-sqlite")
        $args.Add("-opengl"); $args.Add("desktop")
    }
} else {
    Write-Log "警告: Windows 上遇到非 windows 平台 '$QT_PLATFORM'"
}

# -------- OpenSSL --------
# Qt6：走 CMake 的 FindOpenSSL，会自动在 C:\Program Files\OpenSSL 下找到，
#       只需 -openssl-linked / -openssl-runtime 即可。
# Qt5：走 qmake 体系，**只认编译器全局搜索路径**，不会自动去 OpenSSL 安装目录找，
#       因此必须显式给出 OPENSSL_INCDIR / OPENSSL_LIBDIR（configure 的 VAR=value 赋值语法）。
#       否则 configure 会打印 "openssl/ssl.h not found in [] and global paths."，
#       最终报 "Feature 'openssl-linked' ... pre-condition '... libs.openssl' failed."
#       （run 38375939083 即此原因）。
if ($QT_OPENSSL.ToLower() -eq "true") { $args.Add("-openssl-linked") }
else { $args.Add("-openssl-runtime") }

if ($QT_MAJOR -eq "5") {
    if ($QT_OPENSSL_INC -ne "") { $args.Add((New-Assign "OPENSSL_INCDIR" $QT_OPENSSL_INC)) }
    if ($QT_OPENSSL_LIB -ne "") { $args.Add((New-Assign "OPENSSL_LIBDIR" $QT_OPENSSL_LIB)) }
    if ($QT_OPENSSL_INC -eq "" -and $QT_OPENSSL_LIB -eq "") {
        Write-Log "警告: Qt5 未获得 OpenSSL 路径（OPENSSL_INCDIR/LIBDIR 均为空），-openssl-linked 很可能失败"
    } else {
        Write-Log "Qt5 OpenSSL: INCDIR=$QT_OPENSSL_INC LIBDIR=$QT_OPENSSL_LIB"
    }
}

# -------- SQL 驱动 --------
# Qt5：PostgreSQL 驱动必须显式 -sql-psql，且需 PSQL_INCDIR / PSQL_LIBDIR（同 OpenSSL 的道理，
#      Qt5 不会自动去 C:\Program Files\PostgreSQL\<ver> 找）。
#      ⚠ 只在「确实探测到 libpq」时才加 -sql-psql：显式请求的 feature 若条件不满足，
#        Qt5 configure 会直接报错退出，而不是静默关闭。
$sqlDrivers = New-Object System.Collections.Generic.List[string]
foreach ($d in ($QT_SQL_DRIVERS -split ",")) {
    $t = $d.Trim()
    if ($t -ne "") { $sqlDrivers.Add($t) }
}
if ($QT_MAJOR -eq "5" -and $QT_PSQL_LIB -ne "" -and -not $sqlDrivers.Contains("psql")) {
    $sqlDrivers.Add("psql")
}
foreach ($d in $sqlDrivers) { $args.Add("-sql-$d") }

if ($QT_MAJOR -eq "5" -and $sqlDrivers.Contains("psql")) {
    if ($QT_PSQL_INC -ne "") { $args.Add((New-Assign "PSQL_INCDIR" $QT_PSQL_INC)) }
    if ($QT_PSQL_LIB -ne "") { $args.Add((New-Assign "PSQL_LIBDIR" $QT_PSQL_LIB)) }
    Write-Log "Qt5 PostgreSQL: INCDIR=$QT_PSQL_INC LIBDIR=$QT_PSQL_LIB"
}

# -------- 三方库路径 --------
foreach ($i in ($QT_TP_INC -split ",")) {
    $t = $i.Trim(); if ($t -ne "") { $args.Add("-I`"$t`"") }
}
foreach ($l in ($QT_TP_LIB -split ",")) {
    $t = $l.Trim(); if ($t -ne "") { $args.Add("-L`"$t`"") }
}

# -------- 用户追加 --------
if ($QT_EXTRA_ARGS -ne "") {
    foreach ($a in ($QT_EXTRA_ARGS -split "\s+")) {
        if ($a -ne "") { $args.Add($a) }
    }
}

# -------- CMake 变量透传（必须放最后，用 `--` 与 configure 选项分隔） --------
if ($cmPt.Count -gt 0) {
    $args.Add("--")
    foreach ($c in $cmPt) { $args.Add($c) }
    Write-Log ("CMake 透传参数: " + ($cmPt -join " "))
}

$argsStr = ($args -join " ")
Write-Log "生成的 configure 参数："
Write-Log "  $argsStr"

if ($env:GITHUB_OUTPUT) {
    "configure_args=$argsStr" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "prefix=$QT_PREFIX"       | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

if ($OutFile -ne "") {
    $argsStr | Out-File -FilePath $OutFile -Encoding utf8
}