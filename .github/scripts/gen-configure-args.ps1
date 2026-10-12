# =============================================================================
# gen-configure-args.ps1 —— 根据工作流输入生成 Qt configure 参数串 (Windows)
#
# 与 gen-configure-args.sh 逻辑对齐，供 Windows runner 使用。
#
# 输入环境变量（与 shell 版同名）：
#   QT_MAJOR QT_VERSION QT_PLATFORM QT_BUILD_TYPE QT_ARCH QT_STATIC
#   QT_SKIP_MODULES QT_EXTRA_ARGS QT_PREFIX QT_OPENSSL_LINKED
#   QT_SQL_DRIVERS QT_THIRDPARTY_INCDIR QT_THIRDPARTY_LIBDIR
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

$QT_MAJOR        = Get-EnvOr "QT_MAJOR" "5"
$QT_VERSION      = Get-EnvOr "QT_VERSION" "5.15.17"
$QT_PLATFORM     = Get-EnvOr "QT_PLATFORM" "windows-msvc2022"
$QT_BUILD_TYPE   = Get-EnvOr "QT_BUILD_TYPE" "release"
$QT_ARCH         = Get-EnvOr "QT_ARCH" "x86_64"
$QT_STATIC       = Get-EnvOr "QT_STATIC" "false"
$QT_SKIP_MODULES = Get-EnvOr "QT_SKIP_MODULES" "qtdoc,qt3d,qtwebengine,qtwebview"
$QT_EXTRA_ARGS   = Get-EnvOr "QT_EXTRA_ARGS" ""
$QT_PREFIX       = Get-EnvOr "QT_PREFIX" "D:\Qt\$QT_VERSION"
$QT_OPENSSL      = Get-EnvOr "QT_OPENSSL_LINKED" "true"
$QT_SQL_DRIVERS  = Get-EnvOr "QT_SQL_DRIVERS" ""
$QT_TP_INC       = Get-EnvOr "QT_THIRDPARTY_INCDIR" ""
$QT_TP_LIB       = Get-EnvOr "QT_THIRDPARTY_LIBDIR" ""

$args = New-Object System.Collections.Generic.List[string]

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
if ($QT_SKIP_MODULES -ne "") {
    foreach ($m in ($QT_SKIP_MODULES -split ",")) {
        $t = $m.Trim()
        if ($t -ne "") { $args.Add("-skip"); $args.Add($t) }
    }
}

# -------- 精简产物 --------
$args.Add("-nomake"); $args.Add("tests")
$args.Add("-nomake"); $args.Add("examples")
$args.Add("-no-compile-examples")

# -------- 平台 --------
if ($QT_PLATFORM -like "windows-*") {
    $args.Add("-verbose")
    if ($QT_MAJOR -eq "5") {
        $args.Add("-platform"); $args.Add("win32-msvc")
        $args.Add("-mp"); $args.Add("-no-icu")
        $args.Add("-qt-zlib"); $args.Add("-qt-freetype"); $args.Add("-qt-harfbuzz")
        $args.Add("-qt-libpng"); $args.Add("-qt-libjpeg"); $args.Add("-qt-sqlite")
        $args.Add("-opengl"); $args.Add("dynamic")
        $args.Add("-gui"); $args.Add("-widgets")
    } else {
        $args.Add("-mp")
        $args.Add("-qt-zlib"); $args.Add("-qt-freetype"); $args.Add("-qt-harfbuzz")
        $args.Add("-qt-libpng"); $args.Add("-qt-libjpeg"); $args.Add("-qt-sqlite")
    }
    if ($QT_PLATFORM -like "*msvc*") {
        $args.Add("-DCMAKE_GENERATOR_PLATFORM=x64")
    }
} else {
    Write-Log "警告: Windows 上遇到非 windows 平台 '$QT_PLATFORM'"
}

# -------- OpenSSL --------
if ($QT_OPENSSL.ToLower() -eq "true") { $args.Add("-openssl-linked") }
else { $args.Add("-openssl-runtime") }

# -------- SQL 驱动 --------
if ($QT_SQL_DRIVERS -ne "") {
    foreach ($d in ($QT_SQL_DRIVERS -split ",")) {
        $t = $d.Trim()
        if ($t -ne "") { $args.Add("-sql-$t") }
    }
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