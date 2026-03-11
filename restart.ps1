param(
    [switch]$NoNewWindow
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $projectRoot "backend"
$frontendDir = Join-Path $projectRoot "frontend"

function Stop-ProcessByPort {
    param([int]$Port)

    $conns = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Where-Object { $_.State -in @("Listen", "Established") } |
        Select-Object -ExpandProperty OwningProcess -Unique

    foreach ($procId in $conns) {
        if ($procId -and $procId -ne $PID) {
            try {
                Stop-Process -Id $procId -Force -ErrorAction Stop
                Write-Host "Stopped PID $procId on port $Port"
            }
            catch {
                Write-Warning "Failed to stop PID $procId on port ${Port}: $($_.Exception.Message)"
            }
        }
    }
}

Write-Host "== MiroFish restart started ==" -ForegroundColor Cyan

Stop-ProcessByPort -Port 3000
Stop-ProcessByPort -Port 5001

$backendCmd = "Set-Location '$backendDir'; py -3.11 -m uv run python run.py"
$frontendCmd = "Set-Location '$projectRoot'; npm run frontend"

if ($NoNewWindow) {
    Start-Job -Name "mirofish-backend" -ScriptBlock {
        param($cmd)
        powershell -NoProfile -Command $cmd
    } -ArgumentList $backendCmd | Out-Null

    Start-Job -Name "mirofish-frontend" -ScriptBlock {
        param($cmd)
        powershell -NoProfile -Command $cmd
    } -ArgumentList $frontendCmd | Out-Null

    Write-Host "Started backend/frontend as background jobs in current session."
    Write-Host "Use: Get-Job | Receive-Job -Keep"
}
else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd | Out-Null
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCmd | Out-Null

    Write-Host "Started backend and frontend in new PowerShell windows."
}

Write-Host "Frontend: http://localhost:3000"
Write-Host "Backend:  http://localhost:5001/health"
