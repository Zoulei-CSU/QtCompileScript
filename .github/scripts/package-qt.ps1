# =============================================================================
# package-qt.ps1 —— 精简安装树 + 打包 + 生成校验文件 (Windows)
#
# 输入环境变量同 package-qt.sh
# =============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Get-EnvOr {
    param([string]$Name, [string]$Default)
    $v = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($v)) { return $Default }
    return $v
}
function Write-Log { param([string]$M) Write-Host "[package-qt] $M" -ForegroundColor Cyan }
function Write-Warn2 { param([string]$M) Write-Host "[package-qt][警告] $M" -ForegroundColor Yellow }

$QT_PREFIX         = Get-EnvOr "QT_PREFIX" ""
$QT_VERSION        = Get-EnvOr "QT_VERSION" "unknown"
$QT_PLATFORM       = Get-EnvOr "QT_PLATFORM" "unknown"
$QT_BUILD_TYPE     = Get-EnvOr "QT_BUILD_TYPE" "release"
$QT_SOURCE_PACKAGE = Get-EnvOr "QT_SOURCE_PACKAGE" "qtbase"
$QT_PACK_MODE      = Get-EnvOr "QT_PACK_MODE" "dev-lite"
$QT_OUTPUT_DIR     = Get-EnvOr "QT_OUTPUT_DIR" (Join-Path (Get-Location) "dist")
$QT_ARTIFACT_NAME  = Get-EnvOr "QT_ARTIFACT_NAME" "Qt-$QT_VERSION-$QT_PLATFORM-$QT_BUILD_TYPE"

if (-not (Test-Path $QT_PREFIX)) { Write-Error "安装前缀不存在: $QT_PREFIX"; exit 1 }
if (-not (Test-Path $QT_OUTPUT_DIR)) { New-Item -ItemType Directory -Path $QT_OUTPUT_DIR -Force | Out-Null }

# ---------------------------------------------------------------------------
# 瘦身（可选）：这是【开发包】，必须保留 include/.prl/.cmake/mkspecs 等开发文件，
#   仅剔除"体积巨大且与开发无关"的纯文档与示例源码。
#     dev-lite  （默认）: 剔除 doc/ 与 examples/demos 源码，保留所有开发/运行文件
#     dev-full          : 保留全部文件，原样打包（含文档与示例）
#   绝不删除：include/ *.prl *.la lib/cmake/** mkspecs/ bin/ plugins/ qml/ 等
# ---------------------------------------------------------------------------
if ($QT_PACK_MODE -in @("runtime-only", "dev-lite", "lite")) {
    Write-Log "瘦身模式(dev-lite)：仅剔除 doc/ 与 examples/demos 源码，保留全部开发文件"

    # Qt 自带 HTML 文档（仅删顶层 doc/，不碰 include 下的任何东西）
    Get-ChildItem $QT_PREFIX -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "doc" } |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

    # 示例 / 演示 源码目录
    Get-ChildItem $QT_PREFIX -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @("examples", "demos") } |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

    # 编译中间产物（正常不含）
    Get-ChildItem $QT_PREFIX -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".o", ".obj") } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Log "瘦身完成"
}
elseif ($QT_PACK_MODE -in @("full", "dev-full")) {
    Write-Log "完整模式(dev-full)：保留全部文件（含文档与示例）"
}
else {
    Write-Warn2 "未知 pack_mode '$QT_PACK_MODE'，按完整模式处理"
}

# ---------------------------------------------------------------------------
# 安全校验：确保开发必需文件没有被误删（缺失则直接报错）
# ---------------------------------------------------------------------------
$incDir = Join-Path $QT_PREFIX "include"
if (-not (Test-Path $incDir)) {
    Write-Host ""
    Write-Host "[package-qt][致命] include/ 目录缺失！产物将无法用于开发编译。" -ForegroundColor Red
    Write-Host "  请检查是否有步骤误删头文件。" -ForegroundColor Red
    exit 1
}
Write-Log "开发文件校验通过：include/ 存在"

# ---------------------------------------------------------------------------
# BUILD-INFO.txt
# ---------------------------------------------------------------------------
$buildInfo = Join-Path $QT_OUTPUT_DIR "BUILD-INFO.txt"
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$cores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
$memGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

@(
    "===== Qt 编译信息 / BUILD INFO ====="
    "版本      : $QT_VERSION"
    "平台      : $QT_PLATFORM"
    "构建类型  : $QT_BUILD_TYPE"
    "源码粒度  : $QT_SOURCE_PACKAGE"
    "打包模式  : $QT_PACK_MODE"
    "构建时间  : $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC"
    "Runner    : $env:RUNNER_OS / $env:RUNNER_ARCH / $env:RUNNER_NAME"
    "Commit    : $env:GITHUB_SHA"
    "RunID     : $env:GITHUB_RUN_ID #$env:GITHUB_RUN_NUMBER"
    "编译耗时  : $env:QT_BUILD_SECONDS 秒"
    ""
    "---- configure 参数 ----"
    "$env:QT_CONFIGURE_ARGS"
    ""
    "---- 硬件环境 ----"
    "CPU       : $cpu"
    "核心数    : $cores"
    "内存      : $memGB GB"
) | Out-File -FilePath $buildInfo -Encoding utf8

# ---------------------------------------------------------------------------
# 打包 zip
# ---------------------------------------------------------------------------
$archive = Join-Path $QT_OUTPUT_DIR "$QT_ARTIFACT_NAME.zip"
Write-Log "打包 -> $QT_ARTIFACT_NAME.zip"

# 用 Compress-Archive 会较慢；优先 7z（runner 自带），否则 Compress-Archive
$sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
if ($sevenZip) {
    & 7z a -tzip -mx=6 "$archive" "$QT_PREFIX\*" | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "7z 打包失败，回退 Compress-Archive"; $sevenZip = $null }
}
if (-not $sevenZip) {
    $parent = Split-Path $QT_PREFIX -Parent
    $leaf   = Split-Path $QT_PREFIX -Leaf
    Compress-Archive -Path (Join-Path $parent $leaf) -DestinationPath $archive -CompressionLevel Optimal -Force
}

$arcBytes = (Get-Item $archive).Length
$arcMB = [math]::Round($arcBytes / 1MB, 1)
Write-Log "打包完成: $arcMB MB"

$maxBytes = 2GB - 1MB
if ($arcBytes -gt $maxBytes) {
    Write-Host ""
    Write-Host "[package-qt][严重警告] 产物 $arcMB MB 超过 GitHub Release 单资产 2GB 上限！" -ForegroundColor Red
    Write-Host "  建议：改用 pack_mode=dev-lite，或使用 7z 分卷压缩。" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# SHA256
# ---------------------------------------------------------------------------
Write-Log "生成 SHA256 校验文件"
$hash = (Get-FileHash -Path $archive -Algorithm SHA256).Hash.ToLower()
"$hash  $QT_ARTIFACT_NAME.zip" | Out-File -FilePath "$archive.sha256" -Encoding ascii

Write-Log "产物目录内容:"
Get-ChildItem $QT_OUTPUT_DIR | Format-Table Name, Length, LastWriteTime

if ($env:GITHUB_OUTPUT) {
    "archive=$archive"                                | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "archive_name=$QT_ARTIFACT_NAME.zip"              | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "artifact_name=$QT_ARTIFACT_NAME"                 | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}