`timescale 1ns / 1ps

// Stress testbench: bursts, random backpressure, concurrent directions, scoreboard.
// Phase 3: split c2u scoreboard (posted vs. NP), ordering directed test.

`include "cxl_ucie_bridge_defs.vh"

module tb_cxl_ucie_bridge;

  localparam integer W                 = 64;
  localparam integer FIFO_DEPTH       = 8;
  localparam integer NUM_CYCLES       = 4000;
  localparam integer NUM_STRESS_HEAVY = 12000;
  localparam integer GOLD_SZ          = 32768;

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
  integer p1_c2u_sent, p1_u2c_sent;

  // c2u gold queues split by ordering class
  reg [W-1:0] gold_c2u_posted[GOLD_SZ];
  reg [W-1:0] gold_c2u_np[GOLD_SZ];
  integer     c2u_posted_gold_wr, c2u_posted_gold_rd;
  integer     c2u_np_gold_wr,     c2u_np_gold_rd;

  reg [W-1:0] gold_u2c[GOLD_SZ];
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

  cxl_ucie_bridge_chk #(.WIDTH(W)) u_chk (
    .clk(clk),
    .rst_n(rst_n),
    .ucie_out_valid(ucie_out_valid),
    .ucie_out_data(ucie_out_data),
    .ucie_out_ready(ucie_out_ready),
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

  // Gold model: mirrors translate_cxl_to_ucie in the bridge RTL.
  function automatic [63:0] expect_ucie_from_cxl;
    input [63:0] cxl_pkt;
    reg [63:0] raw_pkt;
    reg [7:0] attr;
    begin
      case (cxl_pkt[PKT_KIND_MSB:PKT_KIND_LSB])
        CXL_PKT_KIND_IO_REQ: begin
          attr = cxl_pkt[PKT_AUX_MSB:PKT_AUX_LSB] ^
                 cxl_pkt[PKT_MISC_MSB:PKT_MISC_LSB];
          raw_pkt = pack_ucie_ad_req(
            (cxl_pkt[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_IO_OP_CFG_RD) ||
            (cxl_pkt[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_IO_OP_CFG_WR) ?
              UCIE_MSG_CFG : UCIE_MSG_MEM,
            cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
            cxl_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
            cxl_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
            cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
            attr,
            8'h00
          );
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          expect_ucie_from_cxl = raw_pkt;
        end
        CXL_PKT_KIND_MEM_RD: begin
          attr = cxl_pkt[PKT_AUX_MSB:PKT_AUX_LSB] ^
                 cxl_pkt[PKT_MISC_MSB:PKT_MISC_LSB];
          raw_pkt = pack_ucie_ad_req(
            UCIE_MSG_MEM_RD,
            cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
            cxl_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
            cxl_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
            cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
            attr,
            8'h00
          );
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          expect_ucie_from_cxl = raw_pkt;
        end
        CXL_PKT_KIND_MEM_WR: begin
          attr = cxl_pkt[PKT_AUX_MSB:PKT_AUX_LSB] ^
                 cxl_pkt[PKT_MISC_MSB:PKT_MISC_LSB];
          raw_pkt = pack_ucie_ad_req(
            UCIE_MSG_MEM_WR,
            cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
            cxl_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
            cxl_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
            cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
            attr,
            8'h00
          );
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          expect_ucie_from_cxl = raw_pkt;
        end
        CXL_PKT_KIND_CACHE_RD: begin
          attr = cxl_pkt[PKT_AUX_MSB:PKT_AUX_LSB] ^
                 cxl_pkt[PKT_MISC_MSB:PKT_MISC_LSB];
          raw_pkt = pack_ucie_ad_req(
            UCIE_MSG_CACHE_RD,
            cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
            cxl_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
            cxl_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
            cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
            attr,
            8'h00
          );
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          expect_ucie_from_cxl = raw_pkt;
        end
        CXL_PKT_KIND_CACHE_WR: begin
          attr = cxl_pkt[PKT_AUX_MSB:PKT_AUX_LSB] ^
                 cxl_pkt[PKT_MISC_MSB:PKT_MISC_LSB];
          raw_pkt = pack_ucie_ad_req(
            UCIE_MSG_CACHE_WR,
            cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
            cxl_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
            cxl_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
            cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
            attr,
            8'h00
          );
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          expect_ucie_from_cxl = raw_pkt;
        end
        default: begin
          raw_pkt = {UCIE_PKT_KIND_ERROR, 4'h0, cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                     16'h0000, 8'h00, cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
                     8'h00, 8'h00};
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          expect_ucie_from_cxl = raw_pkt;
        end
      endcase
    end
  endfunction

  // Gold model: mirrors translate_ucie_to_cxl in the bridge RTL.
  function automatic [63:0] expect_cxl_from_ucie;
    input [63:0] ucie_pkt;
    reg [63:0] chk_pkt;
    begin
      chk_pkt = ucie_pkt;
      chk_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = 8'h00;
      case (ucie_pkt[PKT_KIND_MSB:PKT_KIND_LSB])
        UCIE_PKT_KIND_AD_CPL:
          if (ucie_pkt[PKT_MISC_MSB:PKT_MISC_LSB] == bridge_checksum(chk_pkt))
            expect_cxl_from_ucie = pack_cxl_io_cpl(
              ucie_pkt[PKT_CODE_MSB:PKT_CODE_LSB],
              ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
              ucie_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
              ucie_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
              ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
              ucie_pkt[PKT_AUX_MSB:PKT_AUX_LSB]
            );
          else
            expect_cxl_from_ucie = {CXL_PKT_KIND_INVALID, 4'h0,
                                    ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB], 16'h0000,
                                    8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                                    8'h00, 8'h00};
        UCIE_PKT_KIND_MEM_CPL:
          if (ucie_pkt[PKT_MISC_MSB:PKT_MISC_LSB] == bridge_checksum(chk_pkt))
            expect_cxl_from_ucie = pack_cxl_mem_cpl(
              ucie_pkt[PKT_CODE_MSB:PKT_CODE_LSB],
              ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
              ucie_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
              ucie_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
              ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
              ucie_pkt[PKT_AUX_MSB:PKT_AUX_LSB]
            );
          else
            expect_cxl_from_ucie = {CXL_PKT_KIND_INVALID, 4'h0,
                                    ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB], 16'h0000,
                                    8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                                    8'h00, 8'h00};
        UCIE_PKT_KIND_CACHE_CPL:
          if (ucie_pkt[PKT_MISC_MSB:PKT_MISC_LSB] == bridge_checksum(chk_pkt))
            expect_cxl_from_ucie = pack_cxl_cache_cpl(
              ucie_pkt[PKT_CODE_MSB:PKT_CODE_LSB],
              ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
              ucie_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
              ucie_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
              ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
              ucie_pkt[PKT_AUX_MSB:PKT_AUX_LSB]
            );
          else
            expect_cxl_from_ucie = {CXL_PKT_KIND_INVALID, 4'h0,
                                    ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB], 16'h0000,
                                    8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                                    8'h00, 8'h00};
        default:
          expect_cxl_from_ucie = {CXL_PKT_KIND_INVALID, 4'h0,
                                  ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB], 16'h0000,
                                  8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                                  8'h00, 8'h00};
      endcase
    end
  endfunction

  // Mirrors bridge RTL is_posted: true for MEM_WR and CACHE_WR kinds.
  function automatic is_posted_cxl;
    input [63:0] pkt;
    begin
      case (pkt[PKT_KIND_MSB:PKT_KIND_LSB])
        CXL_PKT_KIND_MEM_WR:   is_posted_cxl = 1'b1;
        CXL_PKT_KIND_CACHE_WR: is_posted_cxl = 1'b1;
        default:               is_posted_cxl = 1'b0;
      endcase
    end
  endfunction

  // Determines if a UCIe output packet came from the posted c2u FIFO.
  // UCIE_MSG_MEM_WR and UCIE_MSG_CACHE_WR can only originate from posted CXL requests.
  function automatic is_ucie_posted;
    input [63:0] pkt;
    begin
      case (pkt[PKT_CODE_MSB:PKT_CODE_LSB])
        UCIE_MSG_MEM_WR:   is_ucie_posted = 1'b1;
        UCIE_MSG_CACHE_WR: is_ucie_posted = 1'b1;
        default:           is_ucie_posted = 1'b0;
      endcase
    end
  endfunction

  task automatic scoreboard_step;
    begin
      // c2u input: route expected output to posted or NP gold queue
      if (cxl_in_valid && cxl_in_ready) begin
        if (is_posted_cxl(cxl_in_data)) begin
          if (c2u_posted_gold_wr >= GOLD_SZ) begin
            $display("FAIL: gold_c2u_posted overflow");
            $finish(1);
          end
          gold_c2u_posted[c2u_posted_gold_wr] = expect_ucie_from_cxl(cxl_in_data);
          c2u_posted_gold_wr = c2u_posted_gold_wr + 1;
        end else begin
          if (c2u_np_gold_wr >= GOLD_SZ) begin
            $display("FAIL: gold_c2u_np overflow");
            $finish(1);
          end
          gold_c2u_np[c2u_np_gold_wr] = expect_ucie_from_cxl(cxl_in_data);
          c2u_np_gold_wr = c2u_np_gold_wr + 1;
        end
        c2u_sent = c2u_sent + 1;
      end

      // c2u output: check against the appropriate gold queue
      if (ucie_out_valid && ucie_out_ready) begin
        if (is_ucie_posted(ucie_out_data)) begin
          if (c2u_posted_gold_rd >= c2u_posted_gold_wr) begin
            $display("FAIL: c2u posted pop underrun");
            $finish(1);
          end
          if (ucie_out_data !== gold_c2u_posted[c2u_posted_gold_rd]) begin
            $display("FAIL: c2u posted mismatch exp=%h got=%h",
                     gold_c2u_posted[c2u_posted_gold_rd], ucie_out_data);
            $finish(1);
          end
          c2u_posted_gold_rd = c2u_posted_gold_rd + 1;
        end else begin
          if (c2u_np_gold_rd >= c2u_np_gold_wr) begin
            $display("FAIL: c2u np pop underrun");
            $finish(1);
          end
          if (ucie_out_data !== gold_c2u_np[c2u_np_gold_rd]) begin
            $display("FAIL: c2u np mismatch exp=%h got=%h",
                     gold_c2u_np[c2u_np_gold_rd], ucie_out_data);
            $finish(1);
          end
          c2u_np_gold_rd = c2u_np_gold_rd + 1;
        end
        c2u_rcvd = c2u_rcvd + 1;
      end

      // u2c scoreboard (unchanged)
      if (ucie_in_valid && ucie_in_ready) begin
        if (u2c_gold_wr >= GOLD_SZ) begin
          $display("FAIL: gold_u2c overflow");
          $finish(1);
        end
        gold_u2c[u2c_gold_wr] = expect_cxl_from_ucie(ucie_in_data);
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
    clk                  = 1'b0;
    rst_n                = 1'b0;
    cxl_in_valid         = 1'b0;
    cxl_in_data          = {W{1'b0}};
    ucie_out_ready       = 1'b0;
    ucie_in_valid        = 1'b0;
    ucie_in_data         = {W{1'b0}};
    cxl_out_ready        = 1'b0;
    seed                 = 32'hACE15EED;
    c2u_posted_gold_wr   = 0;
    c2u_posted_gold_rd   = 0;
    c2u_np_gold_wr       = 0;
    c2u_np_gold_rd       = 0;
    u2c_gold_wr          = 0;
    u2c_gold_rd          = 0;
    c2u_sent             = 0;
    u2c_sent             = 0;
    c2u_rcvd             = 0;
    u2c_rcvd             = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // --- Smoke 1: CXL.io IO_REQ (original sanity) ---
    @(posedge clk);
    cxl_in_data    = pack_cxl_io_req(CXL_IO_OP_MEM_RD, 8'h3c, 16'hbeef, 8'h04, 8'ha1, 8'h0f);
    cxl_in_valid   = 1'b1;
    ucie_out_ready = 1'b1;
    @(posedge clk);
    while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
    cxl_in_valid = 1'b0;

    wait (ucie_out_valid);
    @(posedge clk);
    if (ucie_out_data !== expect_ucie_from_cxl(pack_cxl_io_req(CXL_IO_OP_MEM_RD, 8'h3c, 16'hbeef, 8'h04, 8'ha1, 8'h0f))) begin
      $display("FAIL: smoke io_req ucie_out_data got %h", ucie_out_data);
      $finish(1);
    end

    @(posedge clk);
    ucie_in_data   = pack_ucie_ad_cpl(UCIE_CPL_SC, 8'h5a, 16'h0040, 8'h04, 8'hc3, 8'h18, 8'h00);
    ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(ucie_in_data);
    ucie_in_valid  = 1'b1;
    cxl_out_ready  = 1'b1;
    @(posedge clk);
    while (!(ucie_in_valid && ucie_in_ready)) @(posedge clk);
    ucie_in_valid = 1'b0;

    wait (cxl_out_valid);
    @(posedge clk);
    if (cxl_out_data !== expect_cxl_from_ucie(ucie_in_data)) begin
      $display("FAIL: smoke ad_cpl cxl_out_data got %h", cxl_out_data);
      $finish(1);
    end

    // --- Smoke 2: new packet kinds ---
    begin : blk_smoke_new_kinds
      reg [W-1:0] upkt;

      // CXL.mem read
      @(posedge clk);
      cxl_in_data  = pack_cxl_mem_rd(4'h1, 8'h11, 16'h2000, 8'h08, 8'hd4, 8'hf5);
      cxl_in_valid = 1'b1; ucie_out_ready = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== expect_ucie_from_cxl(pack_cxl_mem_rd(4'h1, 8'h11, 16'h2000, 8'h08, 8'hd4, 8'hf5))) begin
        $display("FAIL: smoke mem_rd got %h", ucie_out_data); $finish(1);
      end

      // CXL.mem write
      @(posedge clk);
      cxl_in_data  = pack_cxl_mem_wr(4'h2, 8'h22, 16'h4000, 8'h04, 8'he5, 8'ha3);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== expect_ucie_from_cxl(pack_cxl_mem_wr(4'h2, 8'h22, 16'h4000, 8'h04, 8'he5, 8'ha3))) begin
        $display("FAIL: smoke mem_wr got %h", ucie_out_data); $finish(1);
      end

      // CXL.cache read
      @(posedge clk);
      cxl_in_data  = pack_cxl_cache_rd(4'h0, 8'h33, 16'h8000, 8'h02, 8'hf6, 8'h77);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== expect_ucie_from_cxl(pack_cxl_cache_rd(4'h0, 8'h33, 16'h8000, 8'h02, 8'hf6, 8'h77))) begin
        $display("FAIL: smoke cache_rd got %h", ucie_out_data); $finish(1);
      end

      // CXL.cache write
      @(posedge clk);
      cxl_in_data  = pack_cxl_cache_wr(4'h3, 8'h44, 16'hc000, 8'h01, 8'ha7, 8'h5b);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== expect_ucie_from_cxl(pack_cxl_cache_wr(4'h3, 8'h44, 16'hc000, 8'h01, 8'ha7, 8'h5b))) begin
        $display("FAIL: smoke cache_wr got %h", ucie_out_data); $finish(1);
      end

      // UCIe MEM_CPL -> CXL MEM_CPL
      upkt = pack_ucie_mem_cpl(UCIE_CPL_SC, 8'h11, 16'h0800, 8'h08, 8'hd4, 8'hf5, 8'h00);
      upkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(upkt);
      @(posedge clk);
      ucie_in_data = upkt; ucie_in_valid = 1'b1; cxl_out_ready = 1'b1;
      @(posedge clk);
      while (!(ucie_in_valid && ucie_in_ready)) @(posedge clk);
      ucie_in_valid = 1'b0;
      wait (cxl_out_valid); @(posedge clk);
      if (cxl_out_data !== expect_cxl_from_ucie(upkt)) begin
        $display("FAIL: smoke mem_cpl got %h", cxl_out_data); $finish(1);
      end

      // UCIe CACHE_CPL -> CXL CACHE_CPL
      upkt = pack_ucie_cache_cpl(UCIE_CPL_UR, 8'h33, 16'h0200, 8'h02, 8'hf6, 8'h77, 8'h00);
      upkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(upkt);
      @(posedge clk);
      ucie_in_data = upkt; ucie_in_valid = 1'b1;
      @(posedge clk);
      while (!(ucie_in_valid && ucie_in_ready)) @(posedge clk);
      ucie_in_valid = 1'b0;
      wait (cxl_out_valid); @(posedge clk);
      if (cxl_out_data !== expect_cxl_from_ucie(upkt)) begin
        $display("FAIL: smoke cache_cpl got %h", cxl_out_data); $finish(1);
      end

      // UCIe AD_CPL with CA status
      upkt = pack_ucie_ad_cpl(UCIE_CPL_CA, 8'h5a, 16'h0040, 8'h04, 8'hc3, 8'h18, 8'h00);
      upkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(upkt);
      @(posedge clk);
      ucie_in_data = upkt; ucie_in_valid = 1'b1;
      @(posedge clk);
      while (!(ucie_in_valid && ucie_in_ready)) @(posedge clk);
      ucie_in_valid = 1'b0;
      wait (cxl_out_valid); @(posedge clk);
      if (cxl_out_data !== expect_cxl_from_ucie(upkt)) begin
        $display("FAIL: smoke ad_cpl_ca got %h", cxl_out_data); $finish(1);
      end
    end

    // --- Smoke 3: ordering — posted bypasses non-posted ---
    // Fill posted FIFO first (2 writes), then NP FIFO (2 reads) with the sink held off.
    // Posted packets arrive while valid is driven by the posted FIFO, so the arbiter
    // selects posted at valid-assert time; NP packets queue up behind it.
    // On drain, posted packets must emerge before the NP packets.
    begin : blk_ordering
      reg [W-1:0] exp_posted0, exp_posted1, exp_np0, exp_np1;

      ucie_out_ready = 1'b0;

      // posted packet 0: MEM_WR
      @(posedge clk);
      cxl_in_data  = pack_cxl_mem_wr(4'h0, 8'hB1, 16'h3000, 8'h04, 8'h30, 8'h00);
      exp_posted0  = expect_ucie_from_cxl(cxl_in_data);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;

      // posted packet 1: CACHE_WR
      @(posedge clk);
      cxl_in_data  = pack_cxl_cache_wr(4'h0, 8'hB2, 16'h4000, 8'h04, 8'h40, 8'h00);
      exp_posted1  = expect_ucie_from_cxl(cxl_in_data);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;

      // NP packet 0: MEM_RD (arrives after posted; arbiter already locked to posted)
      @(posedge clk);
      cxl_in_data  = pack_cxl_mem_rd(4'h0, 8'hA1, 16'h1000, 8'h04, 8'h10, 8'h00);
      exp_np0      = expect_ucie_from_cxl(cxl_in_data);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;

      // NP packet 1: CACHE_RD
      @(posedge clk);
      cxl_in_data  = pack_cxl_cache_rd(4'h0, 8'hA2, 16'h2000, 8'h04, 8'h20, 8'h00);
      exp_np1      = expect_ucie_from_cxl(cxl_in_data);
      cxl_in_valid = 1'b1;
      @(posedge clk);
      while (!(cxl_in_valid && cxl_in_ready)) @(posedge clk);
      cxl_in_valid = 1'b0;

      // Release sink — posted FIFO has priority so posted drains first.
      @(posedge clk);
      ucie_out_ready = 1'b1;

      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== exp_posted0) begin
        $display("FAIL: ordering[0] want posted MEM_WR=%h got=%h", exp_posted0, ucie_out_data);
        $finish(1);
      end
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== exp_posted1) begin
        $display("FAIL: ordering[1] want posted CACHE_WR=%h got=%h", exp_posted1, ucie_out_data);
        $finish(1);
      end
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== exp_np0) begin
        $display("FAIL: ordering[2] want np MEM_RD=%h got=%h", exp_np0, ucie_out_data);
        $finish(1);
      end
      wait (ucie_out_valid); @(posedge clk);
      if (ucie_out_data !== exp_np1) begin
        $display("FAIL: ordering[3] want np CACHE_RD=%h got=%h", exp_np1, ucie_out_data);
        $finish(1);
      end
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

      // CXL -> UCIe source: all packet kinds
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
          case (seed[20:18] % 5)
            3'd0: cxl_in_data <= pack_cxl_io_req(
                                   CXL_IO_OP_CFG_RD, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            3'd1: cxl_in_data <= pack_cxl_io_req(
                                   CXL_IO_OP_MEM_WR, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            3'd2: cxl_in_data <= pack_cxl_mem_rd(
                                   4'h0, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            3'd3: cxl_in_data <= pack_cxl_cache_rd(
                                   4'h0, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            default: cxl_in_data <= pack_cxl_cache_wr(
                                      4'h0, seed[15:8], seed[31:16],
                                      {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
          endcase
        end
      end

      // UCIe -> CXL source: all completion kinds
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
          case (seed[19:18] % 3)
            2'd0: begin
              ucie_in_data <= pack_ucie_ad_cpl(
                               seed[16] ? UCIE_CPL_SC : UCIE_CPL_UR,
                               seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                               seed[23:16], seed[7:0], 8'h00);
              ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] <= bridge_checksum(
                pack_ucie_ad_cpl(seed[16] ? UCIE_CPL_SC : UCIE_CPL_UR,
                                 seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                                 seed[23:16], seed[7:0], 8'h00));
            end
            2'd1: begin
              ucie_in_data <= pack_ucie_mem_cpl(
                               seed[16] ? UCIE_CPL_SC : UCIE_CPL_CA,
                               seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                               seed[23:16], seed[7:0], 8'h00);
              ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] <= bridge_checksum(
                pack_ucie_mem_cpl(seed[16] ? UCIE_CPL_SC : UCIE_CPL_CA,
                                  seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                                  seed[23:16], seed[7:0], 8'h00));
            end
            default: begin
              ucie_in_data <= pack_ucie_cache_cpl(
                               seed[16] ? UCIE_CPL_UR : UCIE_CPL_SC,
                               seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                               seed[23:16], seed[7:0], 8'h00);
              ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] <= bridge_checksum(
                pack_ucie_cache_cpl(seed[16] ? UCIE_CPL_UR : UCIE_CPL_SC,
                                    seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                                    seed[23:16], seed[7:0], 8'h00));
            end
          endcase
        end
      end
    end

    // Drain: hold both sinks ready, stop new sources
    @(posedge clk);
    scoreboard_step();

    cxl_in_valid   <= 1'b0;
    ucie_in_valid  <= 1'b0;
    ucie_out_ready <= 1'b1;
    cxl_out_ready  <= 1'b1;

    repeat (FIFO_DEPTH + 64) begin
      @(posedge clk);

      if (ucie_out_valid && ucie_out_ready) begin
        if (is_ucie_posted(ucie_out_data)) begin
          if (c2u_posted_gold_rd >= c2u_posted_gold_wr) begin
            $display("FAIL: drain c2u posted underrun");
            $finish(1);
          end
          if (ucie_out_data !== gold_c2u_posted[c2u_posted_gold_rd]) begin
            $display("FAIL: drain c2u posted mismatch exp=%h got=%h",
                     gold_c2u_posted[c2u_posted_gold_rd], ucie_out_data);
            $finish(1);
          end
          c2u_posted_gold_rd = c2u_posted_gold_rd + 1;
        end else begin
          if (c2u_np_gold_rd >= c2u_np_gold_wr) begin
            $display("FAIL: drain c2u np underrun");
            $finish(1);
          end
          if (ucie_out_data !== gold_c2u_np[c2u_np_gold_rd]) begin
            $display("FAIL: drain c2u np mismatch exp=%h got=%h",
                     gold_c2u_np[c2u_np_gold_rd], ucie_out_data);
            $finish(1);
          end
          c2u_np_gold_rd = c2u_np_gold_rd + 1;
        end
        c2u_rcvd = c2u_rcvd + 1;
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

    if (c2u_posted_gold_rd !== c2u_posted_gold_wr) begin
      $display("FAIL: c2u posted gold not empty wr=%0d rd=%0d",
               c2u_posted_gold_wr, c2u_posted_gold_rd);
      $finish(1);
    end
    if (c2u_np_gold_rd !== c2u_np_gold_wr) begin
      $display("FAIL: c2u np gold not empty wr=%0d rd=%0d",
               c2u_np_gold_wr, c2u_np_gold_rd);
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

    p1_c2u_sent = c2u_sent;
    p1_u2c_sent = u2c_sent;
    $display("PASS stress c2u_beats=%0d u2c_beats=%0d", p1_c2u_sent, p1_u2c_sent);

    if (!$test$plusargs("stress"))
      $finish(0);

    // --- Heavy stress: longer run, sinks ready ~20% (FIFOs stay near full) ---
    c2u_sent = 0;
    u2c_sent = 0;
    c2u_rcvd = 0;
    u2c_rcvd = 0;
    seed     = 32'hC0FFEE01;

    for (cyc = 0; cyc < NUM_STRESS_HEAVY; cyc = cyc + 1) begin
      @(posedge clk);

      scoreboard_step();

      seed           = rnd32(seed);
      ucie_out_ready <= (seed % 10) < 2;
      seed           = rnd32(seed);
      cxl_out_ready  <= (seed % 10) < 2;

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
          case (seed[20:18] % 5)
            3'd0: cxl_in_data <= pack_cxl_io_req(
                                   CXL_IO_OP_MEM_RD, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            3'd1: cxl_in_data <= pack_cxl_io_req(
                                   CXL_IO_OP_CFG_WR, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            3'd2: cxl_in_data <= pack_cxl_mem_wr(
                                   4'h0, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            3'd3: cxl_in_data <= pack_cxl_cache_wr(
                                   4'h0, seed[15:8], seed[31:16],
                                   {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
            default: cxl_in_data <= pack_cxl_mem_rd(
                                      4'h0, seed[15:8], seed[31:16],
                                      {6'h0, seed[7:6]}, seed[23:16], seed[7:0]);
          endcase
        end
      end

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
          case (seed[19:18] % 3)
            2'd0: begin
              ucie_in_data <= pack_ucie_ad_cpl(
                               seed[16] ? UCIE_CPL_SC : UCIE_CPL_CA,
                               seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                               seed[23:16], seed[7:0], 8'h00);
              ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] <= bridge_checksum(
                pack_ucie_ad_cpl(seed[16] ? UCIE_CPL_SC : UCIE_CPL_CA,
                                 seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                                 seed[23:16], seed[7:0], 8'h00));
            end
            2'd1: begin
              ucie_in_data <= pack_ucie_mem_cpl(
                               seed[16] ? UCIE_CPL_SC : UCIE_CPL_UR,
                               seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                               seed[23:16], seed[7:0], 8'h00);
              ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] <= bridge_checksum(
                pack_ucie_mem_cpl(seed[16] ? UCIE_CPL_SC : UCIE_CPL_UR,
                                  seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                                  seed[23:16], seed[7:0], 8'h00));
            end
            default: begin
              ucie_in_data <= pack_ucie_cache_cpl(
                               seed[16] ? UCIE_CPL_CA : UCIE_CPL_SC,
                               seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                               seed[23:16], seed[7:0], 8'h00);
              ucie_in_data[PKT_MISC_MSB:PKT_MISC_LSB] <= bridge_checksum(
                pack_ucie_cache_cpl(seed[16] ? UCIE_CPL_CA : UCIE_CPL_SC,
                                    seed[15:8], seed[31:16], {6'h0, seed[7:6]},
                                    seed[23:16], seed[7:0], 8'h00));
            end
          endcase
        end
      end
    end

    @(posedge clk);
    scoreboard_step();

    cxl_in_valid   <= 1'b0;
    ucie_in_valid  <= 1'b0;
    ucie_out_ready <= 1'b1;
    cxl_out_ready  <= 1'b1;

    repeat (FIFO_DEPTH + 128) begin
      @(posedge clk);

      if (ucie_out_valid && ucie_out_ready) begin
        if (is_ucie_posted(ucie_out_data)) begin
          if (c2u_posted_gold_rd >= c2u_posted_gold_wr) begin
            $display("FAIL: heavy drain c2u posted underrun");
            $finish(1);
          end
          if (ucie_out_data !== gold_c2u_posted[c2u_posted_gold_rd]) begin
            $display("FAIL: heavy drain c2u posted mismatch exp=%h got=%h",
                     gold_c2u_posted[c2u_posted_gold_rd], ucie_out_data);
            $finish(1);
          end
          c2u_posted_gold_rd = c2u_posted_gold_rd + 1;
        end else begin
          if (c2u_np_gold_rd >= c2u_np_gold_wr) begin
            $display("FAIL: heavy drain c2u np underrun");
            $finish(1);
          end
          if (ucie_out_data !== gold_c2u_np[c2u_np_gold_rd]) begin
            $display("FAIL: heavy drain c2u np mismatch exp=%h got=%h",
                     gold_c2u_np[c2u_np_gold_rd], ucie_out_data);
            $finish(1);
          end
          c2u_np_gold_rd = c2u_np_gold_rd + 1;
        end
        c2u_rcvd = c2u_rcvd + 1;
      end

      if (cxl_out_valid && cxl_out_ready) begin
        if (u2c_gold_rd >= u2c_gold_wr) begin
          $display("FAIL: heavy drain u2c underrun");
          $finish(1);
        end
        if (cxl_out_data !== gold_u2c[u2c_gold_rd]) begin
          $display("FAIL: heavy drain u2c mismatch exp=%h got=%h",
                   gold_u2c[u2c_gold_rd], cxl_out_data);
          $finish(1);
        end
        u2c_gold_rd = u2c_gold_rd + 1;
        u2c_rcvd    = u2c_rcvd + 1;
      end
    end

    if (c2u_posted_gold_rd !== c2u_posted_gold_wr) begin
      $display("FAIL: heavy c2u posted gold not empty wr=%0d rd=%0d",
               c2u_posted_gold_wr, c2u_posted_gold_rd);
      $finish(1);
    end
    if (c2u_np_gold_rd !== c2u_np_gold_wr) begin
      $display("FAIL: heavy c2u np gold not empty wr=%0d rd=%0d",
               c2u_np_gold_wr, c2u_np_gold_rd);
      $finish(1);
    end
    if (u2c_gold_rd !== u2c_gold_wr) begin
      $display("FAIL: heavy u2c gold not empty wr=%0d rd=%0d", u2c_gold_wr, u2c_gold_rd);
      $finish(1);
    end
    if (ucie_out_valid) begin
      $display("FAIL: heavy ucie_out still valid after drain");
      $finish(1);
    end
    if (cxl_out_valid) begin
      $display("FAIL: heavy cxl_out still valid after drain");
      $finish(1);
    end

    if (c2u_sent !== c2u_rcvd) begin
      $display("FAIL: heavy c2u sent=%0d rcvd=%0d", c2u_sent, c2u_rcvd);
      $finish(1);
    end
    if (u2c_sent !== u2c_rcvd) begin
      $display("FAIL: heavy u2c sent=%0d rcvd=%0d", u2c_sent, u2c_rcvd);
      $finish(1);
    end

    $display("PASS stress_heavy c2u_beats=%0d u2c_beats=%0d (after default stress %0d/%0d)",
             c2u_sent, u2c_sent, p1_c2u_sent, p1_u2c_sent);
    $finish(0);
  end

endmodule
