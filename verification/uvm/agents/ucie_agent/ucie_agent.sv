class ucie_driver extends uvm_driver#(bridge_item);
  virtual bridge_if vif;
  `uvm_component_utils(ucie_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.ucie_in_valid <= 0;
    vif.ucie_out_ready <= 0;

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(bridge_item item);
    repeat(item.delay) @(vif.ucie_cb);
    vif.ucie_cb.ucie_in_data <= item.data;
    vif.ucie_cb.ucie_in_valid <= 1;
    wait(vif.ucie_cb.ucie_in_ready);
    @(vif.ucie_cb);
    vif.ucie_cb.ucie_in_valid <= 0;
  endtask
endclass

class ucie_agent extends uvm_agent;
  ucie_driver driver;
  uvm_sequencer#(bridge_item) sequencer;
  `uvm_component_utils(ucie_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    driver = ucie_driver::type_id::create("driver", this);
    sequencer = uvm_sequencer#(bridge_item)::type_id::create("sequencer", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
