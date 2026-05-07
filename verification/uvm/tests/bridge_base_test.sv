class bridge_base_test extends uvm_test;
  bridge_env env;
  `uvm_component_utils(bridge_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    env = bridge_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #1000;
    phase.drop_objection(this);
  endtask
endclass
