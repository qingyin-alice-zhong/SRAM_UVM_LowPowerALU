param(
    [string]$Test = "smoke_test"
)

Push-Location $PSScriptRoot

if (-not $env:UVM_HOME) {
    Write-Error "UVM_HOME is not set. Example: `$env:UVM_HOME='C:\questasim\verilog_src\uvm-1.2'"
    Pop-Location
    exit 1
}

vlib work
vlog -sv -f compile.f
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    exit $LASTEXITCODE
}

vsim -c tb_top +UVM_TESTNAME=$Test -do "run -all; quit -f"
$exitCode = $LASTEXITCODE

Pop-Location
exit $exitCode
