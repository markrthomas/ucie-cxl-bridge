# Development Plan — ucie-cxl-bridge

**As of:** 2026-05-09

## Current baseline (Phase 7)

| Area | Status |
|------|--------|
| RTL | `src/cxl_ucie_bridge.v` — dual-clock async FIFO architecture, granular protocol opcodes, cross-domain credit counters, posted/non-posted ordering domain split, `reset_drain` FSM, **multi-beat payload transport** (per-direction payload FIFOs; C2U split posted/NP; header carries `payload_len`) |
| Formal | SymbiYosys BMC + cover on `sync_fifo`, `reset_drain`, `cxl_ucie_bridge`, and `payload_fifo` |
| Directed tests | `verification/directed/` — lint, stress (payload-carrying), ordering, decode-table, **1/4/16-beat payload bursts**; payload-content checker `cxl_ucie_bridge_payload_chk`; Verilator clean |
| cocotb | `verification/cocotb/` — 11 tests incl. end-to-end payload-content checks each direction |
| UVM | `verification/uvm/` — starter scaffold (independent CXL + UCIe agents, scoreboard skeleton) |
| Known limits | Compact 64-bit packet model; no PHY / link training; credit model is local-counter only |
| State | `main` |

---

## Phase 7 — Multi-beat payload transport

**Goal:** move beyond header-only packets to carry separate data payload beats.

### RTL updates

- Add a `payload_fifo` per direction (CXL-to-UCIe, UCIe-to-CXL) alongside the
  existing header FIFO; depth parameterized independently.
- Extend the arbiter/mux to sequence: header beat → N payload beats → next header.
- Add a `payload_len` field to the opcode decode path so the bridge knows how many
  follow-on beats to forward.
- Keep the credit model consistent: credits gate header issue; payload beats
  drain without additional credit consumption in Phase 7 (simplification).

### Tests

- Directed: 1-beat, 4-beat, 16-beat payload bursts in each direction.
- Scoreboard: match payload content at egress to ingress (new checker module
  `src/cxl_ucie_bridge_payload_chk.v`).
- Formal: add `payload_fifo` safety property file to `verification/formal/`.

### Exit criteria

- `make stress` in `verification/directed/` passes with multi-beat payloads.
- Formal payload FIFO proves no overflow/underflow.
- `README.md` "Known Limits" table updated: payload row removed.

---

## Phase 8 — UVM constrained-random closure

**Goal:** promote UVM from a scaffold to an executable constrained-random regression.

**Status (in progress):** scoreboard is protocol-/ordering-/payload-accurate
(`bridge_scoreboard` + `bridge_predict`); constrained-random *legal* sequences
(`bridge_cxl_seq` / `bridge_ucie_seq`, writes expand to header+payload beats);
base test runs both directions + drains; functional covergroups added
(kind×payload-len, kind×status). Remaining for the UVM env: measure/close
coverage ≥95%, dedicated backpressure sequences, and a 10k-transaction run —
all require a UVM 1.2 simulator (VCS/Questa); not runnable with the OSS
toolchain here.

The **OSS-runnable equivalent** lives in `verification/cocotb`
(`test_random_traffic`): constrained-random legal traffic both directions with
payload expansion, per-transaction translation + payload-content checks, and
functional-coverage closure over kind × direction × status × payload-length
bucket. Note: cocotb must phase-shift `ucie_clk` off `clk` (quarter-period), or
the async-FIFO Gray-pointer CDC syncs race and intermittently stall.

### Updates

- **CXL agent driver:** constrained-random sequence that generates legal
  CXL.io / CXL.mem / CXL.cache requests with randomized opcode, tag, address.
- **UCIe agent monitor:** passive monitor that records ingress packets and feeds
  the scoreboard.
- **Scoreboard:** full completion: compare every CXL request to a corresponding
  UCIe egress packet and vice versa; flag duplicates, drops, and mis-routing.
- **Functional coverage:** opcode cross × direction × payload-length ×
  credit-level; target 95% coverage closure before calling Phase 8 done.
- **Backpressure sequences:** hold `ucie_ready` / `cxl_ready` deasserted for
  random durations; verify no credit underflow and no stall.

### Exit criteria

- `make -C verification/uvm run` passes with constrained-random seeds.
- Coverage report shows ≥ 95% functional coverage on the opcode/direction cross.
- Scoreboard reports PASS with zero mismatches over 10k transactions.

---

## Phase 9 — Credit advertisement protocol

**Goal:** replace the local-counter credit model with an explicit credit
advertisement handshake so the bridge can interoperate with an external flow-control
partner.

### RTL updates

- Define a credit-advertisement channel: `credit_grant` (upstream → bridge) and
  `credit_return` (bridge → upstream) sideband signals.
- Replace the current saturating counter with a received-grant accumulator.
- `credit_pulse_sync` already exists — extend it to carry a grant count rather
  than a single-pulse return.
- Update `cxl_ucie_bridge.v` top-level I/O for both directions.

### Tests

- Directed: partner starts at 0 credits, grants 4, watch bridge throttle and
  then release.
- Directed: credit exhaustion: bridge stalls until a grant arrives.
- Formal: add a property that bridge never issues a packet when local credit
  count is zero.

### Exit criteria

- `verification/directed/` stress test with external credit partner passes.
- Formal credit-safety property verified.
- "Credit model" Known Limits row updated.

---

## Recommended near-term backlog

Implement in this order:

1. **[DONE] Payload FIFO formal property file** (`verification/formal/payload_fifo.sby`)
   — can be written against `sync_fifo` before Phase 7 RTL changes land.
2. **UVM scoreboard wiring** — complete the existing stub before expanding random
   sequences (prevents coverage false-positives).
3. **[DONE] CI directed test job** — add a GitHub Actions job that runs
   `make -C verification/directed stress` (Verilator, no VCS dependency).
4. **[DONE] Opcode decode table unit test** — directed test that hits every opcode in
   `cxl_ucie_bridge_defs.vh`; catches decode regressions cheaply.
5. **[DONE] Phase 7 payload transport** (multi-beat).
6. **Phase 8 UVM closure** (constrained-random).
7. **Phase 9 credit advertisement** (external credit partner).

---

## Longer horizon

| Theme | Aim |
|-------|-----|
| CXL compliance alignment | Map compact 64-bit packet fields to actual CXL.io TLP header layout |
| UCIe adapter layer accuracy | Align adapter-layer framing with UCIe 1.1 Spec §9 |
| PHY / link training stub | Add a `link_train` FSM that accepts PHY status and drives `link_up` |
| Performance monitoring | Add packet-count, stall-cycle, and credit-utilization counters accessible via a CSR-style read port |
| Synthesis flow | Yosys gate-count + timing estimate; FPGA mapping trial |

## How to use this file

- Convert items into GitHub issues with acceptance criteria before starting.
- Update **Current baseline** when a Phase lands.
- Keep `doc/design-spec.md` Section 9 (Roadmap) in sync with the phase list here.
