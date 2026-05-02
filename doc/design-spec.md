---
title: "CXL–UCIe Bridge Design Specification"
subtitle: "Experimental RTL"
date: "April 2026"
---

# 1. Purpose and scope

This document specifies the design intent for an experimental **bridge between Compute Express Link (CXL)** traffic and a **UCIe-compatible adapter-layer interface**. The implementation targets **Verilog** suitable for simulation with **Icarus Verilog** (`iverilog` / `vvp`).

**In scope today:** simulation bring-up, a documented module boundary, a typed packet taxonomy covering CXL.io / CXL.mem / CXL.cache and matching UCIe adapter completions, a lightweight credit and ordering model (posted vs. non-posted domain split with posted-priority egress arbitration), and a path toward link bring-up.

**Out of scope for the current RTL:** full CXL protocol compliance, production UCIe PHY and link training, payload movement, retries, and reset / link bring-up sequencing (described here as requirements to be met by future revisions).

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

## 4.2 Current implementation (Phase 4 baseline)

The repository contains a **Phase 4 RTL** that adds link-state gating, error injection, and a CDC synchronizer utility to the Phase 3 foundation of typed packet model, per-direction credit flow control, and posted/non-posted ordering domain split. The current scope is intentionally narrow relative to full CXL/UCIe compliance so semantics can be exercised and verified incrementally.

The top RTL module is `cxl_ucie_bridge`. It parameterizes flit width (`WIDTH`, default 64 bits), FIFO depth (`FIFO_DEPTH`, default 8; must be a power of two), and initial credits per direction (`POSTED_CREDITS`, `NP_CREDITS`, `CPL_CREDITS`, all defaulting to `FIFO_DEPTH`). The translation layer assumes **64-bit packets** with shared field definitions in `src/cxl_ucie_bridge_defs.vh`.

**CXL → UCIe path** uses two independent sync FIFOs:
- `u_c2u_posted` — posted requests (`MEM_WR`, `CACHE_WR`), gated by `u_posted_crd` credit counter
- `u_c2u_np` — non-posted requests (all other CXL kinds), gated by `u_np_crd` credit counter

The egress arbiter selects between the two FIFOs using posted-priority arbitration. A registered lock (`arb_locked_r` / `arb_sel_posted_r`) freezes the selected FIFO for the duration of any stalled handshake, ensuring `ucie_out_data` remains stable while `ucie_out_valid` is asserted and `ucie_out_ready` is deasserted.

**UCIe → CXL path** uses a single sync FIFO (`u_u2c`) gated by `u_cpl_crd`.

Each direction uses a **valid/ready** interface with standard backpressure: upstream `ready` is asserted when the target FIFO is not full **and** credits are available; downstream sees `valid` when the output FIFO (or arbiter) has data.

Unsupported packet kinds are not dropped; they are converted into an explicit error or invalid packet kind on the output side so the testbench and downstream logic can observe the mismatch.

## 4.3 Implemented packet taxonomy (Phases 1–2)

Phase 1 froze a narrow first target (CXL.io request ↔ UCIe adapter completion) to make semantics exercise-able without claiming full protocol compliance. Phase 2 broadened the packet taxonomy to cover:

1. **CXL-facing ingress:** `CXL.io` requests (CFG_RD, CFG_WR, MEM_RD, MEM_WR) and `CXL.mem` / `CXL.cache` requests (MEM_RD, MEM_WR, CACHE_RD, CACHE_WR)
2. **UCIe-facing ingress:** UCIe adapter completions — `AD_CPL`, `MEM_CPL`, `CACHE_CPL` — each with checksum verification
3. **Translation behavior:** field remap, opcode/kind preservation, CRC-8/CCITT checksum generation and verification (poly 0x07, init 0x00, over header bytes [63:8])
4. **Remaining non-goals:** payload movement, retries, full CXL ordering compliance, and link bring-up

## 4.5 Bring-up and non-ideal behavior (Phase 4)

