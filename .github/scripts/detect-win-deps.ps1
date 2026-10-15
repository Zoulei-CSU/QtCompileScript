# =============================================================================
# detect-win-deps.ps1 —— 在 Windows runner 上探测 OpenSSL / PostgreSQL 的安装位置
#
# 为什么需要这个脚本：
#   Qt6 走 CMake，自带 FindOpenSSL / FindPostgreSQL，能自动在
#   C:\Program Files\OpenSSL、C:\Program Files\PostgreSQL\<ver> 下找到依赖。
#   Qt5 走 qmake 体系，**只认编译器全局搜索路径**，不会自动去这两个目录找，
#   于是 configure 报：
#       openssl/ssl.h not found in [] and global paths.
#       ERROR: Feature 'openssl-linked' ... pre-condition '... libs.openssl' failed.
#   （run 38375939083 <|place_holder_mm_span_0442|> qtdrivers：PostgreSQL 同理，静默变成 no）
#
#   解决：在编译前把这两个依赖的 prefix 探测出来，交给 gen-configure-args.ps1，
#   由它以 `OPENSSL_PREFIX=... PSQL_PREFIX=...` 赋值形式传给 Qt5 configure。
#
# 输出（写入 $GITHUB_OUTPUT，供后续 step 使用）：
#   openssl_prefix   例：C:\Program Files\OpenSSL
#   openssl_incdir   例：C:\Program Files\OpenSSL\include
#   openssl_libdir   例：C:\Program Files\OpenSSL\lib\VC\x64\MD
#   psql_prefix      例：C:\Program Files\PostgreSQL\14
#   psql_incdir      例：C:\Program Files\PostgreSQL\14\include
#   psql_libdir      例：C:\Program Files\PostgreSQL\14\lib
#
# 探测策略：以「真实文件是否存在」为准（ssl.h / ssl.lib / libpq-fe.h / libpq.lib），
#   逐个候选目录验证，绝不凭空拼路径就当真。
# =============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Log { param([string]$Msg) Write-Host "[detect-win-deps] $Msg" }

