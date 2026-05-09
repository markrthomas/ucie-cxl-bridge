SIM          ?= icarus
TOPLEVEL_LANG = verilog

SRC_DIR := $(PWD)/../../src

VERILOG_SOURCES = \
    $(SRC_DIR)/async_fifo.v \
    $(SRC_DIR)/credit_counter.v \
    $(SRC_DIR)/credit_pulse_sync.v \
    $(SRC_DIR)/reset_drain.v \
    $(SRC_DIR)/cdc_sync.v \
    $(SRC_DIR)/reset_sync.v \
    $(SRC_DIR)/cxl_ucie_bridge.v

TOPLEVEL = cxl_ucie_bridge
MODULE   = test_cxl_bridge

# SystemVerilog (function automatic) + include path for cxl_ucie_bridge_defs.vh
ICARUS_BIN_DIR ?= /usr/bin
COMPILE_ARGS    = -g2005-sv -I$(SRC_DIR)

export PYTHONPATH := $(PWD):$(PYTHONPATH)

# Strip OSS CAD Suite Python environment so cocotb's pip-installed VPI loads cleanly.
SIM_CMD_PREFIX          := env -u VIRTUAL_ENV -u PYTHONHOME
export PYGPI_PYTHON_BIN := $(shell cocotb-config --python-bin)

include $(shell cocotb-config --makefiles)/Makefile.sim
