# Verilator UVM flow for the CXL<->UCIe bridge UVM environment
# (../ = verification/uvm; RTL in <repo>/src).
#
# Runs the *same* SystemVerilog UVM env as a commercial simulator would, but
# under open-source Verilator (>= 5.050) with the Accellera UVM 2020.3.1 library
# bundled in the Verilator source tree (test_regress/t/uvm).
#
# Quick start (local lint is RAM-safe; the full --binary build belongs in CI):
#   V=~/verilator/bin/verilator ; U=~/verilator/test_regress/t/uvm
#   ( unset VERILATOR_ROOT; make -C verification/uvm/vlt lint  VERILATOR=$V UVM_HOME=$U )
#   ( unset VERILATOR_ROOT; make -C verification/uvm/vlt smoke VERILATOR=$V UVM_HOME=$U )

VERILATOR ?= verilator

UVM_HOME ?= $(error Set UVM_HOME to the bundled Verilator UVM dir, e.g. \
  ~/verilator/test_regress/t/uvm)
UVM_HDR := $(UVM_HOME)/uvm_pkg_all_v2020_3_1_dpi.svh
UVM_DPI := $(UVM_HOME)/v2020_3_1/dpi/uvm_dpi.cc

BUILD_JOBS ?= 1
UVM_TEST   ?= bridge_base_test

VFLAGS ?= --binary --timing --vpi -j $(BUILD_JOBS) --build-jobs $(BUILD_JOBS) \
          -Wno-fatal -Wno-COVERIGN -Wno-TIMESCALEMOD --CFLAGS -O0
UVM_PLUSARGS ?= +UVM_NO_RELNOTES

VLT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
UVMROOT := $(abspath $(VLT_DIR)/..)
TB      := $(UVMROOT)/tb
SRC     := $(abspath $(VLT_DIR)/../../../src)
OBJ     := $(VLT_DIR)/obj

INCS := +incdir+$(TB) +incdir+$(VLT_DIR) +incdir+$(SRC) +incdir+$(UVM_HOME)

# RTL: all src/*.v except the standalone tb_* Verilog testbenches.
RTL  := $(filter-out %/tb_%,$(wildcard $(SRC)/*.v))
# Order: interface, RTL (module order is resolved by Verilator), UVM package
# (pulls in the env via `include), then the TB top.
SRCS := $(TB)/bridge_if.sv $(RTL) $(TB)/bridge_pkg.sv $(TB)/top.sv

define build
	rm -rf $(OBJ)/top
	mkdir -p $(OBJ)/top
	$(VERILATOR) $(VFLAGS) --top-module top --Mdir $(OBJ)/top \
	  $(INCS) $(UVM_HDR) $(UVM_DPI) $(SRCS)
endef
define run
	$(OBJ)/top/Vtop $(UVM_PLUSARGS) +UVM_TESTNAME=$(1)
endef

.PHONY: all build smoke lint clean

all: smoke

build:
	$(build)

# The TB top calls run_test() with no default, so the test is chosen here.
smoke: build
	$(call run,$(UVM_TEST))

LINTFLAGS ?= --lint-only --timing -Wno-fatal -Wno-COVERIGN -Wno-TIMESCALEMOD
lint:
	$(VERILATOR) $(LINTFLAGS) --top-module top $(INCS) $(UVM_HDR) $(SRCS)

clean:
	rm -rf $(OBJ)
