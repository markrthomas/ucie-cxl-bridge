class bridge_base_seq extends uvm_sequence#(bridge_item);
  `uvm_object_utils(bridge_base_seq)

  function new(string name = "bridge_base_seq");
    super.new(name);
  endfunction

  task body();
    repeat(10) begin
      `uvm_do(req)
    end
  endtask
endclass
