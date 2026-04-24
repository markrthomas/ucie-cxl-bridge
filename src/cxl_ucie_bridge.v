// CXL <-> UCIe bridge — protocol mapping TBD.
// Buffered ready/valid datapaths: parameterized sync FIFO per direction (default depth 8).
// FIFO_DEPTH must be a power of 2 (see sync_fifo.v).

/* verilator lint_off UNUSEDPARAM */
`include "cxl_ucie_bridge_defs.vh"
/* verilator lint_on UNUSEDPARAM */

module cxl_ucie_bridge #(
  parameter integer WIDTH       = 64,
  parameter integer FIFO_DEPTH  = 8
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
  input  wire                  cxl_out_ready
);

  generate
    if (WIDTH != 64) begin : gen_width_check
      initial $fatal(1, "cxl_ucie_bridge: WIDTH must be 64 for the typed packet model");
    end
  endgenerate

  wire c2u_full;
  wire c2u_empty;
  wire u2c_full;
  wire u2c_empty;
  wire [WIDTH-1:0] c2u_wr_data;
  wire [WIDTH-1:0] u2c_wr_data;

  assign cxl_in_ready   = !c2u_full;
  assign ucie_out_valid = !c2u_empty;
  assign ucie_in_ready  = !u2c_full;
  assign cxl_out_valid  = !u2c_empty;

  wire c2u_wr = cxl_in_valid && cxl_in_ready;
  wire c2u_rd = ucie_out_ready && ucie_out_valid;
  wire u2c_wr = ucie_in_valid && ucie_in_ready;
  wire u2c_rd = cxl_out_ready && cxl_out_valid;

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
        default: begin
          raw_pkt = {CXL_PKT_KIND_INVALID, 4'h0, ucie_pkt[PKT_TAG_MSB:PKT_TAG_LSB],
                     16'h0000, 8'h00, ucie_pkt[PKT_ID_MSB:PKT_ID_LSB],
                     8'h00, 8'h00};
          translate_ucie_to_cxl = raw_pkt[WIDTH-1:0];
        end
      endcase
    end
  endfunction

  assign c2u_wr_data = translate_cxl_to_ucie(cxl_in_data);
  assign u2c_wr_data = translate_ucie_to_cxl(ucie_in_data);

  sync_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_c2u (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_en   (c2u_wr),
    .wr_data (c2u_wr_data),
    .full    (c2u_full),
    .empty   (c2u_empty),
    .rd_en   (c2u_rd),
    .rd_data (ucie_out_data)
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

endmodule