Phase 4 adds a link-state readiness gate, a reset-drain FSM, an error injection interface, and a CDC synchronizer utility module.

**Reset-drain FSM (`src/reset_drain.v`):** A `reset_drain` module implements a three-state machine that gates the bridge open or closed based on an external `link_up` signal:

| State | Meaning | Transition |
|-------|---------|------------|
| `S_DOWN` | Bridge closed; no new ingress accepted | → `S_UP` when `link_up` asserted |
| `S_UP` | Bridge open; normal operation | → `S_DRAIN` when `link_up` deasserted |
| `S_DRAIN` | Bridge closed; draining in-flight packets | → `S_DOWN` when all FIFOs empty |

The bridge's `cxl_in_ready` and `ucie_in_ready` are gated by the FSM's `open` output, so de-asserting `link_up` immediately stops new traffic acceptance while existing FIFO contents drain normally via the egress path. The `drain_done` output (combinationally equal to `all_empty`) signals when it is safe to power-down or re-sequence the link.

**Error injection interface:** The `err_inj_en` input allows a testbench or external agent to corrupt the next outgoing CXL→UCIe packet. When `err_inj_en` is asserted, bit 0 of the translated packet's checksum byte is flipped before the packet enters the FIFO. This exercises downstream error-handling paths without requiring separate error-generating stimulus.

**CDC synchronizer (`src/cdc_sync.v`):** A standalone `cdc_sync` module provides a parameterized N-stage flip-flop chain for crossing single-bit signals between asynchronous clock domains (default 2 stages). The bridge itself remains single-clock; `cdc_sync` is provided as a building block for future multi-clock integration (see §9).

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
- **Formal:** SymbiYosys (`sby`) targets three modules. `formal/sync_fifo.sby`: bounded **BMC** (safety asserts on `count`), **cover** reachability (full, simultaneous read/write, mid occupancy), and `async2sync` after `prep` for active-low asynchronous reset; BMC uses **initial assumptions** so registers are not unconstrained at time zero. `formal/cxl_ucie_bridge.sby`: BMC checks translation kind-preservation (CXL kind → correct UCIe kind, bad checksum → INVALID), ordering-domain routing (accepted packets route to exactly one FIFO), arbiter correctness (`c2u_posted_rd == arb_sel_final`, posted-priority invariant when unlocked), link-gating (`!bridge_open → cxl_in_ready == 0 && ucie_in_ready == 0`), and error injection (`err_inj_en` flips bit 0 and only bit 0 of the translated packet); cover mode adds link-down stall, error injection firing, and `drain_done` reachability. `formal/reset_drain.sby`: BMC checks FSM state encoding, `open` tied to `S_UP` only, `drain_done == all_empty`; cover reaches all three states including a full DOWN→UP→DRAIN→DOWN cycle. Assertions and covers are `FORMAL`-guarded in RTL. CI uses the OSS CAD Suite installer action.
- **Testbench:** `tb_cxl_ucie_bridge` runs smoke tests for every packet kind (CXL.io, CXL.mem, CXL.cache requests; AD_CPL, MEM_CPL, CACHE_CPL completions), an ordering directed test (posted drains before non-posted when both FIFOs are loaded), a link-gating test (de-assert `link_up`, verify `cxl_in_ready=0`, wait for `drain_done`, re-assert and verify normal operation), an error injection test (assert `err_inj_en` for one beat, verify checksum bit 0 is flipped on egress), then stress with concurrent bidirectional traffic, random sink `ready`, and semantic scoreboarding split by ordering class. The `cxl_ucie_bridge_chk` module checks egress **ready/valid** stability rules (valid must not retract, data must not change while valid && !ready) during simulation.
- **Scoreboard behavior:** The testbench uses a reusable per-cycle scoreboard step and explicitly accounts for transfers on the stress-to-drain boundary clock edge before disabling new source traffic.
- **Automation:** The `test/` directory provides a `Makefile` with targets `run`, `vcd` (optional waveform dump to `build/waves.vcd`), and `gtkwave` (regenerate VCD and open GTKWave when available). On Windows, `test/run_sim.ps1` runs the same compile and `vvp` steps when `iverilog`/`vvp` are on `PATH`.

