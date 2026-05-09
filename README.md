
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

The bridge is a dual-clock asynchronous design with two independent valid/ready datapaths — one per direction — each backed by a parameterized asynchronous FIFO (`async_fifo`).

- **CXL domain (`clk`):** Handles ingress for CXL requests and egress for completions.
- **UCIe domain (`ucie_clk`):** Handles egress for UCIe adapter requests and ingress for completions.

**CXL → UCIe path:** incoming `CXL.io` request packets are field-remapped into simplified UCIe adapter request packets. CFG reads and CFG writes are tagged as `UCIE_MSG_CFG`; all other ops map to `UCIE_MSG_MEM`. A lightweight XOR checksum is computed over the translated packet and written into the `misc` byte.

**UCIe → CXL path:** incoming UCIe adapter completion packets are checksum-verified, then field-remapped into `CXL.io` completion packets. Packets with a failing checksum are converted to `CXL_PKT_KIND_INVALID` so downstream logic can observe the mismatch rather than silently dropping it. Unsupported packet kinds on either path produce an explicit error/invalid packet rather than being dropped.

Packet field layout and pack/unpack helpers are defined in `src/cxl_ucie_bridge_defs.vh`. The top module asserts at elaboration time that `WIDTH == 64` (the typed model assumes 64-bit packets).

## Status
Phase 5 dual-clock model: asynchronous buffered translation between CXL (clk) and UCIe (ucie_clk) domains. Robust CDC for external control signals, reset synchronization, and a link-state gating FSM. Simulation CI, optional Verilator lint, bounded formal (BMC + cover) on the full bridge and FIFOs.

## Current Scope
- `CXL -> UCIe`: simplified `CXL.io` request packet translation
- `UCIe -> CXL`: simplified UCIe adapter completion translation
- Shared packet-field definitions live in `src/cxl_ucie_bridge_defs.vh`
- Full `CXL.cache` / `CXL.mem` semantics, credits, and ordering policy remain future work

## Quick start

- **Linux / WSL:** `cd test && make clean && make && make stress` (optional: `make lint` for Verilator). A checkout **outside** `/mnt/c/...` under native WSL (for example `~/proj/ucie-cxl-bridge`) is often faster; commands are unchanged.
- **Windows (PowerShell):** `cd test; .\run_sim.ps1` (requires `iverilog` and `vvp` on `PATH`; optional `.\run_sim.ps1 lint` if Verilator is installed).

More detail (formal runs, CI, native WSL): [CONTRIBUTING.md](CONTRIBUTING.md).

