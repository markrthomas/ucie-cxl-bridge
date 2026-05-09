---
title: "CXL–UCIe Bridge Design Specification"
subtitle: "Experimental RTL"
date: "May 2026"
---

# 1. Purpose and scope

This document specifies the design intent for an experimental **bridge between Compute Express Link (CXL)** traffic and a **UCIe-compatible adapter-layer interface**. The implementation targets **Verilog** suitable for simulation with **Icarus Verilog** (`iverilog` / `vvp`).

**In scope today:** simulation bring-up, a documented module boundary, a typed packet taxonomy covering CXL.io / CXL.mem / CXL.cache and matching UCIe adapter completions, a dual-clock asynchronous architecture with robust credit-based flow control, and a link bring-up model.

**Out of scope for the current RTL:** full CXL protocol compliance, production UCIe PHY and link training, payload movement, retries, and full link bring-up sequencing.

# 2. Background

CXL defines memory, cache-coherent, and I/O semantics over a PCIe physical layer. UCIe defines die-to-die interconnect including adapter layers that carry protocol flits. A bridge must translate semantic and transport assumptions between these domains while preserving **ordering** where required and honoring **flow control** on both sides.

# 3. Goals

The bridge is intended to support:

1. **Protocol translation** — Map CXL.io, CXL.cache, and CXL.mem concepts to and from UCIe adapter-layer traffic.
2. **Asynchronous Operation** — Support independent clock domains for CXL and UCIe logic.
3. **Credit-based flow control** — Reflect credits available from each side so the bridge does not overrun peer buffers.
4. **Ordering preservation** — Maintain required ordering classes (Posted vs. Non-Posted) between ingress and egress.
5. **Link bring-up model** — Model reset, training handshakes, and readiness gates relevant to safe traffic acceptance.

# 4. Architecture

The bridge provides a low-latency, credit-flow-controlled translation layer between a CXL-facing domain and a UCIe-facing domain.

```mermaid
graph LR
    subgraph "CXL Domain (clk)"
        CI[CXL Ingress]
        CO[CXL Egress]
        RC[Reset Sync]
        CC[Credit Counters]
    end

    subgraph "UCIe Domain (ucie_clk)"
        UI[UCIe Ingress]
        UO[UCIe Egress]
        RU[Reset Sync]
        ARB[Arbiter]
    end

    CI -- Posted --> AF1[Async FIFO] --> ARB --> UO
    CI -- Non-Posted --> AF2[Async FIFO] --> ARB --> UO
    UI -- Completion --> AF3[Async FIFO] --> CO

    ARB -- return pulse --> CC
    CO  -- return pulse --> CC
```

## 4.1 Target architecture (summary)

At a high level, the bridge sits between:
- A **CXL-facing port** (logical aggregation of CXL.io / CXL.cache / CXL.mem).
- A **UCIe-facing port** (adapter-layer ingress and egress).

## 4.2 Current implementation (Phase 6 baseline)

The repository contains a **Phase 6 RTL** featuring a **dual-clock asynchronous architecture**, robust **reset synchronization**, and **granular protocol support**.

### 4.2.0 Implementation block diagram

```mermaid
flowchart LR
    subgraph CXL["CXL clock domain: clk"]
        CIN["cxl_in_* handshake"]
        CLASS["kind classifier"]
        PCRED["posted credit_counter"]
        NCRED["NP credit_counter"]
        LINK["reset_drain FSM"]
        COUT["cxl_out_* handshake"]
    end

    subgraph CDC["Clock-domain crossing"]
        PFIFO["posted async_fifo"]
        NFIFO["non-posted async_fifo"]
        CFIFO["completion async_fifo"]
        PRET["posted credit_pulse_sync"]
        NRET["NP credit_pulse_sync"]
        CRET["completion credit_pulse_sync"]
    end

    subgraph UCIE["UCIe clock domain: ucie_clk"]
        ARB["posted-priority arbiter"]
        UOUT["ucie_out_* handshake"]
        UIN["ucie_in_* handshake"]
        CCRED["completion credit_counter"]
    end

    CIN --> CLASS
    CLASS -->|posted packet| PFIFO --> ARB
    CLASS -->|non-posted packet| NFIFO --> ARB
    ARB --> UOUT
    UIN -->|completion packet| CFIFO --> COUT
    PCRED -. gates posted writes .-> CIN
    NCRED -. gates non-posted writes .-> CIN
    CCRED -. gates completion writes .-> UIN
    ARB -. read return .-> PRET -.-> PCRED
    ARB -. read return .-> NRET -.-> NCRED
    COUT -. read return .-> CRET -.-> CCRED
    LINK -. gates ingress .-> CIN
    LINK -. gates ingress .-> UIN
```

