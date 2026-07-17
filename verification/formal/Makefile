# SymbiYosys formal targets for ucie-cxl-bridge.
# Run from this directory: make  (or: make -C verification/formal from repo root)
# Requires: sby (SymbiYosys) from OSS CAD Suite or standalone install.
# The .sby files use relative paths (../../../../src/) that resolve correctly
# from the task subdirectories SymbiYosys creates here.

SBY ?= sby

.PHONY: all sync_fifo reset_drain cxl_ucie_bridge payload_fifo clean

all: sync_fifo reset_drain cxl_ucie_bridge payload_fifo
	@echo "[FORMAL] All SymbiYosys checks passed."

sync_fifo:
	$(SBY) -f sync_fifo.sby
	@echo "[FORMAL] sync_fifo: PASS"

reset_drain:
	$(SBY) -f reset_drain.sby
	@echo "[FORMAL] reset_drain: PASS"

cxl_ucie_bridge:
	$(SBY) -f cxl_ucie_bridge.sby
	@echo "[FORMAL] cxl_ucie_bridge: PASS"

payload_fifo:
	$(SBY) -f payload_fifo.sby
	@echo "[FORMAL] payload_fifo: PASS"

clean:
	rm -rf sync_fifo_bmc sync_fifo_cover \
	       reset_drain_bmc reset_drain_cover \
	       cxl_ucie_bridge_bmc cxl_ucie_bridge_cover \
	       payload_fifo_bmc payload_fifo_cover \
	       sync_fifo_ci.sby reset_drain_ci.sby cxl_ucie_bridge_ci.sby payload_fifo_ci.sby

