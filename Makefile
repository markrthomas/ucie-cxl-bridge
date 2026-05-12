# Root Makefile — ucie-cxl-bridge
# Standard DV gate targets consistent with other RTL repos in this workspace.
# Delegates to verification/directed/ (simulation) and verification/formal/ (SymbiYosys).

SBY ?= sby

VERILATOR ?= verilator
VERILATOR_ROOT := $(shell v=$$(command -v verilator 2>/dev/null); [ -n "$$v" ] && realpath "$$(dirname "$$v")/../share/verilator")
VERILATOR_INC  := $(VERILATOR_ROOT)/include
VERILATOR_CPP  := $(VERILATOR_INC)/verilated.cpp $(VERILATOR_INC)/verilated_cov.cpp \
                  $(VERILATOR_INC)/verilated_threads.cpp

BRIDGE_SRCS := src/async_fifo.v src/cdc_sync.v src/credit_counter.v \
               src/credit_pulse_sync.v src/reset_drain.v src/reset_sync.v \
               src/cxl_ucie_bridge.v
COV_DIR := sim/obj_dir_cov

.PHONY: help lint sim regress stress coverage formal ci cocotb clean

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

# coverage: Verilator --coverage build + run; emits sim/coverage.info (lcov format).
coverage:
	@command -v $(VERILATOR) >/dev/null 2>&1 || { echo "[COVERAGE] verilator not on PATH; skipping"; exit 0; }
	rm -rf $(COV_DIR)
	$(VERILATOR) --coverage -cc $(BRIDGE_SRCS) --top-module cxl_ucie_bridge \
		--Mdir $(COV_DIR) -Isrc -Wno-DECLFILENAME -Wno-WIDTH -Wno-fatal
	$(MAKE) -C $(COV_DIR) -f Vcxl_ucie_bridge.mk
	g++ -DVM_COVERAGE=1 -o $(COV_DIR)/sim_cov \
		sim/sim_main.cpp $(COV_DIR)/Vcxl_ucie_bridge__ALL.a \
		-I$(COV_DIR) -I$(VERILATOR_INC) -I$(VERILATOR_INC)/vltstd \
		$(VERILATOR_CPP) -pthread -lm
	cd $(COV_DIR) && ./sim_cov
	@if command -v verilator_coverage >/dev/null 2>&1; then \
		verilator_coverage --write-info ../coverage.info $(COV_DIR)/coverage.dat; \
		echo "[COVERAGE] sim/coverage.info written"; \
	else \
		echo "[COVERAGE] coverage.dat in $(COV_DIR) (install verilator for lcov export)"; \
	fi

# SymbiYosys formal verification (requires OSS CAD Suite or standalone sby).
formal:
	$(MAKE) -C verification/formal

# Comprehensive local run.
ci: regress formal
	@echo "[CI] regress + formal PASSED"

cocotb:
	$(MAKE) -C verification/cocotb

clean:
	$(MAKE) -C verification/directed clean
	rm -rf $(COV_DIR) sim/coverage.info