### 4.2.1 Protocol Translation

The bridge performs combinational field remapping on ingress. The mapping for CXL to UCIe is summarized below:

| CXL Kind | CXL Opcode | UCIe Message Type | Ordering Class |
|:---|:---|:---|:---|
| `CXL_IO_REQ` | Any | `UCIE_MSG_CFG` | Non-Posted |
| `CXL_MEM_RD` | `RD` | `UCIE_MSG_MEM_RD` | Non-Posted |
| `CXL_MEM_RD` | `RD_DATA` | `UCIE_MSG_MEM_RD_DATA` | Non-Posted |
| `CXL_MEM_WR` | `WR` | `UCIE_MSG_MEM_WR` | Posted |
| `CXL_MEM_WR` | `WR_DATA` | `UCIE_MSG_MEM_WR_DATA` | Posted |
| `CXL_CACHE_RD` | `RD` | `UCIE_MSG_CACHE_RD` | Non-Posted |
| `CXL_CACHE_RD` | `RD_DATA` | `UCIE_MSG_CACHE_RD_DATA` | Non-Posted |
| `CXL_CACHE_WR` | `WR` | `UCIE_MSG_CACHE_WR` | Posted |
| `CXL_CACHE_WR` | `WR_DATA` | `UCIE_MSG_CACHE_WR_DATA` | Posted |

The UCIe-to-CXL completion path validates the checksum before emitting a completion. A bad checksum or unsupported UCIe packet kind maps to `CXL_PKT_KIND_INVALID`.

| UCIe Kind | Checksum | CXL Kind | Notes |
|:---|:---|:---|:---|
| `UCIE_PKT_KIND_AD_CPL` | Pass | `CXL_PKT_KIND_IO_CPL` | Adapter completion maps to CXL.io completion. |
| `UCIE_PKT_KIND_MEM_CPL` | Pass | `CXL_PKT_KIND_MEM_CPL` | Memory completion status and metadata are preserved. |
| `UCIE_PKT_KIND_CACHE_CPL` | Pass | `CXL_PKT_KIND_CACHE_CPL` | Cache completion status and metadata are preserved. |
| Any supported completion | Fail | `CXL_PKT_KIND_INVALID` | Invalid checksum is converted to an invalid CXL packet. |
| Other UCIe kind | Any | `CXL_PKT_KIND_INVALID` | Unsupported ingress traffic is rejected by translation. |

### 4.2.2 Flow Control (Credits)

Flow control is managed via a **toggle-based credit return mechanism** that safely crosses clock domains without pulse loss. Credits are consumed on FIFO write and returned on FIFO read from the peer domain.

```mermaid
sequenceDiagram
    participant D as Destination Domain (clk_dst)
    participant S as Source Domain (clk_src)
    Note over S: Packet read from FIFO
    S->>S: Toggle src_toggle_r
    S-->>D: Cross CDC (2-flop)
    Note over D: detect toggle change
    D->>D: Pulse dst_pulse (1 cycle)
    D->>D: Increment Credit Counter
```

| Credit Class | Counter Domain | Consumed By | Returned By | Destination Buffer |
|:---|:---|:---|:---|:---|
| Posted | `clk` | `c2u_posted_wr` | `c2u_posted_rd` crossed from `ucie_clk` | `u_c2u_posted` |
| Non-Posted | `clk` | `c2u_np_wr` | `c2u_np_rd` crossed from `ucie_clk` | `u_c2u_np` |
| Completion | `ucie_clk` | `u2c_wr` | `u2c_rd` crossed from `clk` | `u_u2c` |

Ingress `ready` is asserted only when the link is open, the target FIFO is not full in the write domain, and the matching credit counter reports availability. FIFO full protects local storage; credits model downstream capacity.

### 4.2.3 Asynchronous Buffering

Three independent **Asynchronous FIFOs** (`src/async_fifo.v`) handle cross-domain buffering:
- `u_c2u_posted`: CXL Domain Ingress -> UCIe Domain Egress (Posted)
- `u_c2u_np`: CXL Domain Ingress -> UCIe Domain Egress (Non-Posted)
- `u_u2c`: UCIe Domain Ingress -> CXL Domain Egress (Completions)

