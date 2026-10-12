# =============================================================================
# print-host-info.ps1 —— 打印编译机器的硬件资源与软件环境信息 (Windows)
#
# 用法: powershell -File print-host-info.ps1 [-OutFile <路径>]
# =============================================================================
[CmdletBinding()]
param(
    [string]$OutFile = ""
)

$ErrorActionPreference = "Continue"

$lines = New-Object System.Collections.Generic.List[string]

function Emit {
    param([string]$Text)
    Write-Host $Text
    $lines.Add($Text) | Out-Null
}

function Hr { Emit ("-" * 80) }

Emit ("=" * 80)
Emit " 编译主机环境信息 / BUILD HOST INFORMATION (Windows)"
Emit (" 生成时间 Generated at: " + (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss") + " UTC")
Emit ("=" * 80)

# -------- 基本信息 --------
Hr
Emit "[基本] 系统信息"
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    Emit ("  系统          : " + $os.Caption + " (" + $os.Version + ")")
    Emit ("  架构          : " + $os.OSArchitecture)
    $up = ((Get-Date) - $os.LastBootUpTime)
    Emit ("  已运行        : " + [math]::Round($up.TotalHours, 1) + " 小时")
} catch {
    Emit "  系统          : 查询失败 ($($_.Exception.Message))"
}
Emit ("  CI Runner     : " + "$env:RUNNER_OS / $env:RUNNER_ARCH / $env:RUNNER_NAME")
Emit ("  GitHub Job    : " + "$env:GITHUB_JOB  (run $env:GITHUB_RUN_ID #$env:GITHUB_RUN_NUMBER)")

# -------- CPU --------
Hr
Emit "[硬件] CPU"
try {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop
    Emit ("  型号          : " + ($cpu.Name -join '; '))
    Emit ("  物理核心数    : " + (($cpu | Measure-Object -Property NumberOfCores -Sum).Sum))
    Emit ("  逻辑核心数    : " + (($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum))
    Emit ("  最大主频      : " + $cpu.MaxClockSpeed + " MHz")
} catch {
    Emit ("  CPU 信息查询失败: " + $_.Exception.Message)
}

# -------- 内存 --------
Hr
Emit "[硬件] 内存"
try {
    $mem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $totalGB = [math]::Round($mem.TotalPhysicalMemory / 1GB, 2)
    Emit ("  物理内存      : " + $totalGB + " GB")
    $osMem = Get-CimInstance Win32_OperatingSystem
    Emit ("  可用内存      : " + [math]::Round($osMem.FreePhysicalMemory / 1MB, 2) + " GB")
    $suggest = [math]::Floor($totalGB / 2)
    Emit ("  -> 用于 nmake/msbuild 的建议并行度: " + [math]::Max(1, $suggest))
} catch {
    Emit ("  内存信息查询失败: " + $_.Exception.Message)
}

# -------- 磁盘 --------
Hr
Emit "[硬件] 磁盘"
try {
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $freeGB  = [math]::Round($_.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($_.Size / 1GB, 2)
        Emit ("  {0}  可用 {1} GB / 总计 {2} GB" -f $_.DeviceID, $freeGB, $totalGB)
    }
    $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    if ($c) {
        $freeGB = [math]::Round($c.FreeSpace / 1GB, 2)
        if ($freeGB -lt 40) {
            Emit "  !! 警告: C 盘可用空间不足 40GB，qt-everywhere 全量编译可能失败"
        }
    }
} catch {
    Emit ("  磁盘信息查询失败: " + $_.Exception.Message)
}

# -------- 编译器 --------
Hr
Emit "[软件] 编译器 / 构建工具"

function Try-Version {
    param([string]$Name, [string]$Cmd, [string[]]$Args = @("--version"))
    try {
        $v = & $Cmd @Args 2>$null | Select-Object -First 1
        if ($v) {
            Emit ("  {0,-14}: {1}" -f $Name, $v)
        } else {
            Emit ("  {0,-14}: 未安装/未激活" -f $Name)
        }
    } catch {
        Emit ("  {0,-14}: 未安装/未激活" -f $Name)
    }
}

Try-Version "cl (MSVC)"  "cl"      @()
Try-Version "clang"      "clang"   @("--version")
Try-Version "gcc"        "gcc"     @("--version")
Try-Version "nmake"      "nmake"   @("/?")
Try-Version "cmake"      "cmake"   @("--version")
Try-Version "ninja"      "ninja"   @("--version")
Try-Version "ccache"     "ccache"  @("--version")
Try-Version "perl"       "perl"    @("--version")
Try-Version "python"     "python"  @("--version")
Try-Version "7z"         "7z"      @()

Emit ""
Emit "  --- Visual Studio 安装探测 ---"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    try {
        $installs = & $vswhere -all -products * -format json 2>$null | ConvertFrom-Json
        foreach ($i in $installs) {
            Emit ("  VS: " + $i.displayName + "  [" + $i.installationVersion + "]  " + $i.installationPath)
        }
    } catch {
        Emit ("  vswhere 执行失败: " + $_.Exception.Message)
    }
} else {
    Emit "  未找到 vswhere（可能未安装 VS）"
}

Hr
Emit ("=" * 80 + " 环境信息结束 " + ("=" * 80))

if ($OutFile -ne "") {
    $lines | Out-File -FilePath $OutFile -Encoding utf8
    Write-Host "环境信息已写入: $OutFile"
}