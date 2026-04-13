
# UCIe to CXL Bridge

Experimental **Verilog / SystemVerilog** RTL for a bridge between:

- UCIe Adapter Layer
- CXL.io / CXL.cache / CXL.mem

Verification today uses **Icarus Verilog** (`iverilog` / `vvp`) with a directed + stress testbench (`tb_cxl_ucie_bridge`). **UVM** is not wired into the repo yet; see `doc/design-spec.md` for roadmap (including optional UVM later).

## Goals
- Protocol translation
- credit flow control
- ordering preservation
- link bringup model

## Architecture
TBD

## Status
Baseline dual-FIFO streaming shell, simulation CI, optional Verilator lint, bounded formal (BMC + cover) on `sync_fifo`, Windows `test/run_sim.ps1` helper.

## Quick start

- **Linux / WSL:** `cd test && make clean && make && make stress` (optional: `make lint` for Verilator)
- **Windows (PowerShell):** `cd test; .\run_sim.ps1` (requires `iverilog` and `vvp` on `PATH`)

