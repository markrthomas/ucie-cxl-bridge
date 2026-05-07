# UVM Testbench for CXL-UCIe Bridge

This directory contains a UVM-based verification environment for the CXL-UCIe bridge, designed for use with Synopsys VCS.

## Directory Structure

- `tb/`: Top-level testbench, interfaces, and packages.
- `agents/`: UVM agents for CXL and UCIe interfaces.
- `env/`: UVM environment combining agents and scoreboards.
- `seq/`: UVM sequences for stimulus generation.
- `tests/`: UVM test cases.

## Requirements

- Synopsys VCS
- UVM 1.2 (or compatible)

## Running with VCS

To compile and run the testbench using VCS:

```bash
vcs -sverilog -ntb_opts uvm-1.2 \
    +incdir+../../../src \
    +incdir+../tb \
    +incdir+../agents/cxl_agent \
    +incdir+../agents/ucie_agent \
    +incdir+../env \
    +incdir+../seq \
    +incdir+../tests \
    ../../../src/cxl_ucie_bridge.v \
    ../tb/bridge_pkg.sv \
    ../tb/top.sv \
    -o simv

./simv +UVM_TESTNAME=bridge_base_test
```

## Environment Overview

The environment mirrors the directed testbench but adds:
- **Functional Coverage:** Track protocol coverage.
- **Scoreboarding:** Automated end-to-end data integrity checks.
- **Randomization:** Stress the design with constrained-random traffic.

## Documentation

To generate a PDF version of this documentation (requires `pandoc` and a LaTeX engine):

```bash
make pdf
```
