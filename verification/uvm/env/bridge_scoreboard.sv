class bridge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(bridge_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  // Implement data checking logic here
endclass
