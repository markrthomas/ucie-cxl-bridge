class bridge_item extends uvm_sequence_item;
  rand bit [63:0] data;
  rand int delay;

  `uvm_object_utils_begin(bridge_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(delay, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "bridge_item");
    super.new(name);
  endfunction

  constraint c_delay { delay inside {[0:10]}; }
endclass
