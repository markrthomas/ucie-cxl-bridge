// CXL <-> UCIe bridge — protocol mapping TBD.
// Buffered ready/valid datapaths: parameterized sync FIFO per direction (default depth 8).
// FIFO_DEPTH must be a power of 2 (see sync_fifo.v).

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

  wire c2u_full;
  wire c2u_empty;
  wire u2c_full;
  wire u2c_empty;

  assign cxl_in_ready   = !c2u_full;
  assign ucie_out_valid = !c2u_empty;
  assign ucie_in_ready  = !u2c_full;
  assign cxl_out_valid  = !u2c_empty;

  wire c2u_wr = cxl_in_valid && cxl_in_ready;
  wire c2u_rd = ucie_out_ready && ucie_out_valid;
  wire u2c_wr = ucie_in_valid && ucie_in_ready;
  wire u2c_rd = cxl_out_ready && cxl_out_valid;

  sync_fifo #(
    .WIDTH (WIDTH),
    .DEPTH (FIFO_DEPTH)
  ) u_c2u (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_en   (c2u_wr),
    .wr_data (cxl_in_data),
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
    .wr_data (ucie_in_data),
    .full    (u2c_full),
    .empty   (u2c_empty),
    .rd_en   (u2c_rd),
    .rd_data (cxl_out_data)
  );

endmodule
