param(
    [string]$List = "regression.list",
    [int]$Seed = 1
)

Push-Location $PSScriptRoot

if (-not (Test-Path $List)) {
    Write-Error "Regression list not found: $List"
    Pop-Location
    exit 1
}

$tests = Get-Content $List | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") }
if ($tests.Count -eq 0) {
    Write-Error "No tests found in $List"
    Pop-Location
    exit 1
}

$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$pass = 0
$fail = 0

foreach ($t in $tests) {
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    $log = Join-Path $logDir ("{0}_{1}.log" -f $t, $ts)

    Write-Host "[RUN] $t"
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run.ps1") -Test $t *>&1 | Tee-Object -FilePath $log

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] $t"
        $pass++
    } else {
        Write-Host "[FAIL] $t (log: $log)"
        $fail++
    }
}

Write-Host "========================================="
Write-Host ("Regression summary: PASS={0} FAIL={1}" -f $pass, $fail)
Write-Host "========================================="

Pop-Location

if ($fail -gt 0) { exit 1 } else { exit 0 }