Optional waveform dumps are enabled with the `+vcd` plus argument; GTKWave is used for inspection.

# 7. Repository layout (relevant paths)

| Path | Role |
|------|------|
| `src/sync_fifo.v` | Parameterized synchronous FIFO |
| `src/credit_counter.v` | Parameterized credit counter (consume / return / available) |
| `src/reset_drain.v` | Link-state FSM (DOWN / UP / DRAIN) with link_up gate and drain_done |
| `src/cdc_sync.v` | N-stage CDC synchronizer utility (for future multi-clock use) |
| `src/cxl_ucie_bridge_defs.vh` | Shared packet kinds, field locations, pack helpers, checksum helper |
| `src/cxl_ucie_bridge.v` | Bridge RTL (split c2u FIFOs, credit counters, posted-priority arbiter, link gate, error injection) |
| `src/cxl_ucie_bridge_chk.v` | Simulation checks (egress stability / no valid retraction) |
| `src/tb_cxl_ucie_bridge.v` | Testbench |
| `test/Makefile` | Simulation and waveform targets |
| `test/run_sim.ps1` | Windows-oriented compile + `vvp` helper |
| `formal/sync_fifo.sby` | SymbiYosys bounded BMC for `sync_fifo` (requires `sby`, e.g. OSS CAD Suite) |
| `formal/cxl_ucie_bridge.sby` | SymbiYosys BMC + cover for `cxl_ucie_bridge` (translation, routing, arbiter, link gate, error injection) |
| `formal/reset_drain.sby` | SymbiYosys BMC + cover for `reset_drain` (FSM state encoding, open/drain_done invariants) |
| `doc/design-spec.md` | This specification (source) |
| `doc/Makefile` | PDF build for this document |
| `CONTRIBUTING.md` | Simulation, formal, and CI notes for contributors |

# 8. Roadmap (phased milestones)

Work is expected to proceed roughly in the following order; later phases depend on chosen protocol profiles and tooling.

1. **Narrow first target (done ✓)** — Typed 64-bit packet definitions, simplified `CXL.io` request translation, simplified UCIe completion translation, synchronous FIFO buffering, ready/valid checks, simulation and bounded formal on the FIFO, second-opinion lint (Verilator).
2. **Broaden typed traffic (done ✓)** — Full CXL.io / CXL.mem / CXL.cache packet taxonomy, matching UCIe adapter message families, expanded scoreboarding and formal assertions, GTKWave save file.
3. **Flow control and ordering (done ✓)** — Per-direction credit counters, posted/non-posted ordering domain split, posted-priority egress arbiter, ordering directed test, credit-exhaustion formal covers.
4. **Bring-up and non-ideal behavior (done ✓)** — `reset_drain` link-state FSM, `link_up` readiness gate, `err_inj_en` error injection interface, `cdc_sync` CDC synchronizer utility.

# 9. Future work (detail)

- Expand coverage to constrained-random stimulus and coverage-driven closure (tooling beyond iverilog likely required for advanced methodologies).
- Document **reset and link bring-up** sequences and corresponding RTL interfaces in more detail (Phase 4 provides the FSM skeleton; handshake timing diagrams and sequence documentation remain).
- Expand the design specification with **timing, clocking, and CDC** assumptions as the design adds multiple clock domains or PHY-facing logic (the `cdc_sync` utility is in place; wiring it into the bridge requires a second clock domain input).

# 10. Document control

| Item | Value |
|------|--------|
| Format | Markdown (source), PDF (generated) |
| Revision | Draft — aligned with repository baseline RTL |

This specification is maintained alongside the RTL; discrepancies should be resolved by updating either the document or the implementation and recording the change in revision control.
