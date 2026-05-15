<#
.SYNOPSIS
  v2rayN Proxy Manager for OpenClaw AI Assistant
.DESCRIPTION
  Manages the v2rayN proxy: start, stop, status, test, and configure
  environment variables for CLI tools.
.NOTES
  This script is designed to be called by the AI assistant (Alien) when
  network connectivity issues are detected while accessing sites like
  Google, GitHub, HuggingFace, etc.
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "stop", "status", "test", "env", "restart", "wait")]
    [string]$Action = "status",

    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 30,

    [Parameter(Mandatory=$false)]
    [string]$TestUrl = "https://www.google.com"
)

# ─── Configuration ───────────────────────────────────────────────
$V2RAYN_EXE   = "D:\soft\v2rayN-windows-64-SelfContained\v2rayN.exe"
$V2RAYN_DIR   = "D:\soft\v2rayN-windows-64-SelfContained"
$PROXY_HOST   = "127.0.0.1"
$PROXY_PORT   = 10808       # SOCKS5 port
$PROXY_TYPE   = "socks5"

# Environment variable names
$ENV_HTTP     = "HTTP_PROXY"
$ENV_HTTPS    = "HTTPS_PROXY"
$ENV_ALL      = "ALL_PROXY"
$ENV_NO_PROXY = "NO_PROXY"

# Sites to exclude from proxy (local/CN sites)
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
    <#
    .SYNOPSIS
      Check if v2rayN proxy is running by testing port connectivity.
    .OUTPUTS
      Returns a hashtable with keys: Running (bool), ProcessId, Port, Message
    #>
    $status = @{
        Running   = $false
        ProcessId = $null
        Port      = $PROXY_PORT
        Message   = ""
    }

    # Check if v2rayN process is running
    $proc = Get-Process -Name "v2rayN" -ErrorAction SilentlyContinue
    if (-not $proc) {
        $status.Message = "v2rayN process not running"
        return $status
    }
    $status.ProcessId = $proc.Id

    # Check core processes (Xray or sing-box)
    $coreProc = Get-Process -Name "xray", "sing-box" -ErrorAction SilentlyContinue

    # Check if port is listening
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
    <#
    .SYNOPSIS
      Launch v2rayN and wait for proxy to become ready.
    #>
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

    Write-Step "Starting v2rayN..."
    if (-not (Test-Path $V2RAYN_EXE)) {
        Write-Fail "v2rayN executable not found at: $V2RAYN_EXE"
        return $false
    }

    try {
        $proc = Start-Process -FilePath $V2RAYN_EXE -WorkingDirectory $V2RAYN_DIR -WindowStyle Hidden
        Write-OK "v2rayN launched"
    } catch {
        Write-Fail "Failed to start v2rayN: $_"
        return $false
    }

    # Wait for proxy to become available
    Write-Step "Waiting for proxy to become available (timeout: ${TimeoutSeconds}s)..."
    $waited = 0
    do {
        Start-Sleep -Seconds 1
        $waited++
        $conn = Test-NetConnection -ComputerName $PROXY_HOST -Port $PROXY_PORT `
            -WarningAction SilentlyContinue -InformationLevel Quiet `
            -ErrorAction SilentlyContinue
        if ($conn) {
            Write-OK "Proxy ready after ${waited}s"
            # Give it a moment to fully initialize
            Start-Sleep -Seconds 1
            return $true
        }
    } while ($waited -lt $TimeoutSeconds)

    Write-Fail "Proxy did not become available within ${TimeoutSeconds}s"
    return $false
}

function Stop-Proxy {
    <#
    .SYNOPSIS
      Stop v2rayN and its core processes.
    #>
    Write-Step "Stopping v2rayN..."

    $stopped = $false

    # Stop v2rayN
    $proc = Get-Process -Name "v2rayN" -ErrorAction SilentlyContinue
    if ($proc) {
        try {
            $proc | Stop-Process -Force -ErrorAction Stop
            Write-OK "v2rayN stopped (PID: $($proc.Id))"
            $stopped = $true
        } catch {
            Write-Fail "Failed to stop v2rayN: $_"
        }
    } else {
        Write-Warn "v2rayN not running"
    }

    # Stop core processes
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

    # Clear proxy environment variables for current process
    Remove-Item Env:\$ENV_HTTP -ErrorAction SilentlyContinue
    Remove-Item Env:\$ENV_HTTPS -ErrorAction SilentlyContinue
    Remove-Item Env:\$ENV_ALL -ErrorAction SilentlyContinue
    Remove-Item Env:\$ENV_NO_PROXY -ErrorAction SilentlyContinue

    return $stopped
}

function Set-ProxyEnv {
    <#
    .SYNOPSIS
      Output commands to set proxy environment variables.
      Call this and then evaluate the output in the calling shell.
    .DESCRIPTION
      Sets HTTP_PROXY, HTTPS_PROXY, ALL_PROXY for both HTTP and SOCKS5.
      Also sets NO_PROXY to exclude local/Chinese sites.
    #>
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

    # Actually set them for this process
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
    <#
    .SYNOPSIS
      Test if a URL is reachable through the proxy.
    #>
    param(
        [string]$Url = $TestUrl,
        [int]$TimeoutSec = 10
    )

    Write-Step "Testing connectivity to: $Url"

    try {
        # Use curl with SOCKS5 proxy
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
    <#
    .SYNOPSIS
      Test connectivity to commonly blocked sites.
    #>
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
Write-Host ""

switch ($Action) {
    "start" {
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
            exit 0
        } else {
            Write-Fail $status.Message
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
            Write-Fail "Proxy is NOT running. Environment variables may be invalid."
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
