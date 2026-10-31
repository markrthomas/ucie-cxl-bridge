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
In an OSS-off shell (`OSS_CAD=0` / `oss-cad-off`) Verilator 5.050 is on `PATH`,
`VERILATOR_ROOT` is unset, and `UVM_HOME` is exported — the vars/`unset` above are
then optional. Details: `verification/uvm/vlt/README.md`.

## Agent swarms (repo notes)
The swarm itself is the shared kit described in the block below; this repo's profile is `.claude/swarm.env`
(envs: `sim cocotb credit`; gate: `make check`; RTL in `src/`; no cross-check target). There is no random regression yet:
`RR_STATUS=bootstrap`, so the first Swarm B run builds `make rr-build/rr/rr-triage/rr-replay` under `verification/random/`
(rr-bootstrap skill) and opens a PR for it.

<!-- swarm-kit:begin (managed by markrthomas/dv-swarm-kit sync.sh — edit the kit, not this block) -->
## Agent swarms, run targets and tokens (swarm-kit)

This repo carries the shared **DV swarm kit** (`markrthomas/dv-swarm-kit`, version in `.claude/swarm-kit.version`).
Its repo-specific settings are **`.claude/swarm.env`** (`make swarm-profile` prints them); everything else in the
kit is identical across repos — change it in the kit and re-sync, never fork it here.

- **Swarm A** — end-to-end re-verification: `make swarm` (`docker/swarm-task.md`; swarm-manager + one
  dv-env-tester per `DV_ENVS` entry + infra-agent + dv-runner).
- **Swarm B** — random regression: `make swarm-rr` (`docker/rr-swarm-task.md`; rr-manager + rr-runner / rr-triage /
  rr-debugger / rr-test-author). With `RR_STATUS=bootstrap` it first builds `make rr-build/rr/rr-triage/rr-replay`
  (the `rr-bootstrap` skill), then flips the flag to `present`.
- Status board: `make board`; workers report via `python3 tools/swarm/board.py` (the `board-report` skill).
- Heavy targets (`HEAVY_TARGETS`) run one at a time: `make heavy T=<target>`. Headless Bash is limited to
  `.claude/settings.json`. `make swarm-dry` shows what a swarm run would execute; `make swarm-kit-check` checks drift.

Doctrine (all agents): verify every claim against a real artifact ("no artifact = not verified"); never weaken or skip
a checker to get green; a skip is "not run", not a pass; keep the RTL assertion-free; DUT behaviour changes are the
owner's call (write them up, don't merge them); branches `swarm/<date>-<topic>`; never push to `main`, never force-push.
Return findings as verdict + evidence (file:line / command + 3-10 line excerpt) + next step — no log dumps.

**Where it runs** (same image everywhere: the Dockerfile `tools` stage, plus the repo for `full`):
| where | how | credentials |
|---|---|---|
| GitHub Actions | Actions → **swarm** → Run workflow (task: Swarm A or B) | repo secret `CLAUDE_CODE_OAUTH_TOKEN` |
| Codespaces | open a Codespace (`.devcontainer/`), then `make swarm`, `make swarm-rr` or `make batch` | Codespaces secret `CLAUDE_CODE_OAUTH_TOKEN`; `GITHUB_TOKEN` is injected |
| Railway | batch service built from `railway.toml` (weekly cron); swarm service: start command `docker/entrypoint.sh swarm [--task docker/rr-swarm-task.md]` | service variables `CLAUDE_CODE_OAUTH_TOKEN` (swarm only) and `GITHUB_TOKEN` (fine-grained PAT: this repo, Contents read+write) |

Batch results go to the `metrics-data` branch (`runs/<UTC>-<sha>/`), never to `main`: automatically on Railway
(when `GITHUB_TOKEN` is set), elsewhere only with `PUBLISH_METRICS=1`. Tokens live only in
GitHub/Codespaces/Railway secret stores — never in the repo, the image, a log or a chat.
<!-- swarm-kit:end -->
