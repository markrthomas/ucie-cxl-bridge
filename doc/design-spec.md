---
title: "CXL–UCIe Bridge Design Specification"
subtitle: "Experimental RTL"
date: "April 2026"
---

# 1. Purpose and scope

This document specifies the design intent for an experimental **bridge between Compute Express Link (CXL)** traffic and a **UCIe-compatible adapter-layer interface**. The implementation targets **Verilog** suitable for simulation with **Icarus Verilog** (`iverilog` / `vvp`).

**In scope today:** simulation bring-up, a documented module boundary, a narrowed first protocol target, and a path to richer protocol behavior.

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

The repository now contains a **first protocol-bearing revision** built on the earlier dual-path streaming shell. The current scope is intentionally narrow so semantics can be exercised without claiming full CXL or UCIe compliance.

The top RTL module is `cxl_ucie_bridge`. It parameterizes flit width (`WIDTH`, default 64 bits) and FIFO depth per direction (`FIFO_DEPTH`, default 8; must be a power of two for `sync_fifo`). The current translation layer assumes **64-bit packets** with shared field definitions in `src/cxl_ucie_bridge_defs.vh`. Each direction instantiates `sync_fifo` for buffering:

- **CXL → UCIe** — simplified `CXL.io` request packet to simplified UCIe adapter request packet
- **UCIe → CXL** — simplified UCIe adapter completion packet to simplified `CXL.io` completion packet

Each direction uses a **valid/ready** interface with a synchronous FIFO (first-word fall-through read data) and standard backpressure: upstream `ready` is asserted when that FIFO is not full; downstream sees `valid` when the FIFO is not empty.

Unsupported packet kinds are not dropped; they are converted into an explicit error or invalid packet kind on the output side so the testbench and downstream logic can observe the mismatch.

## 4.3 Implemented packet taxonomy (Phases 1–2)

Phase 1 froze a narrow first target (CXL.io request ↔ UCIe adapter completion) to make semantics exercise-able without claiming full protocol compliance. Phase 2 broadened the packet taxonomy to cover:

1. **CXL-facing ingress:** `CXL.io` requests (CFG_RD, CFG_WR, MEM_RD, MEM_WR) and `CXL.mem` / `CXL.cache` requests (MEM_RD, MEM_WR, CACHE_RD, CACHE_WR)
2. **UCIe-facing ingress:** UCIe adapter completions — `AD_CPL`, `MEM_CPL`, `CACHE_CPL` — each with checksum verification
3. **Translation behavior:** field remap, opcode/kind preservation, lightweight XOR checksum generation and verification
4. **Remaining non-goals:** payload movement, retries, full CXL ordering compliance, and link bring-up

## 4.4 Flow control and ordering (Phase 3)

Phase 3 adds per-direction credit counters and splits the CXL→UCIe path into two ordering domains:

**Credit counting (`src/credit_counter.v`):** A parameterized `credit_counter` module tracks available send credits per direction. Credits are consumed when a packet enters a FIFO and returned automatically when the downstream reads the packet. The bridge gates `cxl_in_ready` on both local FIFO space and credit availability, so an exhausted credit pool stalls the source cleanly without overrunning peer buffers.

**Ordering domain split:** CXL defines two classes of traffic with different ordering rules:

| Class | CXL kinds | UCIe msg type | Rule |
|-------|-----------|---------------|------|
| Posted | `MEM_WR`, `CACHE_WR` | `UCIE_MSG_MEM_WR`, `UCIE_MSG_CACHE_WR` | May bypass non-posted |
| Non-posted | `IO_REQ`, `MEM_RD`, `CACHE_RD` | `UCIE_MSG_*` (other) | Must preserve ordering within class |

