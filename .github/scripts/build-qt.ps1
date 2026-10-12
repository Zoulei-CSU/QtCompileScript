# =============================================================================
# build-qt.ps1 —— Windows 上 configure + nmake + install Qt
#
# 输入环境变量：
#   QT_SRC_DIR         源码根目录
#   QT_BUILD_DIR       构建目录
#   QT_PREFIX          安装前缀
#   QT_MAJOR           5 | 6
#   QT_CONFIGURE_ARGS  configure 参数串
#   QT_JOBS            并行度（默认按 CPU/内存推算）
#   QT_USE_CCACHE      true | false
#   QT_SOURCE_PACKAGE  qtbase | qt-everywhere
#   QT_PLATFORM        windows-msvc2022 / windows-mingw ...
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

function Write-Step {
    param([string]$Msg)
    Write-Host ""
    Write-Host "==================== $Msg ====================" -ForegroundColor Cyan
}
function Write-Warn2 {
    param([string]$Msg)
    Write-Host "[警告] $Msg" -ForegroundColor Yellow
}

$QT_SRC_DIR         = Get-EnvOr "QT_SRC_DIR" ""
$QT_BUILD_DIR       = Get-EnvOr "QT_BUILD_DIR" (Join-Path (Get-Location) "build")
$QT_PREFIX          = Get-EnvOr "QT_PREFIX" "D:\Qt"
$QT_MAJOR           = Get-EnvOr "QT_MAJOR" "5"
$QT_CONFIGURE_ARGS  = Get-EnvOr "QT_CONFIGURE_ARGS" ""
$QT_USE_CCACHE      = Get-EnvOr "QT_USE_CCACHE" "true"
$QT_SOURCE_PACKAGE  = Get-EnvOr "QT_SOURCE_PACKAGE" "qtbase"
$QT_PLATFORM        = Get-EnvOr "QT_PLATFORM" "windows-msvc2022"
$QT_JOBS            = Get-EnvOr "QT_JOBS" ""

if ($QT_SRC_DIR -eq "" -or -not (Test-Path $QT_SRC_DIR)) {
    Write-Error "源码目录不存在: $QT_SRC_DIR"
    exit 1
}

# ---------------------------------------------------------------------------
# 并行度推算
# ---------------------------------------------------------------------------
if ($QT_JOBS -eq "") {
    $cores = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $memGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $memLimit = [math]::Max(1, [math]::Floor($memGB / 2))
    $QT_JOBS = [string][math]::Min($cores, $memLimit)
    Write-Host "自动推算并行度: CPU=$cores 核, 内存=$memGB GB -> 并行 $QT_JOBS"
}
Write-Host "并行度: $QT_JOBS"

# ---------------------------------------------------------------------------
# ccache（Windows 上 ccache 支持 MSVC/Clang；对 cl.exe 效果有限但仍有收益）
# ---------------------------------------------------------------------------
if ($QT_USE_CCACHE.ToLower() -eq "true") {
    $ccache = Get-Command ccache -ErrorAction SilentlyContinue
    if ($ccache) {
        $env:CCACHE_DIR = if ($env:CCACHE_DIR) { $env:CCACHE_DIR } else { "$HOME\.ccache" }
        $env:CCACHE_MAXSIZE = "5G"
        $env:CCACHE_COMPRESS = "1"
        if (-not (Test-Path $env:CCACHE_DIR)) { New-Item -ItemType Directory -Path $env:CCACHE_DIR -Force | Out-Null }
        & ccache --show-stats
        Write-Host "ccache 已启用: $env:CCACHE_DIR"
    } else {
        Write-Warn2 "指定启用 ccache 但未找到，已跳过"
    }
}

# ---------------------------------------------------------------------------
# 进入构建目录
# ---------------------------------------------------------------------------
if (-not (Test-Path $QT_BUILD_DIR)) { New-Item -ItemType Directory -Path $QT_BUILD_DIR -Force | Out-Null }
Set-Location $QT_BUILD_DIR

