# Contributing

## Simulation

From `test/`:

```bash
make clean && make && make stress
```

Optional Verilator lint (from `test/`): `make lint` (expects `verilator` on `PATH`).

## Formal verification

Bounded **bmc** and **cover** for `sync_fifo` are defined in `formal/sync_fifo.sby`. The Yosys script uses a path **relative to each task’s `src/` directory** (`../../../src/sync_fifo.v`) so it resolves correctly under SymbiYosys (do not use `[files]` here with a `../src/...` path: `sby` can emit a `read_verilog` from that path while `cwd` is already `…/src`, which breaks). Locally you need **SymbiYosys** (`sby`) and solvers (for example via [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)):

```bash
cd formal
sby -f sync_fifo.sby
```

Workdirs such as `formal/sync_fifo_bmc/` are listed in `.gitignore`; do not commit them.

## Continuous integration

GitHub Actions runs Icarus simulation, Verilator `--lint-only`, and `sby` on `sync_fifo`. The OSS CAD Suite version is pinned in `.github/workflows/ci.yml` (`OSS_CAD_SUITE_VERSION`) for reproducibility.

## Native WSL vs `/mnt/c`

Keeping a clone on the Linux filesystem (for example under `$HOME/proj/`) avoids cross-filesystem overhead when editing from Windows under `/mnt/c/...`. Either tree is fine; use the same `make` targets from `test/`.
