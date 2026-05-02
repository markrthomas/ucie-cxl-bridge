// CXL <-> UCIe bridge — protocol mapping TBD.
// Phase 4: link readiness gate (reset_drain FSM), error injection interface, CDC helper.
// Phase 3: per-direction credit counters + ordering domain split (posted vs. non-posted).
// c2u path uses two sync FIFOs: posted (MEM_WR, CACHE_WR) and non-posted (all others).
// Egress arbiter is posted-first (CXL spec: posted may bypass non-posted).

/* verilator lint_off UNUSEDPARAM */
`include "cxl_ucie_bridge_defs.vh"
/* verilator lint_on UNUSEDPARAM */

module cxl_ucie_bridge #(
  parameter integer WIDTH          = 64,
  parameter integer FIFO_DEPTH     = 8,
  parameter integer POSTED_CREDITS = FIFO_DEPTH,
  parameter integer NP_CREDITS     = FIFO_DEPTH,
  parameter integer CPL_CREDITS    = FIFO_DEPTH
) (
  input  wire                  clk,
  input  wire                  rst_n,
  // CXL -> UCIe
  input  wire                  cxl_in_valid,
  input  wire [WIDTH-1:0]      cxl_in_data,
  output wire                  cxl_in_ready,
  output wire                  ucie_out_valid,
  output wire [WIDTH-1:0]      ucie_out_data,
  input  wire                  ucie_out_ready,
  // UCIe -> CXL
  input  wire                  ucie_in_valid,
  input  wire [WIDTH-1:0]      ucie_in_data,
  output wire                  ucie_in_ready,
  output wire                  cxl_out_valid,
  output wire [WIDTH-1:0]      cxl_out_data,
  input  wire                  cxl_out_ready,
  // Phase 4: link readiness and error injection
  input  wire                  link_up,
  input  wire                  err_inj_en,
  output wire                  drain_done
);

  generate
    if (WIDTH != 64) begin : gen_width_check
      initial $fatal(1, "cxl_ucie_bridge: WIDTH must be 64 for the typed packet model");
    end
  endgenerate

  // --- Packet classification ---
  // Posted: writes that do not require a completion (MEM_WR, CACHE_WR).
  // All other CXL kinds — IO_REQ reads/cfg, MEM_RD, CACHE_RD — are non-posted.
  /* verilator lint_off UNUSEDSIGNAL */
  function automatic is_posted;
    input [WIDTH-1:0] pkt;
    begin
      case (pkt[PKT_KIND_MSB:PKT_KIND_LSB])
        CXL_PKT_KIND_MEM_WR:   is_posted = 1'b1;
        CXL_PKT_KIND_CACHE_WR: is_posted = 1'b1;
        default:               is_posted = 1'b0;
      endcase
    end
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */

  // --- Translation functions ---

  function automatic [WIDTH-1:0] translate_cxl_to_ucie;
    input [WIDTH-1:0] cxl_pkt;
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
          translate_cxl_to_ucie = raw_pkt[WIDTH-1:0];
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
          translate_cxl_to_ucie = raw_pkt[WIDTH-1:0];
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
          translate_cxl_to_ucie = raw_pkt[WIDTH-1:0];
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
          translate_cxl_to_ucie = raw_pkt[WIDTH-1:0];
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
          translate_cxl_to_ucie = raw_pkt[WIDTH-1:0];
        end
        default: begin
          raw_pkt = {UCIE_PKT_KIND_ERROR, 4'h0, cxl_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                     16'h0000, 8'h00, cxl_pkt[PKT_ID_MSB:PKT_ID_LSB],
                     8'h00, 8'h00};
          raw_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = bridge_checksum(raw_pkt);
          translate_cxl_to_ucie = raw_pkt[WIDTH-1:0];
        end
      endcase
    end
  endfunction

  function automatic [WIDTH-1:0] translate_ucie_to_cxl;
    input [WIDTH-1:0] ucie_pkt;
    reg [63:0] raw_pkt;
    reg [63:0] chk_pkt;
    begin
      case (ucie_pkt[PKT_KIND_MSB:PKT_KIND_LSB])
        UCIE_PKT_KIND_AD_CPL: begin
          chk_pkt = ucie_pkt;
          chk_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = 8'h00;
          if (ucie_pkt[PKT_MISC_MSB:PKT_MISC_LSB] == bridge_checksum(chk_pkt)) begin
            raw_pkt = pack_cxl_io_cpl(
              ucie_pkt[PKT_CODE_MSB:PKT_CODE_LSB],
              ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
              ucie_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
              ucie_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
              ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
              ucie_pkt[PKT_AUX_MSB:PKT_AUX_LSB]
            );
          end else begin
            raw_pkt = {CXL_PKT_KIND_INVALID, 4'h0, ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                       16'h0000, 8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                       8'h00, 8'h00};
          end
          translate_ucie_to_cxl = raw_pkt[WIDTH-1:0];
        end
        UCIE_PKT_KIND_MEM_CPL: begin
          chk_pkt = ucie_pkt;
          chk_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = 8'h00;
          if (ucie_pkt[PKT_MISC_MSB:PKT_MISC_LSB] == bridge_checksum(chk_pkt)) begin
            raw_pkt = pack_cxl_mem_cpl(
              ucie_pkt[PKT_CODE_MSB:PKT_CODE_LSB],
              ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
              ucie_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
              ucie_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
              ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
              ucie_pkt[PKT_AUX_MSB:PKT_AUX_LSB]
            );
          end else begin
            raw_pkt = {CXL_PKT_KIND_INVALID, 4'h0, ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                       16'h0000, 8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                       8'h00, 8'h00};
          end
          translate_ucie_to_cxl = raw_pkt[WIDTH-1:0];
        end
        UCIE_PKT_KIND_CACHE_CPL: begin
          chk_pkt = ucie_pkt;
          chk_pkt[PKT_MISC_MSB:PKT_MISC_LSB] = 8'h00;
          if (ucie_pkt[PKT_MISC_MSB:PKT_MISC_LSB] == bridge_checksum(chk_pkt)) begin
            raw_pkt = pack_cxl_cache_cpl(
              ucie_pkt[PKT_CODE_MSB:PKT_CODE_LSB],
              ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
              ucie_pkt[PKT_ADDR_MSB:PKT_ADDR_LSB],
              ucie_pkt[PKT_LEN_MSB:PKT_LEN_LSB],
              ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
              ucie_pkt[PKT_AUX_MSB:PKT_AUX_LSB]
            );
          end else begin
            raw_pkt = {CXL_PKT_KIND_INVALID, 4'h0, ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                       16'h0000, 8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                       8'h00, 8'h00};
          end
          translate_ucie_to_cxl = raw_pkt[WIDTH-1:0];
        end
        default: begin
          raw_pkt = {CXL_PKT_KIND_INVALID, 4'h0, ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                     16'h0000, 8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                     8'h00, 8'h00};
          translate_ucie_to_cxl = raw_pkt[WIDTH-1:0];
        end
      endcase
    end
  endfunction

  // --- Internal signals ---

  wire c2u_posted_full;
  wire c2u_posted_empty;
  wire c2u_np_full;
  wire c2u_np_empty;
  wire u2c_full;
  wire u2c_empty;

  wire posted_credits_avail;
  wire np_credits_avail;
  wire cpl_credits_avail;

  // Phase 4: all FIFOs empty — used by reset_drain to detect drain completion.
  wire all_empty = c2u_posted_empty && c2u_np_empty && u2c_empty;
  // bridge_open: driven by reset_drain FSM; low gates all ingress.
  wire bridge_open;

  // Error injection: flip bit 0 of the checksum byte when err_inj_en is asserted.
  wire [WIDTH-1:0] c2u_wr_data_raw = translate_cxl_to_ucie(cxl_in_data);
  wire [WIDTH-1:0] c2u_wr_data     = err_inj_en ?
    {c2u_wr_data_raw[WIDTH-1:1], ~c2u_wr_data_raw[0]} : c2u_wr_data_raw;
  wire [WIDTH-1:0] u2c_wr_data     = translate_ucie_to_cxl(ucie_in_data);
  wire [WIDTH-1:0] c2u_posted_rd_data;
  wire [WIDTH-1:0] c2u_np_rd_data;

  wire cxl_in_is_posted_w = is_posted(cxl_in_data);

  // CXL input accepted when bridge is open AND its target FIFO has space AND credits are available.
  assign cxl_in_ready  = bridge_open && (cxl_in_is_posted_w ?
                         (!c2u_posted_full && posted_credits_avail) :
                         (!c2u_np_full && np_credits_avail));

  assign ucie_in_ready = bridge_open && !u2c_full && cpl_credits_avail;
  assign cxl_out_valid = !u2c_empty;

  // Egress arbiter: posted FIFO has priority (CXL spec: posted may bypass non-posted).
  // Lock the selection once a beat is in-flight (valid && !ready) so ucie_out_data
  // cannot change before the downstream accepts it.
  reg  arb_locked_r;
  reg  arb_sel_posted_r;

  wire arb_sel_now   = !c2u_posted_empty;
  wire arb_sel_final = arb_locked_r ? arb_sel_posted_r : arb_sel_now;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arb_locked_r     <= 1'b0;
      arb_sel_posted_r <= 1'b0;
    end else begin
      if (arb_locked_r) begin
        if (ucie_out_ready)
          arb_locked_r <= 1'b0;
      end else if (ucie_out_valid && !ucie_out_ready) begin
        arb_locked_r     <= 1'b1;
        arb_sel_posted_r <= arb_sel_now;
      end
    end
  end

  assign ucie_out_valid = !c2u_posted_empty || !c2u_np_empty;
  assign ucie_out_data  = arb_sel_final ? c2u_posted_rd_data : c2u_np_rd_data;

  wire c2u_wr         = cxl_in_valid && cxl_in_ready;
  wire c2u_posted_wr  = c2u_wr && cxl_in_is_posted_w;
  wire c2u_np_wr      = c2u_wr && !cxl_in_is_posted_w;
  wire c2u_posted_rd  = ucie_out_valid && ucie_out_ready && arb_sel_final;
  wire c2u_np_rd      = ucie_out_valid && ucie_out_ready && !arb_sel_final;
  wire u2c_wr         = ucie_in_valid && ucie_in_ready;
  wire u2c_rd         = cxl_out_ready && cxl_out_valid;

  // --- Credit counters (credits return when downstream reads from the FIFO) ---

  credit_counter #(.CREDITS(POSTED_CREDITS)) u_posted_crd (
    .clk      (clk),
    .rst_n    (rst_n),
    .consume  (c2u_posted_wr),
    .ret      (c2u_posted_rd),
    .available(posted_credits_avail)
  );

  credit_counter #(.CREDITS(NP_CREDITS)) u_np_crd (
    .clk      (clk),
    .rst_n    (rst_n),
    .consume  (c2u_np_wr),
    .ret      (c2u_np_rd),
    .available(np_credits_avail)
  );

  credit_counter #(.CREDITS(CPL_CREDITS)) u_cpl_crd (
    .clk      (clk),
    .rst_n    (rst_n),
    .consume  (u2c_wr),
    .ret      (u2c_rd),
    .available(cpl_credits_avail)
  );

  // --- Link readiness FSM ---

  reset_drain u_reset_drain (
    .clk       (clk),
    .rst_n     (rst_n),
    .link_up   (link_up),
    .all_empty (all_empty),
    .open      (bridge_open),
    .drain_done(drain_done)
  );

  // --- FIFOs ---

  sync_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_c2u_posted (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_en   (c2u_posted_wr),
    .wr_data (c2u_wr_data),
    .full    (c2u_posted_full),
    .empty   (c2u_posted_empty),
    .rd_en   (c2u_posted_rd),
    .rd_data (c2u_posted_rd_data)
  );

  sync_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_c2u_np (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_en   (c2u_np_wr),
    .wr_data (c2u_wr_data),
    .full    (c2u_np_full),
    .empty   (c2u_np_empty),
    .rd_en   (c2u_np_rd),
    .rd_data (c2u_np_rd_data)
  );

  sync_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_u2c (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_en   (u2c_wr),
    .wr_data (u2c_wr_data),
    .full    (u2c_full),
    .empty   (u2c_empty),
    .rd_en   (u2c_rd),
    .rd_data (cxl_out_data)
  );

`ifdef FORMAL
  // Helper: checksum check for the u2c direction (misc byte zeroed for computation).
  wire [63:0] f_u2c_chk_zero = {ucie_in_data[63:8], 8'h00};
  wire        f_u2c_cs_ok    = (ucie_in_data[7:0] == bridge_checksum(f_u2c_chk_zero));

  // Translation kind preservation — purely combinational, checked at all times.
  always @(*) begin
    // CXL->UCIe: recognized request kinds always produce AD_REQ; everything else → ERROR.
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_IO_REQ ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_RD  ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_WR  ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_RD ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_WR)
      assert (c2u_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_AD_REQ);
    else
      assert (c2u_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_ERROR);

    // CXL->UCIe: message type matches CXL kind for mem/cache requests.
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_RD)
      assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_MEM_RD);
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_WR)
      assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_MEM_WR);
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_RD)
      assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_CACHE_RD);
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_WR)
      assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_CACHE_WR);

    // UCIe->CXL: good checksum → CXL kind matches UCIe completion kind.
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_AD_CPL && f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_IO_CPL);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_MEM_CPL && f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_CPL);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_CACHE_CPL && f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_CPL);

    // UCIe->CXL: bad checksum or unknown kind → INVALID.
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_AD_CPL && !f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_INVALID);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_MEM_CPL && !f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_INVALID);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_CACHE_CPL && !f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_INVALID);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] != UCIE_PKT_KIND_AD_CPL    &&
        ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] != UCIE_PKT_KIND_MEM_CPL   &&
        ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] != UCIE_PKT_KIND_CACHE_CPL)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_INVALID);
  end

  // Phase 3: ordering domain routing correctness.
  always @(*) begin
    // Accepted CXL packets route to exactly one FIFO.
    if (cxl_in_valid && cxl_in_ready) begin
      if (cxl_in_is_posted_w)
        assert (c2u_posted_wr && !c2u_np_wr);
      else
        assert (!c2u_posted_wr && c2u_np_wr);
    end
    // Egress arbiter correctness: read fires on the selected FIFO.
    if (ucie_out_valid && ucie_out_ready) begin
      assert (c2u_posted_rd == arb_sel_final);
      assert (c2u_np_rd     == !arb_sel_final);
    end
    // Arbiter selects posted when not locked and posted is non-empty (priority rule).
    if (!arb_locked_r && !c2u_posted_empty)
      assert (arb_sel_final == 1'b1);
  end

  // Phase 4: link gating — ingress must be stalled when bridge is not open.
  always @(*) begin
    if (!bridge_open) begin
      assert (cxl_in_ready  == 1'b0);
      assert (ucie_in_ready == 1'b0);
    end
  end

  // Phase 4: error injection — bit 0 of the translated packet is flipped iff err_inj_en.
  always @(*) begin
    if (err_inj_en) begin
      assert (c2u_wr_data[0]         == ~c2u_wr_data_raw[0]);
      assert (c2u_wr_data[WIDTH-1:1] ==  c2u_wr_data_raw[WIDTH-1:1]);
    end else begin
      assert (c2u_wr_data == c2u_wr_data_raw);
    end
  end

  // Covers: packet kind reachability and Phase 3 scenarios.
  always_ff @(posedge clk) begin
    if (rst_n) begin
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_RD);
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_WR);
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_RD);
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_WR);
      cover (ucie_in_valid && ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_MEM_CPL);
      cover (ucie_in_valid && ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_CACHE_CPL);
      // Phase 3: credit exhaustion (CXL input stalled by empty credits)
      cover (cxl_in_valid && !cxl_in_ready && !posted_credits_avail);
      cover (cxl_in_valid && !cxl_in_ready && !np_credits_avail);
      // Phase 3: posted bypasses non-posted (ordering domain property)
      cover (c2u_posted_rd && !c2u_np_empty);
      // Phase 4: link gating and error injection reachability
      cover (!bridge_open && cxl_in_valid);
      cover (err_inj_en && c2u_np_wr);
      cover (drain_done);
    end
  end
`endif

endmodule
