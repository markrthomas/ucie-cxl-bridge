class bridge_env extends uvm_env;
  cxl_agent c_agent;
  ucie_agent u_agent;
  bridge_scoreboard sb;
  `uvm_component_utils(bridge_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    c_agent = cxl_agent::type_id::create("c_agent", this);
    u_agent = ucie_agent::type_id::create("u_agent", this);
    sb = bridge_scoreboard::type_id::create("sb", this);
  endfunction
endclass
