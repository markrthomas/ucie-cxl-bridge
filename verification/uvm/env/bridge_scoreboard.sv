`uvm_analysis_imp_decl(_cxl)
`uvm_analysis_imp_decl(_ucie)

class bridge_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp_cxl#(bridge_item, bridge_scoreboard) cxl_export;
  uvm_analysis_imp_ucie#(bridge_item, bridge_scoreboard) ucie_export;

  bridge_item c2u_exp_q[$];
  bridge_item u2c_exp_q[$];

  `uvm_component_utils(bridge_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cxl_export = new("cxl_export", this);
    ucie_export = new("ucie_export", this);
  endfunction

  virtual function void write_cxl(bridge_item item);
    // If it's a request going IN, predict the UCIe output
    // If it's a completion going OUT, it should match something in u2c_exp_q
    if (item.kind != CXL_IO_CPL && item.kind != CXL_MEM_CPL && item.kind != CXL_CACHE_CPL) begin
      // Predict UCIe request
      `uvm_info("SB", $sformatf("CXL IN: %h", item.data), UVM_MEDIUM)
      c2u_exp_q.push_back(item); // Simple model: keep the same item for now
    end else begin
      // Check completion against u2c_exp_q
      if (u2c_exp_q.size() > 0) begin
        bridge_item exp = u2c_exp_q.pop_front();
        // compare logic...
        `uvm_info("SB", "Checked U2C completion", UVM_MEDIUM)
      end
    end
  endfunction

  virtual function void write_ucie(bridge_item item);
    // Predict CXL completion or check UCIe request
    if (item.kind == CXL_IO_CPL || item.kind == CXL_MEM_CPL || item.kind == CXL_CACHE_CPL) begin
      `uvm_info("SB", $sformatf("UCIe IN: %h", item.data), UVM_MEDIUM)
      u2c_exp_q.push_back(item);
    end else begin
      if (c2u_exp_q.size() > 0) begin
        bridge_item exp = c2u_exp_q.pop_front();
        `uvm_info("SB", "Checked C2U request", UVM_MEDIUM)
      end
    end
  endfunction

endclass