| FIFO | Write Clock | Read Clock | Read Policy | Empty/Full Use |
|:---|:---|:---|:---|:---|
| `u_c2u_posted` | `clk` | `ucie_clk` | FWFT, read when UCIe accepts selected beat | Write full gates posted CXL ingress. Read empty drives arbiter. |
| `u_c2u_np` | `clk` | `ucie_clk` | FWFT, read when UCIe accepts selected beat | Write full gates non-posted CXL ingress. Read empty drives arbiter. |
| `u_u2c` | `ucie_clk` | `clk` | FWFT, read when CXL accepts completion | Write full gates UCIe ingress. Read empty drives CXL egress valid. |

The async FIFO uses binary pointers locally and synchronizes Gray-coded pointers into the opposite clock domain. `DEPTH` must be a power of two and at least four entries.

### 4.2.4 Ordering and arbitration

The CXL-to-UCIe request path splits posted and non-posted traffic before crossing clock domains. The UCIe egress arbiter gives posted traffic priority when both request classes are non-empty. When `ucie_out_valid` is asserted and `ucie_out_ready` is low, the arbiter locks the selected FIFO until the beat is accepted so `ucie_out_data` remains stable during backpressure.

```mermaid
stateDiagram-v2
    [*] --> Unlocked
    Unlocked --> Unlocked : selected beat accepted
    Unlocked --> Locked : valid && !ready / latch selection
    Locked --> Locked : !ready / hold selection
    Locked --> Unlocked : ready / release selection
```

| Condition | Selected FIFO |
|:---|:---|
| Posted non-empty | Posted |
| Posted empty, non-posted non-empty | Non-posted |
| Both empty | No valid egress beat |
| Backpressured beat in flight | Previously selected FIFO until handshake completes |

# 5. Packet format

The RTL uses a compact 64-bit typed packet format for simulation and formal reasoning. This format is intentionally smaller than real CXL/UCIe protocol headers.

```text
  63      60 59      56 55      48 47              32
 +----------+----------+----------+------------------+
 | kind     | code     | tag/txn  | addr/byte_count  |
 +----------+----------+----------+------------------+
  31      24 23      16 15       8 7                0
 +----------+----------+----------+------------------+
 | length   | id       | aux      | misc/checksum    |
 +----------+----------+----------+------------------+
```

| Field | Bits | CXL Request Meaning | CXL Completion Meaning | UCIe Meaning |
|:---|:---|:---|:---|:---|
| `kind` | `[63:60]` | Packet family such as IO, MEM_RD, MEM_WR, CACHE_RD, CACHE_WR | Completion family | Adapter request/completion/error kind |
| `code` | `[59:56]` | Request opcode | Completion status | Message type or completion status |
| `tag/txn` | `[55:48]` | Request tag | Completion tag | Transaction ID |
| `addr/byte_count` | `[47:32]` | Address slice | Byte count | Address slice or byte count |
| `length` | `[31:24]` | Length in DW | Length in DW | Length in DW |
| `id` | `[23:16]` | Requester ID | Completer ID | Source ID |
| `aux` | `[15:8]` | Attributes or first DW byte enable | Lower address | Attributes or lower address |
| `misc/checksum` | `[7:0]` | Reserved in CXL helpers | Reserved in CXL helpers | CRC-8/CCITT checksum over bits `[63:8]` |

# 6. Interface summary

## 6.1 Common & Control

| Signal | Dir | Domain | Description |
|:---|:---|:---|:---|
| `clk` | In | N/A | CXL domain core clock. |
| `ucie_clk` | In | N/A | UCIe domain core clock. |
| `rst_n` | In | Async | Global asynchronous reset (active low). |
| `link_up` | In | clk | Link status; initiates FSM transitions. |
| `err_inj_en` | In | clk | Enables CRC error injection on next C2U flit. |
| `drain_done` | Out | clk | Asserted when link is DOWN and all buffers are empty. |

## 6.2 CXL Port (CXL Domain)

| Signal | Dir | Description |
|:---|:---|:---|
| `cxl_in_valid` | In | Valid for ingress CXL flit. |
| `cxl_in_ready` | Out | Ready for ingress CXL flit (gated by credits and FIFO space). |
| `cxl_in_data` | In | 64-bit CXL flit data. |
| `cxl_out_valid` | Out | Valid for egress CXL flit (completions). |
| `cxl_out_ready` | In | Ready for egress CXL flit. |
| `cxl_out_data` | Out | 64-bit CXL flit data. |

## 6.3 UCIe Port (UCIe Domain)

