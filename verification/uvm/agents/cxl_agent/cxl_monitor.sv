class cxl_monitor extends uvm_monitor;
  virtual bridge_if vif;
  uvm_analysis_port#(bridge_item) item_collected_port;
  `uvm_component_utils(cxl_monitor)

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
      @(vif.cxl_mon_cb);
      if(vif.cxl_mon_cb.cxl_in_valid && vif.cxl_mon_cb.cxl_in_ready) begin
        bridge_item item = bridge_item::type_id::create("item");
        item.data = vif.cxl_mon_cb.cxl_in_data;
        // Basic mapping for kind (simplified)
        item.kind = cxl_pkt_kind_e'(vif.cxl_mon_cb.cxl_in_data[63:60]); 
        item_collected_port.write(item);
      end
    end
  endtask

  task collect_egress();
    forever begin
      @(vif.cxl_mon_cb);
      if(vif.cxl_mon_cb.cxl_out_valid && vif.cxl_mon_cb.cxl_out_ready) begin
        bridge_item item = bridge_item::type_id::create("item");
        item.data = vif.cxl_mon_cb.cxl_out_data;
        item.kind = cxl_pkt_kind_e'(vif.cxl_mon_cb.cxl_out_data[63:60]);
        item_collected_port.write(item);
      end
    end
  endtask
endclass
