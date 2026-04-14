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

SymbiYosys workdirs under `formal/` (e.g. `formal/sync_fifo/`, `formal/sync_fifo_bmc/`, `formal/sync_fifo_cover/`) are listed in `.gitignore`; do not commit them.

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
