class ucie_monitor extends uvm_monitor;
  virtual bridge_if vif;
  uvm_analysis_port#(bridge_item) item_collected_port;
  `uvm_component_utils(ucie_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual bridge_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      collect_ingress();
      collect_egress();
    join
  endtask

  task collect_ingress();
    forever begin
      @(vif.ucie_mon_cb);
      if(vif.ucie_mon_cb.ucie_in_valid && vif.ucie_mon_cb.ucie_in_ready) begin
        bridge_item item = bridge_item::type_id::create("item");
        item.data = vif.ucie_mon_cb.ucie_in_data;
        // UCIe kind space differs from cxl_pkt_kind_e; the scoreboard decodes
        // the raw data. Tag the direction so it routes correctly.
        item.is_egress = 1'b0;   // UCIe ingress completion
        item_collected_port.write(item);
      end
    end
  endtask

  task collect_egress();
    forever begin
      @(vif.ucie_mon_cb);
      if(vif.ucie_mon_cb.ucie_out_valid && vif.ucie_mon_cb.ucie_out_ready) begin
        bridge_item item = bridge_item::type_id::create("item");
        item.data = vif.ucie_mon_cb.ucie_out_data;
        item.is_egress = 1'b1;   // UCIe egress request
        item_collected_port.write(item);
      end
    end
  endtask
endclass
