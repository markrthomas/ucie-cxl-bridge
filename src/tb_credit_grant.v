`timescale 1ns / 1ps

// Phase 9 directed test: external credit-advertisement (EXT_CREDIT=1).
// Verifies the bridge issues exactly as many packets as the partner grants and
// throttles when the granted-credit pool is empty — for both a clk-domain pool
// (posted C2U) and a ucie_clk-domain pool (cpl U2C).

`include "cxl_ucie_bridge_defs.vh"

module tb_credit_grant;

  localparam integer W = 64;

  reg clk, ucie_clk, rst_n;
  reg         cxl_in_valid;
  reg [W-1:0] cxl_in_data;
  wire        cxl_in_ready;
  wire        ucie_out_valid;
  wire [W-1:0] ucie_out_data;
  reg         ucie_out_ready;
  reg         ucie_in_valid;
  reg [W-1:0] ucie_in_data;
  wire        ucie_in_ready;
  wire        cxl_out_valid;
  wire [W-1:0] cxl_out_data;
  reg         cxl_out_ready;
  reg         link_up, err_inj_en;
  wire        drain_done;

  reg  posted_grant, np_grant, cpl_grant;
  wire posted_credit_return, np_credit_return, cpl_credit_return;

  integer accepts, errors, k;

  cxl_ucie_bridge #(
    .WIDTH(W), .FIFO_DEPTH(8),
    .POSTED_CREDITS(8), .NP_CREDITS(8), .CPL_CREDITS(8),
    .EXT_CREDIT(1)
  ) dut (
    .clk(clk), .ucie_clk(ucie_clk), .rst_n(rst_n),
    .cxl_in_valid(cxl_in_valid), .cxl_in_data(cxl_in_data), .cxl_in_ready(cxl_in_ready),
    .ucie_out_valid(ucie_out_valid), .ucie_out_data(ucie_out_data), .ucie_out_ready(ucie_out_ready),
    .ucie_in_valid(ucie_in_valid), .ucie_in_data(ucie_in_data), .ucie_in_ready(ucie_in_ready),
    .cxl_out_valid(cxl_out_valid), .cxl_out_data(cxl_out_data), .cxl_out_ready(cxl_out_ready),
    .link_up(link_up), .err_inj_en(err_inj_en), .drain_done(drain_done),
    .posted_grant(posted_grant), .np_grant(np_grant), .cpl_grant(cpl_grant),
    .posted_credit_return(posted_credit_return),
    .np_credit_return(np_credit_return),
    .cpl_credit_return(cpl_credit_return)
  );

  always #5 clk = ~clk;
  // ucie_clk phase-shifted so it never shares a timestamp with clk (CDC safety).
  initial begin
    ucie_clk = 1'b0;
    #2.5 forever #5 ucie_clk = ~ucie_clk;
  end

  task fail; input [255:0] msg; begin
    $display("FAIL: %0s", msg); errors = errors + 1;
  end endtask

  initial begin
    clk = 0; rst_n = 0;
    cxl_in_valid = 0; cxl_in_data = 0; ucie_out_ready = 1;
    ucie_in_valid = 0; ucie_in_data = 0; cxl_out_ready = 1;
    link_up = 0; err_inj_en = 0;
    posted_grant = 0; np_grant = 0; cpl_grant = 0;
    errors = 0;

    repeat (6) @(posedge clk);
    rst_n = 1; link_up = 1;
    repeat (10) @(posedge clk);   // let reset_drain reach S_UP (bridge open)

    // ---- Posted pool (clk domain) ----
    // Throttle: 0 credits -> ingress must not accept a posted write.
    cxl_in_data  = pack_cxl_mem_wr(CXL_MEM_OP_WR, 8'h10, 16'h1000, 8'h00, 8'h10, 8'h00);
    cxl_in_valid = 1'b1;
    accepts = 0;
    repeat (8) @(posedge clk) if (cxl_in_valid && cxl_in_ready) accepts = accepts + 1;
    if (accepts != 0) fail("posted issued a packet with zero credits");

    // Grant 3 credits while not consuming (valid low so no simultaneous consume).
    cxl_in_valid = 1'b0;
    for (k = 0; k < 3; k = k + 1) begin
      @(posedge clk); posted_grant = 1'b1;
      @(posedge clk); posted_grant = 1'b0;
    end

    // Now the bridge may issue exactly 3 posted packets, then throttle.
    cxl_in_valid = 1'b1;
    accepts = 0;
    repeat (30) @(posedge clk) if (cxl_in_valid && cxl_in_ready) accepts = accepts + 1;
    if (accepts != 3) fail("posted did not issue exactly the 3 granted credits");
    cxl_in_valid = 1'b0;

    // Exhaustion release: grant 1 more, expect exactly 1 more accept.
    @(posedge clk); posted_grant = 1'b1;
    @(posedge clk); posted_grant = 1'b0;
    cxl_in_valid = 1'b1;
    accepts = 0;
    repeat (20) @(posedge clk) if (cxl_in_valid && cxl_in_ready) accepts = accepts + 1;
    if (accepts != 1) fail("posted release did not issue exactly 1 packet after 1 grant");
    cxl_in_valid = 1'b0;
    if (errors == 0) $display("PASS credit_grant posted");

    // ---- Cpl pool (ucie_clk domain) ----
    ucie_in_data = pack_ucie_ad_cpl(UCIE_CPL_UR, 8'h20, 16'h0020, 8'h00, 8'h20, 8'h00, 8'h00);
    ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(ucie_in_data);

    // Throttle: 0 cpl credits.
    ucie_in_valid = 1'b1;
    accepts = 0;
    repeat (8) @(posedge ucie_clk) if (ucie_in_valid && ucie_in_ready) accepts = accepts + 1;
    if (accepts != 0) fail("cpl issued with zero credits");

    // Grant 2 cpl credits (ucie_clk domain).
    ucie_in_valid = 1'b0;
    for (k = 0; k < 2; k = k + 1) begin
      @(posedge ucie_clk); cpl_grant = 1'b1;
      @(posedge ucie_clk); cpl_grant = 1'b0;
    end

    ucie_in_valid = 1'b1;
    accepts = 0;
    repeat (30) @(posedge ucie_clk) if (ucie_in_valid && ucie_in_ready) accepts = accepts + 1;
    if (accepts != 2) fail("cpl did not issue exactly the 2 granted credits");
    ucie_in_valid = 1'b0;
    if (errors == 0) $display("PASS credit_grant cpl");

    if (errors == 0) $display("PASS credit_grant ALL");
    else             $display("credit_grant FAILED with %0d error(s)", errors);
    $finish(errors == 0 ? 0 : 1);
  end

  // Watchdog
  initial begin
    #200000;
    $display("FAIL: credit_grant timeout");
    $finish(1);
  end

endmodule
