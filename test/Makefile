# Run from this directory: make
# Requires: iverilog, vvp (e.g. sudo apt install iverilog)
# Optional: gtkwave (e.g. sudo apt install gtkwave) for make gtkwave

BUILD_DIR := build
SRC_DIR   := ../src
VCD       := $(BUILD_DIR)/waves.vcd

SOURCES := $(SRC_DIR)/sync_fifo.v $(SRC_DIR)/cxl_ucie_bridge.v $(SRC_DIR)/tb_cxl_ucie_bridge.v
OUT     := $(BUILD_DIR)/tb.out

.PHONY: all run sim compile stress vcd gtkwave clean

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
	gtkwave $(VCD)

$(OUT): $(SOURCES) | $(BUILD_DIR)
	iverilog -o $@ $(SOURCES)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)
