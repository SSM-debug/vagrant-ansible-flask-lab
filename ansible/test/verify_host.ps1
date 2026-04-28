# verify_host.ps1 - Verification from Windows host

$pass = 0
$fail = 0

function Test-Port {
    param($h, $port, $testName, $expectOpen)
    $result = Test-NetConnection -ComputerName $h -Port $port -WarningAction SilentlyContinue
    if ($expectOpen -and $result.TcpTestSucceeded) {
        Write-Host "[PASS] $testName" -ForegroundColor Green
        return 1
    } elseif (-not $expectOpen -and -not $result.TcpTestSucceeded) {
        Write-Host "[PASS] $testName" -ForegroundColor Green
        return 1
    } else {
        Write-Host "[FAIL] $testName" -ForegroundColor Red
        return 0
    }
}

Write-Host "============================================"
Write-Host " vagrant-ansible-flask-lab - Host Verify"
Write-Host "============================================"
Write-Host ""

# T15: nginx nåbar via port forwarding
$pass += Test-Port "localhost" 8080 "T15: nginx reachable via port forwarding :8080" $true

# T16: nginx port 80 INTE nåbar direkt (bara via :8080)
$pass += Test-Port "localhost" 80 "T16: nginx port 80 NOT exposed on host (only :8080)" $false

# T17: PostgreSQL INTE nåbar från host via port forwarding
$pass += Test-Port "localhost" 5432 "T17: PostgreSQL NOT exposed via port forwarding" $false

# T18: Flask INTE nåbar via port forwarding
$pass += Test-Port "localhost" 5000 "T18: Flask port 5000 NOT exposed via port forwarding" $false

Write-Host ""
Write-Host "============================================"
Write-Host " RESULT: $pass PASS / $((4 - $pass)) FAIL"
Write-Host "============================================"