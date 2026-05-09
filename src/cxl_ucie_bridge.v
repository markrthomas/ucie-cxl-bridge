// CXL <-> UCIe bridge — protocol mapping TBD.
// Phase 5: dual-clock (clk=CXL domain, ucie_clk=UCIe domain), async FIFOs.
// Phase 4: link readiness gate (reset_drain FSM), error injection interface.
// Phase 3: posted/non-posted ordering domain split, posted-priority egress arbiter.
// c2u path: two async FIFOs (posted, non-posted), write on clk, read on ucie_clk.
// u2c path: one async FIFO, write on ucie_clk, read on clk.
// Arbiter runs on ucie_clk.  Credit counters replaced by FIFO full/empty.

/* verilator lint_off UNUSEDPARAM */
`include "cxl_ucie_bridge_defs.vh"
/* verilator lint_on UNUSEDPARAM */

module cxl_ucie_bridge #(
  parameter integer WIDTH      = 64,
  parameter integer FIFO_DEPTH = 8,
  parameter integer POSTED_CREDITS = 8,
  parameter integer NP_CREDITS     = 8,
  parameter integer CPL_CREDITS    = 8
) (
  input  wire                  clk,
  input  wire                  ucie_clk,    // UCIe domain clock
  input  wire                  rst_n,
  // CXL -> UCIe  (clk domain in, ucie_clk domain out)
  input  wire                  cxl_in_valid,
  input  wire [WIDTH-1:0]      cxl_in_data,
  output wire                  cxl_in_ready,
  output wire                  ucie_out_valid,
  output wire [WIDTH-1:0]      ucie_out_data,
  input  wire                  ucie_out_ready,
  // UCIe -> CXL  (ucie_clk domain in, clk domain out)
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

  // --- Reset synchronization ---
  wire clk_rst_n;
  wire ucie_rst_n;

  reset_sync #(.STAGES(2)) u_clk_rst_sync (
    .clk(clk), .async_rst_n(rst_n), .sync_rst_n(clk_rst_n)
  );
  reset_sync #(.STAGES(2)) u_ucie_rst_sync (
    .clk(ucie_clk), .async_rst_n(rst_n), .sync_rst_n(ucie_rst_n)
  );

  // --- CDC for external control signals ---
  wire link_up_clk;
  wire err_inj_en_clk;

  cdc_sync #(.STAGES(2)) u_link_up_cdc (
    .clk(clk), .rst_n(clk_rst_n), .d(link_up), .q(link_up_clk)
  );
  cdc_sync #(.STAGES(2)) u_err_inj_cdc (
    .clk(clk), .rst_n(clk_rst_n), .d(err_inj_en), .q(err_inj_en_clk)
  );

  // --- Packet classification ---
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

  // --- Translation functions (unchanged from Phase 2) ---

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
            (cxl_pkt[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_MEM_OP_RD_DATA) ?
              UCIE_MSG_MEM_RD_DATA : UCIE_MSG_MEM_RD,
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
            (cxl_pkt[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_MEM_OP_WR_DATA) ?
              UCIE_MSG_MEM_WR_DATA : UCIE_MSG_MEM_WR,
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
            (cxl_pkt[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_CACHE_OP_RD_DATA) ?
              UCIE_MSG_CACHE_RD_DATA : UCIE_MSG_CACHE_RD,
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
            (cxl_pkt[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_CACHE_OP_WR_DATA) ?
              UCIE_MSG_CACHE_WR_DATA : UCIE_MSG_CACHE_WR,
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

  // Async FIFO status (per clock domain)
  wire c2u_posted_w_full;   // clk domain
  wire c2u_posted_r_empty;  // ucie_clk domain
  wire c2u_np_w_full;       // clk domain
  wire c2u_np_r_empty;      // ucie_clk domain
  wire u2c_w_full;          // ucie_clk domain
  wire u2c_r_empty;         // clk domain

  // FIFO read data (combinational, respective read domain)
  wire [WIDTH-1:0] c2u_posted_rd_data;  // ucie_clk domain
  wire [WIDTH-1:0] c2u_np_rd_data;      // ucie_clk domain
  wire [WIDTH-1:0] u2c_rd_data;         // clk domain

  // Synchronize c2u r_empty signals to clk for drain_done
  wire c2u_posted_r_empty_clk;
  wire c2u_np_r_empty_clk;
  cdc_sync #(.STAGES(2)) u_p_empty_cdc (
    .clk  (clk), .rst_n(clk_rst_n),
    .d    (c2u_posted_r_empty), .q(c2u_posted_r_empty_clk)
  );
  cdc_sync #(.STAGES(2)) u_np_empty_cdc (
    .clk  (clk), .rst_n(clk_rst_n),
    .d    (c2u_np_r_empty),    .q(c2u_np_r_empty_clk)
  );

  // Phase 4: link readiness FSM (clk domain)
  wire all_empty  = c2u_posted_r_empty_clk && c2u_np_r_empty_clk && u2c_r_empty;
  wire bridge_open;

  reset_drain u_reset_drain (
    .clk       (clk),
    .rst_n     (clk_rst_n),
    .link_up   (link_up_clk),
    .all_empty (all_empty),
    .open      (bridge_open),
    .drain_done(drain_done)
  );

  // Synchronize bridge_open to ucie_clk domain
  wire bridge_open_ucie;
  cdc_sync #(.STAGES(2)) u_open_cdc (
    .clk  (ucie_clk), .rst_n(ucie_rst_n),
    .d    (bridge_open), .q(bridge_open_ucie)
  );

  // Error injection (clk domain — affects CXL->UCIe write data)
  wire [WIDTH-1:0] c2u_wr_data_raw = translate_cxl_to_ucie(cxl_in_data);
  wire [WIDTH-1:0] c2u_wr_data     = err_inj_en_clk ?
    {c2u_wr_data_raw[WIDTH-1:1], ~c2u_wr_data_raw[0]} : c2u_wr_data_raw;

  // UCIe->CXL translation (ucie_clk domain input)
  wire [WIDTH-1:0] u2c_wr_data = translate_ucie_to_cxl(ucie_in_data);

  wire cxl_in_is_posted_w = is_posted(cxl_in_data);

  // --- CXL domain ingress gating (clk) ---
  wire posted_crd_avail;
  wire np_crd_avail;
  assign cxl_in_ready  = bridge_open && (cxl_in_is_posted_w ?
                         (!c2u_posted_w_full && posted_crd_avail) :
                         (!c2u_np_w_full     && np_crd_avail));

  // --- UCIe domain ingress gating (ucie_clk) ---
  wire cpl_crd_avail;
  assign ucie_in_ready = bridge_open_ucie && (!u2c_w_full && cpl_crd_avail);

  // --- CXL domain egress (clk) ---
  assign cxl_out_valid = !u2c_r_empty;
  assign cxl_out_data  = u2c_rd_data;

  // --- UCIe domain egress arbiter (ucie_clk) ---
  // Posted-priority: when both FIFOs have data, posted drains first.
  // Lock the selection while a beat is in flight (valid && !ready).
  reg  arb_locked_r;
  reg  arb_sel_posted_r;

  wire arb_sel_now   = !c2u_posted_r_empty;
  wire arb_sel_final = arb_locked_r ? arb_sel_posted_r : arb_sel_now;

  always @(posedge ucie_clk or negedge ucie_rst_n) begin
    if (!ucie_rst_n) begin
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

  assign ucie_out_valid = !c2u_posted_r_empty || !c2u_np_r_empty;
  assign ucie_out_data  = arb_sel_final ? c2u_posted_rd_data : c2u_np_rd_data;

  wire c2u_wr        = cxl_in_valid && cxl_in_ready;
  wire c2u_posted_wr = c2u_wr &&  cxl_in_is_posted_w;
  wire c2u_np_wr     = c2u_wr && !cxl_in_is_posted_w;
  wire c2u_posted_rd = ucie_out_valid && ucie_out_ready &&  arb_sel_final;
  wire c2u_np_rd     = ucie_out_valid && ucie_out_ready && !arb_sel_final;
  wire u2c_wr        = ucie_in_valid && ucie_in_ready;
  wire u2c_rd        = cxl_out_ready && cxl_out_valid;

  // --- Credit counters and pulse syncs ---

  wire posted_ret_clk;
  credit_pulse_sync u_posted_ret_sync (
    .src_clk(ucie_clk), .src_rst_n(ucie_rst_n), .src_pulse(c2u_posted_rd),
    .dst_clk(clk),      .dst_rst_n(clk_rst_n),   .dst_pulse(posted_ret_clk)
  );
  credit_counter #(.CREDITS(POSTED_CREDITS)) u_posted_crd (
    .clk(clk), .rst_n(clk_rst_n), .consume(c2u_posted_wr), .ret(posted_ret_clk),
    .available(posted_crd_avail)
  );

  wire np_ret_clk;
  credit_pulse_sync u_np_ret_sync (
    .src_clk(ucie_clk), .src_rst_n(ucie_rst_n), .src_pulse(c2u_np_rd),
    .dst_clk(clk),      .dst_rst_n(clk_rst_n),   .dst_pulse(np_ret_clk)
  );
  credit_counter #(.CREDITS(NP_CREDITS)) u_np_crd (
    .clk(clk), .rst_n(clk_rst_n), .consume(c2u_np_wr), .ret(np_ret_clk),
    .available(np_crd_avail)
  );

  wire cpl_ret_ucie;
  credit_pulse_sync u_cpl_ret_sync (
    .src_clk(clk),      .src_rst_n(clk_rst_n),   .src_pulse(u2c_rd),
    .dst_clk(ucie_clk), .dst_rst_n(ucie_rst_n), .dst_pulse(cpl_ret_ucie)
  );
  credit_counter #(.CREDITS(CPL_CREDITS)) u_cpl_crd (
    .clk(ucie_clk), .rst_n(ucie_rst_n), .consume(u2c_wr), .ret(cpl_ret_ucie),
    .available(cpl_crd_avail)
  );

  // --- Async FIFOs ---

  async_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_c2u_posted (
    .w_clk   (clk),           .w_rst_n(clk_rst_n),
    .w_en    (c2u_posted_wr), .w_data (c2u_wr_data), .w_full (c2u_posted_w_full),
    .r_clk   (ucie_clk),      .r_rst_n(ucie_rst_n),
    .r_en    (c2u_posted_rd), .r_data (c2u_posted_rd_data), .r_empty(c2u_posted_r_empty)
  );

  async_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_c2u_np (
    .w_clk   (clk),        .w_rst_n(clk_rst_n),
    .w_en    (c2u_np_wr), .w_data (c2u_wr_data), .w_full (c2u_np_w_full),
    .r_clk   (ucie_clk),   .r_rst_n(ucie_rst_n),
    .r_en    (c2u_np_rd), .r_data (c2u_np_rd_data), .r_empty(c2u_np_r_empty)
  );

  async_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_u2c (
    .w_clk   (ucie_clk), .w_rst_n(ucie_rst_n),
    .w_en    (u2c_wr),   .w_data (u2c_wr_data), .w_full (u2c_w_full),
    .r_clk   (clk),      .r_rst_n(clk_rst_n),
    .r_en    (u2c_rd),   .r_data (u2c_rd_data),  .r_empty(u2c_r_empty)
  );

`ifdef FORMAL
  // Helper: checksum check for the u2c direction.
  wire [63:0] f_u2c_chk_zero = {ucie_in_data[63:8], 8'h00};
  wire        f_u2c_cs_ok    = (ucie_in_data[7:0] == bridge_checksum(f_u2c_chk_zero));

  // Credits formal (clk domain)
  always @(*) begin
    if (clk_rst_n) begin
      if (c2u_posted_wr) assert (posted_crd_avail);
      if (c2u_np_wr)     assert (np_crd_avail);
    end
  end

  // Credits formal (ucie_clk domain)
  always @(*) begin
    if (ucie_rst_n) begin
      if (u2c_wr) assert (cpl_crd_avail);
    end
  end

  // Translation kind preservation (combinational, clock-agnostic).
  always @(*) begin
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_IO_REQ ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_RD  ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_WR  ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_RD ||
        cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_WR)
      assert (c2u_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_AD_REQ);
    else
      assert (c2u_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_ERROR);

    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_RD) begin
      if (cxl_in_data[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_MEM_OP_RD_DATA)
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_MEM_RD_DATA);
      else
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_MEM_RD);
    end
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_WR) begin
      if (cxl_in_data[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_MEM_OP_WR_DATA)
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_MEM_WR_DATA);
      else
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_MEM_WR);
    end
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_RD) begin
      if (cxl_in_data[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_CACHE_OP_RD_DATA)
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_CACHE_RD_DATA);
      else
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_CACHE_RD);
    end
    if (cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_WR) begin
      if (cxl_in_data[PKT_CODE_MSB:PKT_CODE_LSB] == CXL_CACHE_OP_WR_DATA)
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_CACHE_WR_DATA);
      else
        assert (c2u_wr_data[PKT_CODE_MSB:PKT_CODE_LSB] == UCIE_MSG_CACHE_WR);
    end

    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_AD_CPL && f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_IO_CPL);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_MEM_CPL && f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_CPL);
    if (ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_CACHE_CPL && f_u2c_cs_ok)
      assert (u2c_wr_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_CPL);

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

  // Phase 4: link gating (clk domain — ingress gating is combinational).
  always @(*) begin
    if (!bridge_open) begin
      assert (cxl_in_ready  == 1'b0);
      assert (ucie_in_ready == 1'b0 || bridge_open_ucie == 1'b1);
    end
  end

  // Phase 4: error injection correctness (combinational).
  always @(*) begin
    if (err_inj_en_clk) begin
      assert (c2u_wr_data[0]         == ~c2u_wr_data_raw[0]);
      assert (c2u_wr_data[WIDTH-1:1] ==  c2u_wr_data_raw[WIDTH-1:1]);
    end else begin
      assert (c2u_wr_data == c2u_wr_data_raw);
    end
  end

  // Ordering domain routing (clk domain, combinational).
  always @(*) begin
    if (cxl_in_valid && cxl_in_ready) begin
      if (cxl_in_is_posted_w)
        assert (c2u_posted_wr && !c2u_np_wr);
      else
        assert (!c2u_posted_wr && c2u_np_wr);
    end
  end

  // Arbiter correctness (ucie_clk domain).
  always_ff @(posedge ucie_clk) begin
    if (ucie_rst_n) begin
      if (ucie_out_valid && ucie_out_ready) begin
        assert (c2u_posted_rd == arb_sel_final);
        assert (c2u_np_rd     == !arb_sel_final);
      end
      if (!arb_locked_r && !c2u_posted_r_empty)
        assert (arb_sel_final == 1'b1);
    end
  end

  // Covers (clk domain).
  always_ff @(posedge clk) begin
    if (clk_rst_n) begin
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_RD);
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_MEM_WR);
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_RD);
      cover (cxl_in_valid && cxl_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == CXL_PKT_KIND_CACHE_WR);
      cover (cxl_in_valid && !cxl_in_ready && !bridge_open);
      cover (cxl_in_valid && !cxl_in_ready && bridge_open && !posted_crd_avail);
      cover (err_inj_en_clk && c2u_np_wr);
      cover (drain_done);
    end
  end

  // Covers (ucie_clk domain).
  always_ff @(posedge ucie_clk) begin
    if (ucie_rst_n) begin
      cover (ucie_in_valid && !ucie_in_ready && bridge_open_ucie && !cpl_crd_avail);
      cover (ucie_in_valid && ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_MEM_CPL);
      cover (ucie_in_valid && ucie_in_data[PKT_KIND_MSB:PKT_KIND_LSB] == UCIE_PKT_KIND_CACHE_CPL);
      cover (c2u_posted_rd && !c2u_np_r_empty);
    end
  end
`endif

endmodule
