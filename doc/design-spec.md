---
title: "CXL–UCIe Bridge Design Specification"
subtitle: "Experimental RTL"
date: "April 2026"
---

# 1. Purpose and scope

This document specifies the design intent for an experimental **bridge between Compute Express Link (CXL)** traffic and a **UCIe-compatible adapter-layer interface**. The implementation targets **Verilog** suitable for simulation with **Icarus Verilog** (`iverilog` / `vvp`).

**In scope today:** simulation bring-up, a documented module boundary, and a path to richer protocol behavior.

**Out of scope for the current RTL:** full CXL protocol compliance, production UCIe PHY and link training, and complete credit or ordering models (described here as requirements to be met by future revisions).

# 2. Background

CXL defines memory, cache-coherent, and I/O semantics over a PCIe physical layer. UCIe defines die-to-die interconnect including adapter layers that carry protocol flits. A bridge must translate semantic and transport assumptions between these domains while preserving **ordering** where required and honoring **flow control** on both sides.

# 3. Goals

The bridge is intended to support:

1. **Protocol translation** — Map CXL.io, CXL.cache, and CXL.mem concepts to and from UCIe adapter-layer traffic (exact packet formats TBD).
2. **Credit-based flow control** — Reflect credits available from each side so the bridge does not overrun peer buffers.
3. **Ordering preservation** — Maintain required ordering classes between ingress and egress where the specifications demand it.
4. **Link bring-up model** — Eventually model reset, training handshakes, and readiness gates relevant to safe traffic acceptance.

# 4. Architecture

## 4.1 Target architecture (summary)

At a high level, the bridge sits between:

- A **CXL-facing port** (logical aggregation of CXL.io / CXL.cache / CXL.mem as seen by the design).
- A **UCIe-facing port** (adapter-layer ingress and egress consistent with the chosen UCIe stack profile).

Internal blocks (to be elaborated in later revisions) may include buffering, translation tables, credit trackers, and optional reorder queues subject to specification rules.

## 4.2 Current implementation (baseline)

The repository contains a **minimal dual-path streaming shell** intended only to validate tooling, timing of ready/valid handshakes, and testbench structure. It does **not** implement CXL or UCIe protocols.

The top RTL module is `cxl_ucie_bridge`. It parameterizes flit width (`WIDTH`, default 64 bits) and provides two independent registered channels:

- **CXL → UCIe** — `cxl_in_*` to `ucie_out_*`
- **UCIe → CXL** — `ucie_in_*` to `cxl_out_*`

Each direction uses a **valid/ready** interface with a one-deep output register stage and standard backpressure: upstream `ready` is asserted when the output stage is empty or the downstream has accepted the current beat.

# 5. Interface summary

## 5.1 Common

| Signal   | Direction | Description        |
|----------|-----------|--------------------|
| `clk`    | Input     | Core clock         |
| `rst_n`  | Input     | Asynchronous reset, active low |

## 5.2 CXL → UCIe path

| Signal           | Direction (from bridge) | Description              |
|------------------|-------------------------|--------------------------|
| `cxl_in_valid`   | Input                   | Ingress beat valid       |
| `cxl_in_ready`   | Output                  | Ingress ready          |
| `cxl_in_data`    | Input                   | Ingress flit (`WIDTH`) |
| `ucie_out_valid` | Output                  | Egress beat valid      |
| `ucie_out_ready` | Input                   | Egress ready           |
| `ucie_out_data`  | Output                  | Egress flit (`WIDTH`)  |

## 5.3 UCIe → CXL path

| Signal           | Direction (from bridge) | Description              |
|------------------|-------------------------|--------------------------|
| `ucie_in_valid`  | Input                   | Ingress beat valid       |
| `ucie_in_ready`  | Output                  | Ingress ready            |
| `ucie_in_data`   | Input                   | Ingress flit (`WIDTH`)   |
| `cxl_out_valid`  | Output                  | Egress beat valid        |
| `cxl_out_ready`  | Input                   | Egress ready             |
| `cxl_out_data`   | Output                  | Egress flit (`WIDTH`)    |

# 6. Verification

- **Simulator:** Icarus Verilog (`iverilog` compilation, `vvp` execution).
- **Testbench:** `tb_cxl_ucie_bridge` drives a single flit on each direction and checks data integrity.
- **Automation:** The `test/` directory provides a `Makefile` with targets `run`, `vcd` (optional waveform dump to `build/waves.vcd`), and `gtkwave` (regenerate VCD and open GTKWave when available).

Optional waveform dumps are enabled with the `+vcd` plus argument; GTKWave is used for inspection.

# 7. Repository layout (relevant paths)

| Path | Role |
|------|------|
| `src/cxl_ucie_bridge.v` | Bridge RTL |
| `src/tb_cxl_ucie_bridge.v` | Testbench |
| `test/Makefile` | Simulation and waveform targets |
| `doc/design-spec.md` | This specification (source) |
| `doc/Makefile` | PDF build for this document |

# 8. Future work

- Replace generic flits with **typed CXL and UCIe message** representations aligned to chosen specification revisions.
- Implement **credit** and **ordering** state machines and verify with directed and constrained-random stimulus (tooling beyond iverilog may be required for advanced methodologies).
- Document **reset and link bring-up** sequences and corresponding RTL interfaces.
- Expand the design specification with **timing, clocking, and CDC** assumptions as the design adds multiple clock domains or PHY-facing logic.

# 9. Document control

| Item | Value |
|------|--------|
| Format | Markdown (source), PDF (generated) |
| Revision | Draft — aligned with repository baseline RTL |

This specification is maintained alongside the RTL; discrepancies should be resolved by updating either the document or the implementation and recording the change in revision control.
