class bridge_item extends uvm_sequence_item;
  rand bit [63:0] data;
  rand int delay;
  cxl_pkt_kind_e kind;

  // Monitor tag: 0 = observed on an ingress port (cxl_in / ucie_in),
  //              1 = observed on an egress port (cxl_out / ucie_out).
  bit is_egress;

  // Scoreboard prediction bookkeeping: payload beats trailing a header.
  int pl_beats;

  `uvm_object_utils_begin(bridge_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(delay, UVM_ALL_ON)
    `uvm_field_enum(cxl_pkt_kind_e, kind, UVM_ALL_ON)
    `uvm_field_int(is_egress, UVM_ALL_ON)
    `uvm_field_int(pl_beats, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "bridge_item");
    super.new(name);
  endfunction

  constraint c_delay { delay inside {[0:10]}; }

  function bit is_posted();
    return (kind == CXL_MEM_WR || kind == CXL_CACHE_WR);
  endfunction

endclass