The bridge routes posted packets to `u_c2u_posted` and non-posted packets to `u_c2u_np` — two independent sync FIFOs, each with its own credit counter. The egress arbiter is **posted-priority**: when both FIFOs have data, posted packets drain first (consistent with CXL's permission for posted traffic to bypass non-posted). Within each class, FIFO ordering preserves packet sequence.

The UCIe→CXL path (completions only) remains a single FIFO with its own credit counter (`u_cpl_crd`).

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
- **Lint (second opinion):** Verilator `--lint-only` on `sync_fifo` + `cxl_ucie_bridge` (CI), without elaborating the testbench.
- **Formal:** SymbiYosys (`sby`) on `sync_fifo`: bounded **BMC** (safety asserts on `count`), **cover** reachability (full, simultaneous read/write, mid occupancy), and `async2sync` after `prep` for active-low asynchronous reset. BMC includes **initial assumptions** so registers are not left unconstrained at time zero (otherwise `count` could start above `DEPTH` and fail vacuously). Assertions and covers are `FORMAL`-guarded in RTL (see `formal/sync_fifo.sby`). CI uses the OSS CAD Suite installer action so `sby` and solvers are available without distro-specific packages.
- **Testbench:** `tb_cxl_ucie_bridge` runs a short smoke test (one typed packet per direction), then stress with concurrent traffic, random sink `ready`, bursts, semantic scoreboarding of translated packets, and a drain phase. The `cxl_ucie_bridge_chk` module checks egress **ready/valid** stability rules during simulation.
- **Scoreboard behavior:** The testbench uses a reusable per-cycle scoreboard step and explicitly accounts for transfers on the stress-to-drain boundary clock edge before disabling new source traffic.
- **Automation:** The `test/` directory provides a `Makefile` with targets `run`, `vcd` (optional waveform dump to `build/waves.vcd`), and `gtkwave` (regenerate VCD and open GTKWave when available). On Windows, `test/run_sim.ps1` runs the same compile and `vvp` steps when `iverilog`/`vvp` are on `PATH`.

Optional waveform dumps are enabled with the `+vcd` plus argument; GTKWave is used for inspection.

# 7. Repository layout (relevant paths)

| Path | Role |
|------|------|
| `src/sync_fifo.v` | Parameterized synchronous FIFO |
| `src/credit_counter.v` | Parameterized credit counter (consume / return / available) |
| `src/cxl_ucie_bridge_defs.vh` | Shared packet kinds, field locations, pack helpers, checksum helper |
| `src/cxl_ucie_bridge.v` | Bridge RTL (split c2u FIFOs, credit counters, posted-priority arbiter) |
| `src/cxl_ucie_bridge_chk.v` | Simulation checks (egress stability / no valid retraction) |
| `src/tb_cxl_ucie_bridge.v` | Testbench |
| `test/Makefile` | Simulation and waveform targets |
| `test/run_sim.ps1` | Windows-oriented compile + `vvp` helper |
| `formal/sync_fifo.sby` | SymbiYosys bounded BMC for `sync_fifo` (requires `sby`, e.g. OSS CAD Suite) |
| `doc/design-spec.md` | This specification (source) |
| `doc/Makefile` | PDF build for this document |
| `CONTRIBUTING.md` | Simulation, formal, and CI notes for contributors |

# 8. Roadmap (phased milestones)

Work is expected to proceed roughly in the following order; later phases depend on chosen protocol profiles and tooling.

1. **Narrow first target (done ✓)** — Typed 64-bit packet definitions, simplified `CXL.io` request translation, simplified UCIe completion translation, synchronous FIFO buffering, ready/valid checks, simulation and bounded formal on the FIFO, second-opinion lint (Verilator).
2. **Broaden typed traffic (done ✓)** — Full CXL.io / CXL.mem / CXL.cache packet taxonomy, matching UCIe adapter message families, expanded scoreboarding and formal assertions, GTKWave save file.
3. **Flow control and ordering (done ✓)** — Per-direction credit counters, posted/non-posted ordering domain split, posted-priority egress arbiter, ordering directed test, credit-exhaustion formal covers.
4. **Bring-up and non-ideal behavior** — Reset sequencing, link readiness gates, error injection, and (when needed) **clocking / CDC** documentation and RTL.

# 9. Future work (detail)

- Replace generic flits with **typed CXL and UCIe message** representations aligned to chosen specification revisions.
- Implement **credit** and **ordering** state machines and verify with directed and constrained-random stimulus (tooling beyond iverilog may be required for advanced methodologies).
- Document **reset and link bring-up** sequences and corresponding RTL interfaces.
- Expand the design specification with **timing, clocking, and CDC** assumptions as the design adds multiple clock domains or PHY-facing logic.

# 10. Document control

| Item | Value |
|------|--------|
| Format | Markdown (source), PDF (generated) |
| Revision | Draft — aligned with repository baseline RTL |

This specification is maintained alongside the RTL; discrepancies should be resolved by updating either the document or the implementation and recording the change in revision control.