function Set-Out {
    param([string]$Key, [string]$Value)
    if ($env:GITHUB_OUTPUT) { "$Key=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8 }
    Write-Log "$Key = $Value"
}

# 把可能含空格的路径转成 8.3 短路径（C:\Program Files -> C:\PROGRA~1）。
# 为什么必须这么做：这些路径最终要作为 `OPENSSL_INCDIR="C:\Program Files\..."` 这样的
#   configure 赋值参数，经 build-qt.ps1 的 `cmd /c "..."` 执行。cmd 对内嵌引号的处理极不可靠，
#   一旦引号被吞掉，带空格的路径就会被拆成两段，configure 直接报未知参数。
#   用短路径就没有空格，彻底绕开引号问题。
# 实现：优先用 Scripting.FileSystemObject（COM，最稳，不需要 cmd/引号）；
#   失败再退回 cmd 的 for/%~sA；都失败则原样返回并告警。
function Get-ShortPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) { return $Path }
    try {
        $fso = New-Object -ComObject Scripting.FileSystemObject
        if (Test-Path $Path -PathType Container) {
            $short = $fso.GetFolder($Path).ShortPath
        } else {
            $short = $fso.GetFile($Path).ShortPath
        }
        if (-not [string]::IsNullOrWhiteSpace($short) -and (Test-Path $short)) {
            if ($short -ne $Path) { Write-Log "短路径: $Path -> $short" }
            return $short
        }
    } catch { }
    try {
        $short = (& cmd /c "for %A in (`"$Path`") do @echo %~sA" 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($short) -and (Test-Path $short)) { return $short.Trim() }
    } catch { }
    Write-Log "::warning::无法为含空格路径生成 8.3 短名: $Path（将按原样传递，configure 可能因引号问题失败）"
    return $Path
}

# ---------------------------------------------------------------------------
# OpenSSL
#   runner 上常见布局（由 choco / 官方安装器安装）：
#     C:\Program Files\OpenSSL            <- 官方 "OpenSSL Light" 安装器（含 include/lib/VC/x64/MD）
#     C:\Program Files\OpenSSL-Win64      <- slproweb Win64 安装器
#   库文件可能是 .lib（import）或 .dll 同目录。以 include\openssl\ssl.h 为「锚」判定。
# ---------------------------------------------------------------------------
Write-Log "探测 OpenSSL ..."
$opensslCandidates = @(
    "C:\Program Files\OpenSSL",
    "C:\Program Files\OpenSSL-Win64",
    "C:\OpenSSL-Win64",
    "C:\OpenSSL"
)
# 也接受环境变量指定（用户可在触发面板用 extra args 之外的途径覆盖）
foreach ($e in @($env:OPENSSL_ROOT_DIR, $env:OPENSSL_DIR)) {
    if (-not [string]::IsNullOrWhiteSpace($e)) { $opensslCandidates = @($e) + $opensslCandidates }
}

$opensslPrefix = $null
foreach ($p in $opensslCandidates) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $hdr = Join-Path $p "include\openssl\ssl.h"
    if (Test-Path $hdr) { $opensslPrefix = $p; break }
}

if ($opensslPrefix) {
    $inc = Join-Path $opensslPrefix "include"
    # 库目录在官方安装器里通常是 lib\VC\x64\MD（或 \MT）；逐个候选，取第一个含 ssl.lib 的
    $libCandidates = @(
        (Join-Path $opensslPrefix "lib\VC\x64\MD"),
        (Join-Path $opensslPrefix "lib\VC\x64\MDd"),
        (Join-Path $opensslPrefix "lib\VC\x64\MT"),
        (Join-Path $opensslPrefix "lib\VC\x64\static"),
        (Join-Path $opensslPrefix "lib\VC\static"),
        (Join-Path $opensslPrefix "lib64"),
        (Join-Path $opensslPrefix "lib"),
        (Join-Path $opensslPrefix "lib64\VC\x64\MD")
    )
    # 判定目录可用：里面必须有 import lib（libssl.lib 或 ssl.lib），供 MSVC 链接。
    $hasSsl = {
        param([string]$d)
        if ([string]::IsNullOrWhiteSpace($d) -or -not (Test-Path $d)) { return $false }
        return (Test-Path (Join-Path $d "libssl.lib")) -or (Test-Path (Join-Path $d "ssl.lib"))
    }
    $libDir = $null
    foreach ($lc in $libCandidates) {
        if (& $hasSsl $lc) { $libDir = $lc; break }
    }
    # 兜底：候选都不中时，在 <prefix>\lib 下递归找 libssl.lib/ssl.lib（不同安装器布局差异大）。
    if (-not $libDir) {
        $libRoot = Join-Path $opensslPrefix "lib"
        if (Test-Path $libRoot) {
            $hit = Get-ChildItem -Path $libRoot -Recurse -Include "libssl.lib","ssl.lib" -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($hit) { $libDir = $hit.DirectoryName }
        }
    }
    Write-Log "OpenSSL 头文件: $inc"
    if ($libDir) { Write-Log "OpenSSL 库目录: $libDir" } else { Write-Log "::warning::OpenSSL 头文件找到但未定位 ssl.lib/ libssl.lib，libdir 留空" }

    # 统一转 8.3 短路径：路径里那个 "Program Files" 的空格是引号地狱的根源。
    Set-Out "openssl_prefix" (Get-ShortPath $opensslPrefix)
    Set-Out "openssl_incdir" (Get-ShortPath $inc)
    Set-Out "openssl_libdir" ($(if ($libDir) { Get-ShortPath $libDir } else { "" }))
} else {
    Write-Log "::warning::未能在候选目录中找到 OpenSSL（include\openssl\ssl.h）。Qt5 configure 的 -openssl-linked 可能失败。"
    Set-Out "openssl_prefix" ""
    Set-Out "openssl_incdir" ""
    Set-Out "openssl_libdir" ""
}

# ---------------------------------------------------------------------------
# PostgreSQL
#   runner 上：C:\Program Files\PostgreSQL\<major>（服务 postgresql-x64-14），
#   头文件 include\libpq-fe.h，库 lib\libpq.lib。
#   也允许 PGROOT / PG_ROOT 环境变量覆盖。
# ---------------------------------------------------------------------------
Write-Log "探测 PostgreSQL ..."
$psqlCandidates = New-Object System.Collections.Generic.List[string]
foreach ($e in @($env:PGROOT, $env:PG_ROOT)) {
    if (-not [string]::IsNullOrWhiteSpace($e)) { $psqlCandidates.Add($e) }
}
$pgRoot = "C:\Program Files\PostgreSQL"
if (Test-Path $pgRoot) {
    # 取版本号最大的子目录（14、15、16 ...）
    $vers = Get-ChildItem -Directory $pgRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' } | Sort-Object { [int]$_.Name } -Descending
    foreach ($v in $vers) { $psqlCandidates.Add($v.FullName) }
}

$psqlPrefix = $null
$psqlLibDir = $null
foreach ($p in $psqlCandidates) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (-not (Test-Path (Join-Path $p "include\libpq-fe.h"))) { continue }
    # 头文件在：再确认库目录（lib\libpq.lib）。二者齐备才算探测成功。
    # 只有当 libdir 非空时，gen-configure-args 才会加 -sql-psql（缺库时加会 configure 报错）。
    $ld = Join-Path $p "lib"
    if ((Test-Path (Join-Path $ld "libpq.lib")) -or (Test-Path (Join-Path $ld "libpq.dll"))) {
        $psqlPrefix = $p; $psqlLibDir = $ld; break
    }
    Write-Log "找到 libpq-fe.h 于 $p 但缺少 lib\libpq.lib，继续查找下一个候选"
}

if ($psqlPrefix -and $psqlLibDir) {
    Set-Out "psql_prefix" (Get-ShortPath $psqlPrefix)
    Set-Out "psql_incdir" (Get-ShortPath (Join-Path $psqlPrefix "include"))
    Set-Out "psql_libdir" (Get-ShortPath $psqlLibDir)
} else {
    Write-Log "::warning::未找到可用的 PostgreSQL（需 include\libpq-fe.h 且 lib\libpq.lib）。本次不构建 QPSQL 驱动。"
    Set-Out "psql_prefix" ""
    Set-Out "psql_incdir" ""
    Set-Out "psql_libdir" ""
}