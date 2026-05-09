# Root Makefile — ucie-cxl-bridge
# Standard DV gate targets consistent with other RTL repos in this workspace.
# Delegates to verification/directed/ (simulation) and verification/formal/ (SymbiYosys).

SBY ?= sby

.PHONY: help lint sim regress stress coverage formal ci clean

help:
	@echo "ucie-cxl-bridge — common targets"
	@echo ""
	@echo "  make lint      — Verilator --lint-only on all RTL modules"
	@echo "  make sim       — Icarus directed simulation (default + smoke)"
	@echo "  make stress    — Icarus simulation with heavy backpressure stress"
	@echo "  make regress   — lint + sim (fast CI gate)"
	@echo "  make coverage  — Verilator C++ coverage (stub; see doc/PLAN.md)"
	@echo "  make formal    — SymbiYosys BMC + cover (sync_fifo, reset_drain, bridge)"
	@echo "  make ci        — regress + formal (comprehensive)"
	@echo "  make clean     — remove simulation build artifacts"
	@echo ""
	@echo "  Subdirectory targets:"
	@echo "    make -C verification/directed [lint|sim|stress|vcd|gtkwave|clean]"
	@echo "    make -C verification/formal   [all|sync_fifo|reset_drain|cxl_ucie_bridge|clean]"
	@echo "    make -C verification/uvm      (VCS UVM stub — local only)"

# Verilator RTL lint (no testbench; delegates to directed/ which runs from repo root).
lint:
	$(MAKE) -C verification/directed lint

# Icarus directed simulation.
sim:
	$(MAKE) -C verification/directed sim

# Icarus simulation with heavy backpressure stress.
stress:
	$(MAKE) -C verification/directed stress

# fast CI gate.
regress: lint sim
	@echo "[REGRESS] lint + directed sim PASSED"

# Verilator C++ coverage wrapper not yet written.
# See doc/PLAN.md Phase 7 and DV_STANDARDS.md in the workspace root.
coverage:
	@echo "[COVERAGE] Verilator C++ wrapper not yet written for this repo."
	@echo "           Add a sim_main.cpp targeting cxl_ucie_bridge to enable --coverage."
	@echo "           See doc/PLAN.md and DV_STANDARDS.md in the workspace root."

# SymbiYosys formal verification (requires OSS CAD Suite or standalone sby).
formal:
	$(MAKE) -C verification/formal

# Comprehensive local run.
ci: regress formal
	@echo "[CI] regress + formal PASSED"

clean:
	$(MAKE) -C verification/directed clean