$configureDir = $QT_SRC_DIR
if ($QT_SOURCE_PACKAGE -eq "qtbase" -and (Test-Path (Join-Path $QT_SRC_DIR "qtbase"))) {
    if (-not (Test-Path (Join-Path $QT_SRC_DIR "configure.bat"))) {
        $configureDir = Join-Path $QT_SRC_DIR "qtbase"
    }
}

# ---------------------------------------------------------------------------
# Configure
# ---------------------------------------------------------------------------
Write-Step "Configure"
$t0 = Get-Date

$configureBat = Join-Path $configureDir "configure.bat"
if (Test-Path $configureBat) {
    # 用 cmd 执行，保证 ^ 续行与批处理语义正确
    $cmdLine = "`"$configureBat`" $QT_CONFIGURE_ARGS"
    Write-Host "执行: $cmdLine"
    cmd /c "$cmdLine 2>&1" | Tee-Object -FilePath "configure.log"
    if ($LASTEXITCODE -ne 0) { Write-Error "configure 失败 (退出码 $LASTEXITCODE)"; exit $LASTEXITCODE }
} else {
    Write-Warn2 "未找到 configure.bat，改用 cmake"
    cmake -S $configureDir -B $QT_BUILD_DIR -G "Ninja" `
        -DCMAKE_BUILD_TYPE=Release `
        -DCMAKE_INSTALL_PREFIX="$QT_PREFIX" `
        -DQT_BUILD_TESTS=OFF -DQT_BUILD_EXAMPLES=OFF 2>&1 | Tee-Object -FilePath "configure.log"
    if ($LASTEXITCODE -ne 0) { Write-Error "cmake configure 失败"; exit $LASTEXITCODE }
}
$configureSec = [int]((Get-Date) - $t0).TotalSeconds
Write-Host "configure 完成，耗时 ${configureSec}s"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
Write-Step "Build (并行 $QT_JOBS)"
$t0 = Get-Date

$useNinja = Test-Path "build.ninja"
if ($useNinja) {
    ninja -j $QT_JOBS 2>&1 | Tee-Object -FilePath "build.log"
    $rc = $LASTEXITCODE
    $installCmd = "ninja install"
} else {
    nmake /nologo 2>&1 | Tee-Object -FilePath "build.log"
    $rc = $LASTEXITCODE
    $installCmd = "nmake /nologo install"
}
if ($rc -ne 0) { Write-Error "编译失败 (退出码 $rc)"; exit $rc }
$buildSec = [int]((Get-Date) - $t0).TotalSeconds
Write-Host "编译完成，耗时 $([math]::Round($buildSec/60,1)) 分钟"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
Write-Step "Install -> $QT_PREFIX"
$t0 = Get-Date
cmd /c "$installCmd 2>&1" | Tee-Object -FilePath "install.log"
if ($LASTEXITCODE -ne 0) { Write-Error "安装失败"; exit $LASTEXITCODE }
$installSec = [int]((Get-Date) - $t0).TotalSeconds

# ---------------------------------------------------------------------------
# 摘要
# ---------------------------------------------------------------------------
if ($QT_USE_CCACHE.ToLower() -eq "true" -and (Get-Command ccache -ErrorAction SilentlyContinue)) {
    Write-Host "ccache 统计:"
    & ccache --show-stats
}

$sizeInfo = "n/a"
if (Test-Path $QT_PREFIX) {
    $sz = (Get-ChildItem $QT_PREFIX -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $sizeInfo = "{0:N2} GB" -f ($sz / 1GB)
}

Write-Step "构建摘要"
Write-Host "  configure : ${configureSec}s"
Write-Host "  build     : ${buildSec}s"
Write-Host "  install   : ${installSec}s"
Write-Host "  安装体积  : $sizeInfo"

if ($env:GITHUB_OUTPUT) {
    "build_seconds=$buildSec"     | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "configure_seconds=$configureSec" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "install_seconds=$installSec" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}