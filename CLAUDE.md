# CLAUDE.md

Orientation auto-loaded into each Claude session in this repo.

## UVM on open-source Verilator (`verification/uvm/vlt`)

License-free way to run this repo's UVM env under **Verilator 5.050** (no
VCS/Xcelium/Questa), added 2026-08-28. **Passing** in CI
(`.github/workflows/verilator-uvm.yml`): builds Verilator from source, installs
**z3** (Verilator's SMT solver for `randomize()` — without it constrained
randomize returns 0) + `ccache`, then lint + the `--binary` `smoke` smoke test.

Local (lint is RAM-safe; the `--binary` build wants a big-RAM host or CI):
```sh
V=~/verilator/bin/verilator ; U=~/verilator/test_regress/t/uvm
( unset VERILATOR_ROOT; make -C verification/uvm/vlt lint   VERILATOR=$V UVM_HOME=$U )
( unset VERILATOR_ROOT; make -C verification/uvm/vlt smoke VERILATOR=$V UVM_HOME=$U )
```
Details: `verification/uvm/vlt/README.md`.
