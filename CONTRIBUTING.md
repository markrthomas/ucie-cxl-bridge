# Contributing

## Simulation

From `test/`:

```bash
make clean && make && make stress
```

Optional Verilator lint (from `test/`): `make lint` (expects `verilator` on `PATH`).

## Formal verification

Bounded **bmc** and **cover** targets are defined for several modules in the `formal/` directory:
- `sync_fifo.sby`: Basic synchronous FIFO safety and reachability.
- `reset_drain.sby`: Link-state FSM state encoding and transitions.
- `cxl_ucie_bridge.sby`: End-to-end bridge invariants including translation, routing, and link-gating.

Locally you need **SymbiYosys** (`sby`) and solvers (for example via [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)):

```bash
cd formal
sby -f cxl_ucie_bridge.sby
```

**CI vs local:** GitHub Actions generates `formal/sync_fifo_ci.sby` from `sync_fifo.sby`, replacing the `read_verilog … ../../../src/sync_fifo.v` line with an **absolute** path under `$GITHUB_WORKSPACE`, so formal does not depend on `sby` task-directory depth on the runner.

SymbiYosys workdirs under `formal/` (e.g. `formal/sync_fifo/`, `formal/sync_fifo_bmc/`, `formal/sync_fifo_cover/`, and `sync_fifo_ci_*` from CI) are listed in `.gitignore`; do not commit them.

## Continuous integration

GitHub Actions runs Icarus simulation, Verilator `--lint-only`, and `sby` on `sync_fifo`. The OSS CAD Suite version is pinned in `.github/workflows/ci.yml` (`OSS_CAD_SUITE_VERSION`) for reproducibility.

## Native WSL vs `/mnt/c`

Keeping a clone on the Linux filesystem (for example under `$HOME/proj/`) avoids cross-filesystem overhead when editing from Windows under `/mnt/c/...`. Either tree is fine; use the same `make` targets from `test/`.

## OSS CAD Suite in WSL (`~/oss-cad-suite`)

Download `oss-cad-suite-linux-x64-*.tgz` from [oss-cad-suite-build releases](https://github.com/YosysHQ/oss-cad-suite-build/releases), place it in `$HOME`, then extract:

```bash
cd ~
tar -xzf oss-cad-suite-linux-x64-*.tgz   # creates ~/oss-cad-suite/
```

Add to `~/.bashrc` (or run once: `bash scripts/wsl-append-oss-bashrc.sh` from this repo on a Unix-line-ending checkout):

```bash
if [ -f "$HOME/oss-cad-suite/environment" ]; then
  source "$HOME/oss-cad-suite/environment"
fi
```

New shells then get `yosys`, `sby`, `iverilog`, `vvp`, `verilator`, etc. on `PATH`. For the current session: `source ~/oss-cad-suite/environment`.
