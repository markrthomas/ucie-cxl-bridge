# Random regression (Swarm B)

Seeded runs of the existing self-checking Icarus TB (`src/tb_cxl_ucie_bridge.v`): golden model + scoreboard
(header translation, ordering, payload content via `u_payload_chk`), smoke phases, then a seeded random
stress phase. No new checker is added; `rr.py` only varies seed and config and collects results.

## Contract
- `make rr-build` - compile `verification/random/build/tb.out` (iverilog).
- `make rr N=<jobs> JOBS=<parallel> [SEED=<base>]` - job i runs seed `SEED+i` (default N=10 JOBS=2 SEED=1).
  Writes `verification/random/runs/<UTC>/results.jsonl` (`job, seed, config, status, signature, log, repro`),
  prints `rr run: <dir> seed_base=<s> jobs=<N> fail=<F>`, exits non-zero iff F > 0. `runs/` is git-ignored.
- `make rr-triage RUN=<dir>` - cluster FAILs by normalised signature (count + repro).
- `make rr-replay` - rerun `corpus.json` entries; entries with `"fixed": true` must PASS (exit 1 otherwise).
  `python3 verification/random/rr.py promote --name N --seed S [--config stress=1] --signature SIG` appends one.

## Knobs
| knob | values | effect |
|---|---|---|
| `+seed=N` | any non-zero int | reseeds the TB stress traffic and sink back-pressure; deterministic per seed |
| `stress` | 0 / 1 (odd jobs = 1) | `+stress`: extra heavy phase, sinks ready ~20%. Its seed is fixed in the TB (`C0FFEE01`), so it is not seed-varied |

Smoke phases (link gating, granular opcodes, error injection, decode table, payload bursts, clock ratios) are
directed and seed-independent; only the stress phase varies per seed.

## Known limits
- The payload checker taps the internal payload FIFO read data, not `ucie_out_data`/`cxl_out_data`. Corrupting
  payload bits after the egress mux (`c2u_egr_payload_data ^ 1` on `ucie_out_data`) is NOT caught by this TB
  (verified: 20/20 seeds PASS). The cocotb tier checks payload at the port. See B1.
- Mutation check used: flip bit 8 of the NP header on `ucie_out_data` -> 20/20 FAIL, one cluster
  `FAIL: smoke io_req ucie_out_data got N` (caught by the directed smoke, so seed-independent).

## Stimulus backlog
- B1 Port-level payload scoreboard in the TB (check `ucie_out_data`/`cxl_out_data` payload beats against gold).
- B2 Seed-vary the heavy-stress phase and the sink ready duty cycle (knob `+ready_pct`).
- B3 Randomize header length (payload beats); stress currently uses `{6'h0,seed[7:6]}`.
- B4 Random link_up toggling / reset mid-traffic (reset_drain).
- B5 Random clock ratios (`ucie_clk_half`) per seed.
- B6 Random error injection (bad checksum) in the stress phase.
- B7 Credit-mode (`EXT_CREDIT`) random runs via `tb_credit_grant.v`.
