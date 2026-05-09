# UVM Testbench for CXL-UCIe Bridge

This directory contains a UVM-based verification environment for the CXL-UCIe bridge, designed for use with Synopsys VCS. It provides a scalable, constrained-random alternative to the primary directed testbench.

## Architecture Overview

The environment follows a standard UVM architecture, isolating the Design Under Test (DUT) from stimulus generation and checking logic.

```mermaid
graph TD
    subgraph "UVM Testbench (verification/uvm)"
        Test["bridge_base_test"] --> Env["bridge_env"]
        subgraph "bridge_env"
            Env --> CXL_Agent["cxl_agent"]
            Env --> UCIE_Agent["ucie_agent"]
            Env --> SB["bridge_scoreboard"]
            
            subgraph "cxl_agent"
                CXL_SQ["sequencer"] --> CXL_DRV["driver"]
                CXL_DRV --> CXL_IF["bridge_if (CXL side)"]
            end
            
            subgraph "ucie_agent"
                UCIE_SQ["sequencer"] --> UCIE_DRV["driver"]
                UCIE_DRV --> UCIE_IF["bridge_if (UCIe side)"]
            end
        end
    end
    
    CXL_IF --> DUT["cxl_ucie_bridge (RTL)"]
    UCIE_IF --> DUT
```

## Directory Structure

| Path | Responsibility |
|:---|:---|
| `tb/top.sv` | SystemVerilog top; clock/reset generation; interface instantiation. |
| `tb/bridge_if.sv` | Virtual interface with clocking blocks for CXL and UCIe domains. |
| `tb/bridge_pkg.sv` | Global package importing UVM and local components. |
| `agents/cxl_agent/` | CXL-side driver, monitor, sequencer, and agent logic. |
| `agents/ucie_agent/` | UCIe-side driver, monitor, sequencer, and agent logic. |
| `env/` | Orchestration layer (environment and scoreboard). |
| `seq/` | Reusable sequence library for protocol-specific stimulus. |
| `tests/` | Test library defining specific test scenarios and configurations. |

## Verification Components

### 1. Agents and Drivers
The testbench uses two independent agents to drive the CXL and UCIe interfaces.
- **CXL Driver/Monitor**: Handles the `cxl_in_*` and `cxl_out_*` signals. The driver converts `bridge_item` transactions to valid/ready handshakes, while the monitor observes and reports all traffic in the CXL domain.
- **UCIe Driver/Monitor**: Manages the `ucie_in_*` and `ucie_out_*` signals. The monitor observes traffic in the UCIe domain, facilitating cross-domain checking in the scoreboard.

### 2. Scoreboard and Checking
The `bridge_scoreboard` is responsible for end-to-end data integrity across the dual-clock boundary. It tracks in-flight transactions and verifies:
- **CXL -> UCIe**: Correct mapping of CXL request kinds to UCIe messages and accurate checksum calculation.
- **UCIe -> CXL**: Accurate checksum verification and mapping of completions back to CXL kinds.

### 3. Transaction Model (`bridge_item`)
The `bridge_item` represents a single 64-bit packet beat with protocol metadata.

| Field | Bits | Description |
|:---|:---|:---|
| `data` | [63:0] | Raw 64-bit flit payload. |
| `kind` | [3:0]  | CXL packet kind (enum). |
| `delay` | N/A | Inter-transaction delay (constrained-random). |


## Requirements

- **Simulator**: Synopsys VCS
- **Methodology**: UVM 1.2
- **Documentation Build**: `pandoc` + `pdflatex` (for PDF generation)

## Running with VCS

To compile and run the testbench:

```bash
vcs -sverilog -ntb_opts uvm-1.2 \
    +incdir+../../../src \
    +incdir+./tb \
    +incdir+./agents/cxl_agent \
    +incdir+./agents/ucie_agent \
    +incdir+./env \
    +incdir+./seq \
    +incdir+./tests \
    ../../../src/cxl_ucie_bridge.v \
    ./tb/bridge_pkg.sv \
    ./tb/top.sv \
    -o simv

./simv +UVM_TESTNAME=bridge_base_test
```

## Documentation

To generate a PDF version of this documentation:

```bash
make pdf
```
