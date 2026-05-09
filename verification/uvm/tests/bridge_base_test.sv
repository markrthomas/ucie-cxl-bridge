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
    bridge_base_seq seq;
    seq = bridge_base_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.c_agent.sequencer);
    #1000;
    phase.drop_objection(this);
  endtask
endclass
