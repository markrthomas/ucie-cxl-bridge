class cxl_driver extends uvm_driver#(bridge_item);
  virtual bridge_if vif;
  `uvm_component_utils(cxl_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.cxl_in_valid <= 0;
    vif.cxl_out_ready <= 0;
    vif.link_up <= 1;
    vif.err_inj_en <= 0;

    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(bridge_item item);
    repeat(item.delay) @(vif.cxl_cb);
    vif.cxl_cb.cxl_in_data <= item.data;
    vif.cxl_cb.cxl_in_valid <= 1;
    wait(vif.cxl_cb.cxl_in_ready);
    @(vif.cxl_cb);
    vif.cxl_cb.cxl_in_valid <= 0;
  endtask
endclass

class cxl_agent extends uvm_agent;
  cxl_driver driver;
  cxl_monitor monitor;
  uvm_sequencer#(bridge_item) sequencer;
  `uvm_component_utils(cxl_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    driver = cxl_driver::type_id::create("driver", this);
    monitor = cxl_monitor::type_id::create("monitor", this);
    sequencer = uvm_sequencer#(bridge_item)::type_id::create("sequencer", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