| Signal | Dir | Description |
|:---|:---|:---|
| `ucie_in_valid` | In | Valid for ingress UCIe flit. |
| `ucie_in_ready` | Out | Ready for ingress UCIe flit (gated by credits and FIFO space). |
| `ucie_in_data` | In | 64-bit UCIe flit data. |
| `ucie_out_valid` | Out | Valid for egress UCIe flit (requests). |
| `ucie_out_ready` | In | Ready for egress UCIe flit. |
| `ucie_out_data` | Out | 64-bit UCIe flit data. |

# 7. Bring-up and non-ideal behavior

## 7.1 Reset-drain FSM

The `reset_drain` module manages link state transitions.

```mermaid
stateDiagram-v2
    [*] --> S_DOWN : rst_n asserted
    S_DOWN --> S_UP : link_up=1
    S_UP --> S_DRAIN : link_up=0
    S_DRAIN --> S_DOWN : all_empty=1
    
    note right of S_UP : bridge_open=1, Ingress active
    note right of S_DRAIN : bridge_open=0, Egress draining
```

| State | Bridge Status | Behavior |
|:---|:---|:---|
| `S_DOWN` | Closed | Ingress `ready` is deasserted. Logic is idle. |
| `S_UP` | Open | Normal operation; ingress and egress active. |
| `S_DRAIN` | Closed | Ingress `ready` is deasserted. Egress continues to drain existing FIFO contents. |

# 8. Verification

## 8.1 Directed & Stress Tests
- **Simulator:** Icarus Verilog.
- **Suite:** `tb_cxl_ucie_bridge.v` covers every packet kind, ordering rules, link gating, and heavy concurrent stress.

| Test Area | Covered Behavior |
|:---|:---|
| Link gating | Ingress ready deasserts while link is down and resumes after link up. |
| Granular opcodes | CXL.io, CXL.mem, and CXL.cache requests map to expected UCIe message types. |
| Error injection | CRC bit flip produces detectable invalid completion behavior. |
| Clock ratios | Directed smoke runs at 1:1, 2:1, and 1:3 CXL:UCIe clock ratios. |
| Stress | Concurrent bidirectional traffic with randomized sink backpressure. |

## 8.2 Formal Verification
- **Tool:** SymbiYosys (`sby`).
- **Scope:**
    - `sync_fifo.sby`: FIFO safety (no overflow/underflow).
    - `reset_drain.sby`: FSM transition validity.
    - `cxl_ucie_bridge.sby`: End-to-end invariants, credit availability, and protocol mapping correctness.

## 8.3 UVM Environment
- **Location:** `verification/uvm/`.
- **Status:** Starter UVM scaffold for Phase 6. It includes independent CXL and UCIe agents, drivers, monitors, a virtual interface, and a scoreboard skeleton. The executable regression baseline remains the directed testbench.

# 9. Roadmap (phased milestones)

1. **Narrow first target (done)** — Typed 64-bit packet definitions, synchronous FIFO.
2. **Broaden typed traffic (done)** — Full CXL.io / CXL.mem / CXL.cache packet taxonomy.
3. **Flow control and ordering (done)** — Posted/non-posted ordering domain split.
4. **Bring-up and non-ideal behavior (done)** — `reset_drain` link-state FSM.
5. **Dual-clock asynchronous architecture (done)** — Separated `clk` and `ucie_clk` domains.
6. **Advanced Protocol & Flow Control (done)** — Granular opcodes, integrated cross-domain credit counters.

# 10. Implementation limits

| Area | Current Bound |
|:---|:---|
| Header model | Uses a compact 64-bit pedagogical packet format instead of full protocol headers. |
| Payloads | Does not transport separate data payload beats beyond the modeled header/data opcode distinction. |
| CXL compliance | Models selected ordering, completion, and flow-control concepts; it is not a compliant CXL controller. |
| UCIe compliance | Models adapter-layer message carriage and checksums; it does not implement PHY, link training, retry, or sideband. |
| CDC scope | Single-bit controls use two-flop synchronizers; multi-bit packet movement uses async FIFOs. |
| Credit model | Credits are local counters with return pulses; there is no external credit advertisement protocol. |

# 11. Repository layout

| Path | Role |
|------|------|
| `src/async_fifo.v` | Dual-clock asynchronous FIFO. |
| `src/credit_counter.v` | Parameterized credit tracker. |
| `src/credit_pulse_sync.v` | Toggle-based credit pulse synchronizer. |
| `src/reset_sync.v` | Asynchronous assert, synchronous deassert reset handler. |
| `src/cxl_ucie_bridge.v` | Top-level bridge RTL. |
| `verification/` | Directed, Formal, and UVM environments. |
| `doc/` | Design specification and documentation. |
