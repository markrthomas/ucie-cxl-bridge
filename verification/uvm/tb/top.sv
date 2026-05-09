module top;
  import uvm_pkg::*;
  import bridge_pkg::*;

  logic clk;
  logic ucie_clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    ucie_clk = 0;
    forever #5 ucie_clk = ~ucie_clk;
  end

  initial begin
    rst_n = 0;
    #100 rst_n = 1;
  end

  bridge_if b_if(clk, ucie_clk, rst_n);

  cxl_ucie_bridge dut (
    .clk(clk),
    .ucie_clk(ucie_clk),
    .rst_n(rst_n),
    .cxl_in_valid(b_if.cxl_in_valid),
    .cxl_in_data(b_if.cxl_in_data),
    .cxl_in_ready(b_if.cxl_in_ready),
    .ucie_out_valid(b_if.ucie_out_valid),
    .ucie_out_data(b_if.ucie_out_data),
    .ucie_out_ready(b_if.ucie_out_ready),
    .ucie_in_valid(b_if.ucie_in_valid),
    .ucie_in_data(b_if.ucie_in_data),
    .ucie_in_ready(b_if.ucie_in_ready),
    .cxl_out_valid(b_if.cxl_out_valid),
    .cxl_out_data(b_if.cxl_out_data),
    .cxl_out_ready(b_if.cxl_out_ready),
    .link_up(b_if.link_up),
    .err_inj_en(b_if.err_inj_en),
    .drain_done(b_if.drain_done)
  );

  initial begin
    uvm_config_db#(virtual bridge_if)::set(null, "*", "vif", b_if);
    run_test();
  end

endmodule
