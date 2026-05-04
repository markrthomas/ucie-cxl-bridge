# Run from this directory: make
# Requires: iverilog, vvp (e.g. sudo apt install iverilog)
# Optional: gtkwave (e.g. sudo apt install gtkwave) for make gtkwave

BUILD_DIR := build
SRC_DIR   := ../src
VCD       := $(BUILD_DIR)/waves.vcd

SOURCES := $(SRC_DIR)/async_fifo.v $(SRC_DIR)/credit_counter.v $(SRC_DIR)/reset_drain.v $(SRC_DIR)/cdc_sync.v $(SRC_DIR)/cxl_ucie_bridge.v $(SRC_DIR)/cxl_ucie_bridge_chk.v $(SRC_DIR)/tb_cxl_ucie_bridge.v
OUT     := $(BUILD_DIR)/tb.out

.PHONY: all run sim compile stress vcd gtkwave lint clean

all: run

compile: $(OUT)

run sim: compile
	vvp $(OUT)

# Default smoke + moderate stress; this adds a second phase with harsh sink backpressure.
stress: compile
	vvp $(OUT) +stress

# Regenerate simulation and write $(VCD) (run from this directory so path matches $dumpfile)
vcd: compile
	vvp $(OUT) +vcd

# Generate VCD then open in gtkwave (blocking until gtkwave exits)
gtkwave: vcd
	gtkwave $(VCD) cxl_ucie_bridge.gtkw

$(OUT): $(SOURCES) | $(BUILD_DIR)
	iverilog -g2005-sv -I$(SRC_DIR) -o $@ $(SOURCES)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Verilator second-opinion lint (from repo root paths).
lint:
	cd .. && verilator -Isrc --lint-only -Wall -top-module cxl_ucie_bridge \
		src/async_fifo.v src/credit_counter.v src/reset_drain.v src/cdc_sync.v src/cxl_ucie_bridge.v
	cd .. && verilator -Isrc --lint-only -Wall -top-module async_fifo src/async_fifo.v
	cd .. && verilator -Isrc --lint-only -Wall -top-module cdc_sync src/cdc_sync.v

clean:
	rm -rf $(BUILD_DIR)
