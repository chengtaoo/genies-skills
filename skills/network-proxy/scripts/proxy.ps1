<#
.SYNOPSIS
  v2rayN Proxy Manager for OpenClaw AI Assistant
.DESCRIPTION
  Manages the v2rayN proxy: start, stop, status, test, and configure
  environment variables for CLI tools.
  
  CONFIGURATION: Create proxy-config.json in the same directory, or
  set environment variables V2RAYN_EXE / PROXY_PORT.
  If neither is provided, the script will auto-detect v2rayN.
.NOTES
  Portable version for distribution via genies-skills repository.
  No hardcoded paths or sensitive information.
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "stop", "status", "test", "env", "restart", "wait")]
    [string]$Action = "status",

    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 30,

    [Parameter(Mandatory=$false)]
    [string]$TestUrl = "https://www.google.com",

    [Parameter(Mandatory=$false)]
    [string]$V2rayNPath = "",

    [Parameter(Mandatory=$false)]
    [int]$ProxyPort = 0
)

# ─── Configuration Resolution ────────────────────────────────────

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "proxy-config.json"

# Try loading from config file
$config = $null
if (Test-Path $ConfigFile) {
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    } catch {
        # Ignore malformed config
    }
}

# Resolve v2rayN path: param > env var > config file > auto-detect
function Resolve-V2rayNPath {
    param([string]$ExplicitPath, $Config)

    # 1. Command-line parameter
    if ($ExplicitPath -and (Test-Path $ExplicitPath)) { return $ExplicitPath }

    # 2. Environment variable
    $envPath = $env:V2RAYN_EXE
    if ($envPath -and (Test-Path $envPath)) { return $envPath }

    # 3. Config file
    $cfgPath = $Config.v2rayN_exe
    if ($cfgPath -and (Test-Path $cfgPath)) { return $cfgPath }

    # 4. Auto-detect: common paths
    $searchPaths = @(
        "$env:USERPROFILE\Desktop\v2rayN*\v2rayN.exe",
        "$env:LOCALAPPDATA\v2rayN\v2rayN.exe",
        "$env:PROGRAMFILES\v2rayN\v2rayN.exe",
        "${env:ProgramFiles(x86)}\v2rayN\v2rayN.exe",
        "$env:USERPROFILE\Downloads\v2rayN*\v2rayN.exe",
        "D:\soft\v2rayN*\v2rayN.exe",
        "C:\v2rayN\v2rayN.exe"
    )
    foreach ($p in $searchPaths) {
        $found = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    return $null
}

function Resolve-ProxyPort {
    param($ExplicitPort, $Config)
    if ($ExplicitPort -gt 0) { return $ExplicitPort }
    $envPort = $env:PROXY_PORT
    if ($envPort) { return [int]$envPort }
    if ($Config.proxy_port) { return [int]$Config.proxy_port }
    return 10808  # v2rayN default
}

# Resolve configuration
$V2RAYN_EXE = Resolve-V2rayNPath -ExplicitPath $V2rayNPath -Config $config
$V2RAYN_DIR = if ($V2RAYN_EXE) { Split-Path -Parent $V2RAYN_EXE } else { $null }
$PROXY_HOST = "127.0.0.1"
$PROXY_PORT = Resolve-ProxyPort -ExplicitPort $ProxyPort -Config $config
$PROXY_TYPE = "socks5"

# Environment variable names
$ENV_HTTP     = "HTTP_PROXY"
$ENV_HTTPS    = "HTTPS_PROXY"
$ENV_ALL      = "ALL_PROXY"
$ENV_NO_PROXY = "NO_PROXY"
$NO_PROXY_VAL = "localhost,127.0.0.1,*.cn,*.local,.local,.cn"

# ─── Helper Functions ────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "  [$([DateTime]::Now.ToString('HH:mm:ss'))] $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  ❌ $Message" -ForegroundColor Red
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ⚠️  $Message" -ForegroundColor Yellow
}

# ─── Core Functions ──────────────────────────────────────────────

function Get-ProxyStatus {
    $status = @{
        Running   = $false
        ProcessId = $null
        Port      = $PROXY_PORT
        Message   = ""
    }

    $proc = Get-Process -Name "v2rayN" -ErrorAction SilentlyContinue
    if (-not $proc) {
        $status.Message = "v2rayN process not running"
        return $status
    }
    $status.ProcessId = $proc.Id

    $coreProc = Get-Process -Name "xray", "sing-box" -ErrorAction SilentlyContinue

    $conn = Test-NetConnection -ComputerName $PROXY_HOST -Port $PROXY_PORT `
        -WarningAction SilentlyContinue -InformationLevel Quiet `
        -ErrorAction SilentlyContinue

    if ($conn) {
        $status.Running = $true
        $status.Message = "v2rayN running (PID: $($proc.Id)), proxy port $PROXY_PORT listening"
        if ($coreProc) {
            $status.Message += ", core: $($coreProc.ProcessName) (PID: $($coreProc.Id))"
        }
    } else {
        $status.Message = "v2rayN process running (PID: $($proc.Id)) but port $PROXY_PORT not listening yet"
    }

    return $status
}

