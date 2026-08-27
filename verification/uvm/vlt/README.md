# UVM on open-source Verilator (`verification/uvm/vlt`)

Runs the CXL<->UCIe bridge UVM environment under open-source **Verilator 5.050**
(the first Verilator that can elaborate/run UVM) with the bundled Accellera UVM
2020.3.1 library — a license-free path (no VCS/Xcelium/Questa needed).

## Prerequisites
- **Verilator >= 5.050, UVM-capable** (OSS CAD Suite's is not). Local ref:
  `~/verilator/bin/verilator`. **`unset VERILATOR_ROOT`** after sourcing the OSS
  CAD Suite env. **`UVM_HOME`** = `~/verilator/test_regress/t/uvm`.

## Usage
```sh
V=~/verilator/bin/verilator ; U=~/verilator/test_regress/t/uvm
( unset VERILATOR_ROOT; make -C verification/uvm/vlt lint  VERILATOR=$V UVM_HOME=$U )  # RAM-safe
( unset VERILATOR_ROOT; make -C verification/uvm/vlt smoke VERILATOR=$V UVM_HOME=$U )  # build + run bridge_base_test
```
Top `top`; test via `+UVM_TESTNAME` (default `bridge_base_test`, override with
`UVM_TEST=<name>`). The `--binary` build belongs in CI
(`.github/workflows/verilator-uvm.yml`), not a RAM-constrained host.

## `uvm_macros.svh`
Required tracked empty include-shim (the monolithic UVM header defines the
macros). Do not delete.
