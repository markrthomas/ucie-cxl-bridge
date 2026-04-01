`timescale 1ns / 1ps

// Simple testbench for cxl_ucie_bridge (iverilog).

module tb_cxl_ucie_bridge;

  // Run: vvp ... +vcd  → writes build/waves.vcd (path matches test/Makefile cwd)

  localparam integer W = 64;

  reg clk;
  reg rst_n;

  reg        cxl_in_valid;
  reg [W-1:0] cxl_in_data;
  wire       cxl_in_ready;
  wire       ucie_out_valid;
  wire [W-1:0] ucie_out_data;
  reg        ucie_out_ready;

  reg        ucie_in_valid;
  reg [W-1:0] ucie_in_data;
  wire       ucie_in_ready;
  wire       cxl_out_valid;
  wire [W-1:0] cxl_out_data;
  reg        cxl_out_ready;

  cxl_ucie_bridge #(
    .WIDTH(W)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .cxl_in_valid(cxl_in_valid),
    .cxl_in_data(cxl_in_data),
    .cxl_in_ready(cxl_in_ready),
    .ucie_out_valid(ucie_out_valid),
    .ucie_out_data(ucie_out_data),
    .ucie_out_ready(ucie_out_ready),
    .ucie_in_valid(ucie_in_valid),
    .ucie_in_data(ucie_in_data),
    .ucie_in_ready(ucie_in_ready),
    .cxl_out_valid(cxl_out_valid),
    .cxl_out_data(cxl_out_data),
    .cxl_out_ready(cxl_out_ready)
  );

  initial begin
    if ($test$plusargs("vcd")) begin
      $dumpfile("build/waves.vcd");
      $dumpvars(0, tb_cxl_ucie_bridge);
    end
  end

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    cxl_in_valid = 1'b0;
    cxl_in_data = {W{1'b0}};
    ucie_out_ready = 1'b0;
    ucie_in_valid = 1'b0;
    ucie_in_data = {W{1'b0}};
    cxl_out_ready = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // CXL -> UCIe: one beat
    @(posedge clk);
    cxl_in_data = 64'hCAFEBABE_DEADBEEF;
    cxl_in_valid = 1'b1;
    ucie_out_ready = 1'b1;
    @(posedge clk);
    while (!cxl_in_ready) @(posedge clk);
    cxl_in_valid = 1'b0;

    wait (ucie_out_valid);
    @(posedge clk);
    if (ucie_out_data !== 64'hCAFEBABE_DEADBEEF) begin
      $display("FAIL: ucie_out_data=%h", ucie_out_data);
      $finish(1);
    end

    // UCIe -> CXL: one beat
    @(posedge clk);
    ucie_in_data = 64'h0123456789ABCDEF;
    ucie_in_valid = 1'b1;
    cxl_out_ready = 1'b1;
    @(posedge clk);
    while (!ucie_in_ready) @(posedge clk);
    ucie_in_valid = 1'b0;

    wait (cxl_out_valid);
    @(posedge clk);
    if (cxl_out_data !== 64'h0123456789ABCDEF) begin
      $display("FAIL: cxl_out_data=%h", cxl_out_data);
      $finish(1);
    end

    $display("PASS");
    $finish(0);
  end

endmodule
