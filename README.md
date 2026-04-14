# SRAM UVM LowPower AHB Verification

## Overview

- DUT: AHB-Lite style `32x32` SRAM with byte/halfword/word accesses.
- Verification approach: UVM (`driver`, `monitor`, `scoreboard`, `sequence`, `test`).
- Low-power focus: `sleep_i` behavior (read-as-zero during sleep, write blocking during sleep, sleep interrupt during active transfer window).

## Project Structure

- `rtl/`: DUT RTL
- `tb/`: interface, UVM package, `tb_top`, and SVA
- `sim/`: compile/run/regression scripts and regression list
- `task.md`: task checklist and milestone status
- `note.md`: low-power verification requirements and pass criteria
- `chisel-memory-lower-master/`: reference folder (not part of the main verification project)

## Prerequisites

- Questa/ModelSim available in `PATH` (`vlib`, `vlog`, `vsim`)
- UVM path configured:

```powershell
$env:UVM_HOME='C:\questasim\verilog_src\uvm-1.2'
```

## Quick Start

Run a single test:

```powershell
cd sim
./run.ps1 -Test smoke_test
```

Run full regression:

```powershell
cd sim
./regress.ps1 -List regression.list
```

## Current Test List

- `smoke_test`
- `addr_sweep_test`
- `subword_access_test`
- `unaligned_access_test`
- `pipeline_burst_test`
- `reset_init_test`
- `random_regression_test`
- `low_power_sleep_entry_test`
- `low_power_sleep_blocks_write_test`
- `low_power_sleep_pipeline_interrupt_test`

Logs are generated in `sim/logs/`.
