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
    bridge_cxl_seq  cseq;
    bridge_ucie_seq useq;
    cseq = bridge_cxl_seq::type_id::create("cseq");
    useq = bridge_ucie_seq::type_id::create("useq");
    if (!cseq.randomize()) `uvm_fatal("RAND", "cseq randomize failed");
    if (!useq.randomize()) `uvm_fatal("RAND", "useq randomize failed");

    phase.raise_objection(this);
    // Concurrent bidirectional legal traffic on both clock domains.
    fork
      cseq.start(env.c_agent.sequencer);
      useq.start(env.u_agent.sequencer);
    join
    // Drain: let in-flight headers + payload beats propagate and egress complete
    // before the scoreboard's check_phase verifies all queues are empty.
    #20000;
    phase.drop_objection(this);
  endtask
endclass