function Start-Proxy {
    Write-Step "Checking proxy status..."

    $status = Get-ProxyStatus
    if ($status.Running) {
        Write-OK "Proxy already running: $($status.Message)"
        return $true
    }

    if ($status.ProcessId) {
        Write-Warn "v2rayN process exists but port not listening. Restarting..."
        Stop-Process -Id $status.ProcessId -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    if (-not $V2RAYN_EXE -or -not (Test-Path $V2RAYN_EXE)) {
        Write-Fail "v2rayN not found. Please configure:"
        Write-Host ""
        Write-Host "  Option 1: Create proxy-config.json in scripts/ directory:"
        Write-Host '    { "v2rayN_exe": "D:\\path\\to\\v2rayN.exe", "proxy_port": 10808 }'
        Write-Host ""
        Write-Host "  Option 2: Set environment variable:"
        Write-Host '    $env:V2RAYN_EXE = "D:\path\to\v2rayN.exe"'
        Write-Host ""
        Write-Host "  Searched paths: Desktop, AppData, Program Files"
        return $false
    }

    Write-Step "Starting v2rayN from: $V2RAYN_EXE"

    try {
        $proc = Start-Process -FilePath $V2RAYN_EXE -WorkingDirectory $V2RAYN_DIR -WindowStyle Hidden
        Write-OK "v2rayN launched"
    } catch {
        Write-Fail "Failed to start v2rayN: $_"
        return $false
    }

    Write-Step "Waiting for proxy port $PROXY_PORT (timeout: ${TimeoutSeconds}s)..."
    $waited = 0
    do {
        Start-Sleep -Seconds 1
        $waited++
        $conn = Test-NetConnection -ComputerName $PROXY_HOST -Port $PROXY_PORT `
            -WarningAction SilentlyContinue -InformationLevel Quiet `
            -ErrorAction SilentlyContinue
        if ($conn) {
            Write-OK "Proxy ready after ${waited}s"
            Start-Sleep -Seconds 1
            return $true
        }
    } while ($waited -lt $TimeoutSeconds)

    Write-Fail "Proxy did not become available within ${TimeoutSeconds}s"
    return $false
}

function Stop-Proxy {
    Write-Step "Stopping v2rayN..."

    $stopped = $false

    $proc = Get-Process -Name "v2rayN" -ErrorAction SilentlyContinue
    if ($proc) {
        try {
            $proc | Stop-Process -Force -ErrorAction Stop
            Write-OK "v2rayN stopped (PID: $($proc.Id))"
            $stopped = $true
        } catch {
            Write-Fail "Failed to stop v2rayN: $($_.Exception.Message)"
        }
    } else {
        Write-Warn "v2rayN not running"
    }

    foreach ($name in @("xray", "sing-box", "mihomo")) {
        $core = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($core) {
            try {
                $core | Stop-Process -Force -ErrorAction Stop
                Write-OK "$name stopped (PID: $($core.Id))"
            } catch {
                Write-Warn ("Failed to stop $name : " + $_.Exception.Message)
            }
        }
    }

    Remove-Item Env:\$ENV_HTTP -ErrorAction SilentlyContinue
    Remove-Item Env:\$ENV_HTTPS -ErrorAction SilentlyContinue
    Remove-Item Env:\$ENV_ALL -ErrorAction SilentlyContinue
    Remove-Item Env:\$ENV_NO_PROXY -ErrorAction SilentlyContinue

    return $stopped
}

function Set-ProxyEnv {
    $socks5Url = "socks5://${PROXY_HOST}:${PROXY_PORT}"
    $httpUrl   = "http://${PROXY_HOST}:${PROXY_PORT}"

    Write-Step "Setting proxy environment variables..."
    Write-Host ""
    Write-Host "  # Copy-paste these into your shell to enable proxy:"
    Write-Host ""
    Write-Host "  `$env:HTTP_PROXY  = '$httpUrl'"
    Write-Host "  `$env:HTTPS_PROXY = '$httpUrl'"
    Write-Host "  `$env:ALL_PROXY   = '$socks5Url'"
    Write-Host "  `$env:NO_PROXY    = '$NO_PROXY_VAL'"
    Write-Host ""

    $env:HTTP_PROXY  = $httpUrl
    $env:HTTPS_PROXY = $httpUrl
    $env:ALL_PROXY   = $socks5Url
    $env:NO_PROXY    = $NO_PROXY_VAL

    Write-OK "Environment variables set for current session"

    return @{
        HTTP_PROXY  = $httpUrl
        HTTPS_PROXY = $httpUrl
        ALL_PROXY   = $socks5Url
        NO_PROXY    = $NO_PROXY_VAL
    }
}

function Test-Connectivity {
    param(
        [string]$Url = $TestUrl,
        [int]$TimeoutSec = 10
    )

    Write-Step "Testing connectivity to: $Url"

    try {
        $result = curl.exe -s -o NUL -w "%{http_code}" `
            --socks5-hostname "${PROXY_HOST}:${PROXY_PORT}" `
            --connect-timeout $TimeoutSec `
            --max-time $TimeoutSec `
            $Url 2>&1

        if ($LASTEXITCODE -eq 0 -and $result -match '^[23]\d{2}$') {
            Write-OK "Connected! HTTP $result"
            return $true
        } else {
            Write-Fail "Failed (code: $result)"
            return $false
        }
    } catch {
        Write-Fail "Connection error: $_"
        return $false
    }
}

function Test-AllSites {
    $sites = @(
        @{ Name = "Google";     Url = "https://www.google.com" },
        @{ Name = "GitHub";     Url = "https://github.com" },
        @{ Name = "HuggingFace"; Url = "https://huggingface.co" },
        @{ Name = "DuckDuckGo"; Url = "https://duckduckgo.com" },
        @{ Name = "Wikipedia";  Url = "https://en.wikipedia.org" }
    )

    Write-Host ""
    Write-Host "  Connectivity Test Results:" -ForegroundColor White
    Write-Host "  $( '-' * 50 )"

    $allOK = $true
    foreach ($site in $sites) {
        $ok = Test-Connectivity -Url $site.Url -TimeoutSec 5
        if (-not $ok) { $allOK = $false }
    }

    Write-Host ""
    if ($allOK) {
        Write-OK "All sites reachable through proxy!"
    } else {
        Write-Warn "Some sites unreachable. Check proxy configuration."
    }

    return $allOK
}

# ─── Main ────────────────────────────────────────────────────────

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "  🌐 v2rayN Proxy Manager" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta

if (-not $V2RAYN_EXE) {
    Write-Host ""
    Write-Warn "v2rayN path not configured (will not auto-start)"
    Write-Host "  Auto-detection failed. To enable auto-start, create proxy-config.json"
    Write-Host "  or set `$env:V2RAYN_EXE. See SKILL.md for details."
}

Write-Host ""

switch ($Action) {
    "start" {
        if (-not $V2RAYN_EXE) {
            Write-Fail "Cannot start: v2rayN path unknown. Configure first."
            exit 1
        }
        $result = Start-Proxy
        if ($result) {
            Set-ProxyEnv | Out-Null
            Test-AllSites
            exit 0
        }
        exit 1
    }

    "stop" {
        $result = Stop-Proxy
        if ($result) { exit 0 } else { exit 1 }
    }

    "restart" {
        Stop-Proxy | Out-Null
        Start-Sleep -Seconds 2
        $result = Start-Proxy
        if ($result) {
            Set-ProxyEnv | Out-Null
            exit 0
        }
        exit 1
    }

    "status" {
        $status = Get-ProxyStatus
        if ($status.Running) {
            Write-OK $status.Message
            Write-Host "  Proxy URL: socks5://${PROXY_HOST}:${PROXY_PORT}" -ForegroundColor Gray
            if ($V2RAYN_EXE) {
                Write-Host "  v2rayN path: $V2RAYN_EXE" -ForegroundColor Gray
            }
            exit 0
        } else {
            Write-Fail $status.Message
            if (-not $V2RAYN_EXE) {
                Write-Warn "v2rayN path not configured. Start manually and use 'status' to verify."
            }
            exit 1
        }
    }

    "test" {
        $status = Get-ProxyStatus
        if (-not $status.Running) {
            Write-Fail "Proxy is NOT running. Use 'start' first."
            exit 1
        }
        Test-AllSites
        if ($LASTEXITCODE -eq 0) { exit 0 } else { exit 1 }
    }

    "env" {
        $status = Get-ProxyStatus
        if (-not $status.Running) {
            Write-Warn "Proxy is NOT running. Environment variables may be invalid."
        }
        Set-ProxyEnv | Out-Null
        exit 0
    }

    "wait" {
        $status = Get-ProxyStatus
        if ($status.Running) {
            Write-OK "Already running"
            exit 0
        }
        $result = Start-Proxy
        if ($result) {
            Set-ProxyEnv | Out-Null
            exit 0
        }
        exit 1
    }

    default {
        Write-Fail "Unknown action: $Action"
        Write-Host "Usage: proxy.ps1 [-Action] {start|stop|status|test|env|restart|wait}"
        exit 1
    }
}
