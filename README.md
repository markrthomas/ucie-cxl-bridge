
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
Phase 1 protocol-bearing model: buffered translation for a narrowed first target, with `CXL.io`-style requests mapped onto a simplified UCIe adapter request packet and UCIe adapter completions mapped back into `CXL.io`-style completions. Simulation CI, optional Verilator lint, bounded formal (BMC + cover) on `sync_fifo`, Windows `test/run_sim.ps1` helper.

## Current Scope
- `CXL -> UCIe`: simplified `CXL.io` request packet translation
- `UCIe -> CXL`: simplified UCIe adapter completion translation
- Shared packet-field definitions live in `src/cxl_ucie_bridge_defs.vh`
- Full `CXL.cache` / `CXL.mem` semantics, credits, and ordering policy remain future work

## Quick start

- **Linux / WSL:** `cd test && make clean && make && make stress` (optional: `make lint` for Verilator). A checkout **outside** `/mnt/c/...` under native WSL (for example `~/proj/ucie-cxl-bridge`) is often faster; commands are unchanged.
- **Windows (PowerShell):** `cd test; .\run_sim.ps1` (requires `iverilog` and `vvp` on `PATH`; optional `.\run_sim.ps1 lint` if Verilator is installed).

More detail (formal runs, CI, native WSL): [CONTRIBUTING.md](CONTRIBUTING.md).

