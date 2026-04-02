`timescale 1ns / 1ps

// Stress testbench: bursts, random backpressure, concurrent directions, scoreboard.

module tb_cxl_ucie_bridge;

  localparam integer W           = 64;
  localparam integer FIFO_DEPTH  = 8;
  localparam integer NUM_CYCLES  = 4000;
  localparam integer GOLD_SZ     = 16384;

  reg clk;
  reg rst_n;

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

  reg [31:0] seed;
  integer cyc;

  reg [W-1:0] gold_c2u[GOLD_SZ];
  reg [W-1:0] gold_u2c[GOLD_SZ];
  integer     c2u_gold_wr, c2u_gold_rd;
  integer     u2c_gold_wr, u2c_gold_rd;

  integer     c2u_sent, u2c_sent;
  integer     c2u_rcvd, u2c_rcvd;

  cxl_ucie_bridge #(
    .WIDTH      (W),
    .FIFO_DEPTH (FIFO_DEPTH)
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

  function automatic [31:0] rnd32;
    input [31:0] s;
    reg [31:0] x;
    begin
      x     = s;
      x     = x ^ (x << 13);
      x     = x ^ (x >> 17);
      x     = x ^ (x << 5);
      rnd32 = x;
    end
  endfunction

  task automatic scoreboard_step;
    begin
      if (cxl_in_valid && cxl_in_ready) begin
        if (c2u_gold_wr >= GOLD_SZ) begin
          $display("FAIL: gold_c2u overflow");
          $finish(1);
        end
        gold_c2u[c2u_gold_wr] = cxl_in_data;
        c2u_gold_wr         = c2u_gold_wr + 1;
        c2u_sent            = c2u_sent + 1;
      end

      if (ucie_out_valid && ucie_out_ready) begin
        if (c2u_gold_rd >= c2u_gold_wr) begin
          $display("FAIL: c2u pop underrun");
          $finish(1);
        end
        if (ucie_out_data !== gold_c2u[c2u_gold_rd]) begin
          $display("FAIL: c2u data mismatch exp=%h got=%h", gold_c2u[c2u_gold_rd], ucie_out_data);
          $finish(1);
        end
        c2u_gold_rd = c2u_gold_rd + 1;
        c2u_rcvd    = c2u_rcvd + 1;
      end

      if (ucie_in_valid && ucie_in_ready) begin
        if (u2c_gold_wr >= GOLD_SZ) begin
          $display("FAIL: gold_u2c overflow");
          $finish(1);
        end
        gold_u2c[u2c_gold_wr] = ucie_in_data;
        u2c_gold_wr          = u2c_gold_wr + 1;
        u2c_sent             = u2c_sent + 1;
      end

      if (cxl_out_valid && cxl_out_ready) begin
        if (u2c_gold_rd >= u2c_gold_wr) begin
          $display("FAIL: u2c pop underrun");
          $finish(1);
        end
        if (cxl_out_data !== gold_u2c[u2c_gold_rd]) begin
          $display("FAIL: u2c data mismatch exp=%h got=%h", gold_u2c[u2c_gold_rd], cxl_out_data);
          $finish(1);
        end
        u2c_gold_rd = u2c_gold_rd + 1;
        u2c_rcvd    = u2c_rcvd + 1;
      end
    end
  endtask

  initial begin
    clk              = 1'b0;
    rst_n            = 1'b0;
    cxl_in_valid     = 1'b0;
    cxl_in_data      = {W{1'b0}};
    ucie_out_ready   = 1'b0;
    ucie_in_valid    = 1'b0;
    ucie_in_data     = {W{1'b0}};
    cxl_out_ready    = 1'b0;
    seed             = 32'hACE15EED;
    c2u_gold_wr      = 0;
    c2u_gold_rd      = 0;
    u2c_gold_wr      = 0;
    u2c_gold_rd      = 0;
    c2u_sent         = 0;
    u2c_sent         = 0;
    c2u_rcvd         = 0;
    u2c_rcvd         = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // --- Smoke: single beat each direction (same as original sanity) ---
    @(posedge clk);
    cxl_in_data    = 64'hCAFEBABE_DEADBEEF;
    cxl_in_valid   = 1'b1;
    ucie_out_ready = 1'b1;
    @(posedge clk);
    while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
    cxl_in_valid = 1'b0;

    wait (ucie_out_valid);
    @(posedge clk);
    if (ucie_out_data !== 64'hCAFEBABE_DEADBEEF) begin
      $display("FAIL: smoke ucie_out_data got %h", ucie_out_data);
      $finish(1);
    end

    @(posedge clk);
    ucie_in_data   = 64'h0123456789ABCDEF;
    ucie_in_valid  = 1'b1;
    cxl_out_ready  = 1'b1;
    @(posedge clk);
    while (!(ucie_in_valid && ucie_in_ready)) @(posedge clk);
    ucie_in_valid = 1'b0;

    wait (cxl_out_valid);
    @(posedge clk);
    if (cxl_out_data !== 64'h0123456789ABCDEF) begin
      $display("FAIL: smoke cxl_out_data got %h", cxl_out_data);
      $finish(1);
    end

    // --- Stress: concurrent traffic + random ready ---
    c2u_sent = 0;
    u2c_sent = 0;
    c2u_rcvd = 0;
    u2c_rcvd = 0;

    for (cyc = 0; cyc < NUM_CYCLES; cyc = cyc + 1) begin
      @(posedge clk);

      // Scoreboard: transfers complete on this edge (inputs were stable into posedge)
      scoreboard_step();

      // Random sink ready (bias toward often-on to keep queues moving)
      seed           = rnd32(seed);
      ucie_out_ready <= (seed % 5) != 0;
      seed           = rnd32(seed);
      cxl_out_ready  <= (seed % 5) != 0;

      // CXL -> UCIe source
      if (cxl_in_valid && cxl_in_ready) begin
        seed = rnd32(seed);
        if ((seed % 4) == 0)
          cxl_in_valid <= 1'b0;
        else begin
          cxl_in_valid <= 1'b1;
          cxl_in_data  <= cxl_in_data + 64'h00000000_00001001;
        end
      end else if (!cxl_in_valid) begin
        seed = rnd32(seed);
        if ((seed % 3) != 0) begin
          cxl_in_valid <= 1'b1;
          cxl_in_data  <= {32'hA5C20000, 32'h00000000} ^ {16'h0, seed[15:0], seed[31:16], 16'h0};
        end
      end

      // UCIe -> CXL source (independent pattern)
      if (ucie_in_valid && ucie_in_ready) begin
        seed = rnd32(seed);
        if ((seed % 5) == 0)
          ucie_in_valid <= 1'b0;
        else begin
          ucie_in_valid <= 1'b1;
          ucie_in_data  <= ucie_in_data ^ 64'h10000000_00000001;
        end
      end else if (!ucie_in_valid) begin
        seed = rnd32(seed);
        if ((seed % 4) != 0) begin
          ucie_in_valid <= 1'b1;
          ucie_in_data  <= {32'h5A2C0000, 32'h00000000} ^ {seed, seed};
        end
      end
    end

    // Drain: hold both sinks ready, stop new sources
    @(posedge clk);
    // Account for any transfers that complete on the boundary edge
    // before disabling new source traffic.
    scoreboard_step();

    cxl_in_valid   <= 1'b0;
    ucie_in_valid  <= 1'b0;
    ucie_out_ready <= 1'b1;
    cxl_out_ready  <= 1'b1;

    repeat (FIFO_DEPTH + 64) begin
      @(posedge clk);

      if (ucie_out_valid && ucie_out_ready) begin
        if (c2u_gold_rd >= c2u_gold_wr) begin
          $display("FAIL: drain c2u underrun");
          $finish(1);
        end
        if (ucie_out_data !== gold_c2u[c2u_gold_rd]) begin
          $display("FAIL: drain c2u mismatch exp=%h got=%h", gold_c2u[c2u_gold_rd], ucie_out_data);
          $finish(1);
        end
        c2u_gold_rd = c2u_gold_rd + 1;
        c2u_rcvd    = c2u_rcvd + 1;
      end

      if (cxl_out_valid && cxl_out_ready) begin
        if (u2c_gold_rd >= u2c_gold_wr) begin
          $display("FAIL: drain u2c underrun");
          $finish(1);
        end
        if (cxl_out_data !== gold_u2c[u2c_gold_rd]) begin
          $display("FAIL: drain u2c mismatch exp=%h got=%h", gold_u2c[u2c_gold_rd], cxl_out_data);
          $finish(1);
        end
        u2c_gold_rd = u2c_gold_rd + 1;
        u2c_rcvd    = u2c_rcvd + 1;
      end
    end

    if (c2u_gold_rd !== c2u_gold_wr) begin
      $display("FAIL: c2u gold not empty wr=%0d rd=%0d", c2u_gold_wr, c2u_gold_rd);
      $finish(1);
    end
    if (u2c_gold_rd !== u2c_gold_wr) begin
      $display("FAIL: u2c gold not empty wr=%0d rd=%0d", u2c_gold_wr, u2c_gold_rd);
      $finish(1);
    end
    if (ucie_out_valid) begin
      $display("FAIL: ucie_out still valid after drain");
      $finish(1);
    end
    if (cxl_out_valid) begin
      $display("FAIL: cxl_out still valid after drain");
      $finish(1);
    end

    if (c2u_sent !== c2u_rcvd) begin
      $display("FAIL: c2u sent=%0d rcvd=%0d", c2u_sent, c2u_rcvd);
      $finish(1);
    end
    if (u2c_sent !== u2c_rcvd) begin
      $display("FAIL: u2c sent=%0d rcvd=%0d", u2c_sent, u2c_rcvd);
      $finish(1);
    end

    $display("PASS stress c2u_beats=%0d u2c_beats=%0d", c2u_sent, u2c_sent);
    $finish(0);
  end

endmodule
