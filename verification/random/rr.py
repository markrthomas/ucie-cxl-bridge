#!/usr/bin/env python3
"""Random regression driver for ucie-cxl-bridge (Icarus, directed TB scoreboard).

Each job runs the existing self-checking TB (src/tb_cxl_ucie_bridge.v: golden
model + scoreboard, smoke phases + seeded random stress) with +seed=<N>.
Odd jobs add +stress (second heavy-backpressure phase). No new checker.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(HERE, "build")
OUT = os.path.join(BUILD, "tb.out")
SRCS = ["async_fifo", "credit_counter", "credit_pulse_sync", "reset_drain", "cdc_sync",
        "reset_sync", "cxl_ucie_bridge", "cxl_ucie_bridge_chk",
        "cxl_ucie_bridge_payload_chk", "tb_cxl_ucie_bridge"]
CORPUS = os.path.join(HERE, "corpus.json")
TIMEOUT = 300


def build(a=None):
    os.makedirs(BUILD, exist_ok=True)
    cmd = ["iverilog", "-g2005-sv", "-I", os.path.join(ROOT, "src"), "-o", OUT] + \
          [os.path.join(ROOT, "src", s + ".v") for s in SRCS]
    return subprocess.call(cmd)


def signature(text, rc, timed_out):
    if timed_out:
        return "TIMEOUT"
    for ln in text.splitlines():
        if ln.startswith("FAIL") or "ASSERT FAIL" in ln:
            # normalise numbers/hex so the same check clusters together
            s = re.sub(r"0x[0-9a-fA-F]+|\b[0-9a-fA-F]{8,}\b|\d+", "N", ln)
            return s.strip()[:120]
    if "PASS stress" not in text:
        return "no PASS stress marker (rc=%s)" % rc
    return ""


def run_one(seed, stress, logdir, job):
    args = ["vvp", OUT, "+seed=%d" % seed] + (["+stress"] if stress else [])
    log = os.path.join(logdir, "job%03d_seed%d.log" % (job, seed))
    timed_out = False
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=TIMEOUT)
        text, rc = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired:
        text, rc, timed_out = "timeout", -1, True
    with open(log, "w") as f:
        f.write(text)
    sig = signature(text, rc, timed_out)
    bad = bool(sig) or rc != 0
    if bad and not sig:
        sig = "nonzero exit rc=%s" % rc
    return {"job": job, "seed": seed, "config": "stress=%d" % (1 if stress else 0),
            "status": "FAIL" if bad else "PASS", "signature": sig,
            "log": os.path.relpath(log, ROOT),
            "repro": "make rr-build && vvp verification/random/build/tb.out +seed=%d%s" %
                     (seed, " +stress" if stress else "")}


def cmd_run(a):
    build()
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    rdir = os.path.join(HERE, "runs", ts)
    os.makedirs(rdir, exist_ok=True)
    jobs = [(a.seed + i, i % 2 == 1, i) for i in range(a.n)]
    with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        res = list(ex.map(lambda j: run_one(j[0], j[1], rdir, j[2]), jobs))
    with open(os.path.join(rdir, "results.jsonl"), "w") as f:
        for r in res:
            f.write(json.dumps(r) + "\n")
    fails = sum(r["status"] == "FAIL" for r in res)
    print("rr run: %s seed_base=%d jobs=%d fail=%d" % (os.path.relpath(rdir, ROOT), a.seed, a.n, fails))
    return 1 if fails else 0


def cmd_triage(a):
    d = a.run if os.path.isabs(a.run) else os.path.join(ROOT, a.run)
    rows = [json.loads(l) for l in open(os.path.join(d, "results.jsonl")) if l.strip()]
    cl = {}
    for r in rows:
        if r["status"] == "FAIL":
            cl.setdefault(r["signature"], []).append(r)
    for sig, rs in sorted(cl.items(), key=lambda kv: -len(kv[1])):
        print("cluster count=%d sig=%r repro: %s" % (len(rs), sig, rs[0]["repro"]))
    print("triage: %d fails in %d clusters (of %d jobs)" % (sum(map(len, cl.values())), len(cl), len(rows)))
    return 0


def cmd_replay(a):
    corpus = json.load(open(CORPUS)) if os.path.exists(CORPUS) else []
    build()
    bad = 0
    logdir = os.path.join(BUILD, "replay")
    os.makedirs(logdir, exist_ok=True)
    for i, e in enumerate(corpus):
        r = run_one(e["seed"], "stress=1" in e.get("config", "stress=0"), logdir, i)
        fixed = e.get("fixed", False)
        ok = (r["status"] == "PASS") if fixed else True
        print("replay %s seed=%d fixed=%s -> %s%s" % (e.get("name", i), e["seed"], fixed,
              r["status"], "" if ok else "  <-- REGRESSION"))
        bad += (not ok)
    print("rr replay: %d entries, %d regressions" % (len(corpus), bad))
    return 1 if bad else 0


def cmd_promote(a):
    corpus = json.load(open(CORPUS)) if os.path.exists(CORPUS) else []
    corpus.append({"name": a.name, "seed": a.seed, "config": a.config,
                   "signature": a.signature, "fixed": False})
    with open(CORPUS, "w") as f:
        json.dump(corpus, f, indent=2)
        f.write("\n")
    return 0


def main():
    p = argparse.ArgumentParser()
    s = p.add_subparsers(dest="c", required=True)
    s.add_parser("build").set_defaults(f=build)
    r = s.add_parser("run")
    r.set_defaults(f=cmd_run)
    r.add_argument("--n", type=int, default=10)
    r.add_argument("--jobs", type=int, default=2)
    r.add_argument("--seed", type=int, default=1)
    t = s.add_parser("triage")
    t.set_defaults(f=cmd_triage)
    t.add_argument("run")
    s.add_parser("replay").set_defaults(f=cmd_replay)
    pr = s.add_parser("promote")
    pr.set_defaults(f=cmd_promote)
    pr.add_argument("--name", required=True)
    pr.add_argument("--seed", type=int, required=True)
    pr.add_argument("--config", default="stress=0")
    pr.add_argument("--signature", default="")
    a = p.parse_args()
    sys.exit(a.f(a))


if __name__ == "__main__":
    main()
