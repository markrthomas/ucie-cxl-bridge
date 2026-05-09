package bridge_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit [3:0] {
    CXL_IO_REQ    = 4'h1,
    CXL_IO_CPL    = 4'h2,
    CXL_MEM_RD    = 4'h3,
    CXL_MEM_WR    = 4'h4,
    CXL_MEM_CPL   = 4'h5,
    CXL_CACHE_RD  = 4'h6,
    CXL_CACHE_WR  = 4'h7,
    CXL_CACHE_CPL = 4'h8,
    CXL_INVALID   = 4'hf
  } cxl_pkt_kind_e;

  `include "bridge_item.sv"
  `include "../seq/bridge_sequences.sv"
  `include "../agents/cxl_agent/cxl_monitor.sv"
  `include "../agents/cxl_agent/cxl_agent.sv"
  `include "../agents/ucie_agent/ucie_monitor.sv"
  `include "../agents/ucie_agent/ucie_agent.sv"
  `include "../env/bridge_scoreboard.sv"
  `include "../env/bridge_env.sv"
  `include "../tests/bridge_base_test.sv"

endpackage
