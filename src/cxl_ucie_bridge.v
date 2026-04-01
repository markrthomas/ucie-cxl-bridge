// CXL <-> UCIe bridge — protocol mapping TBD.
// Minimal registered ready/valid datapaths for simulation bring-up (iverilog).

module cxl_ucie_bridge #(
  parameter integer WIDTH = 64
) (
  input  wire                  clk,
  input  wire                  rst_n,
  // CXL -> UCIe
  input  wire                  cxl_in_valid,
  input  wire [WIDTH-1:0]      cxl_in_data,
  output wire                  cxl_in_ready,
  output reg                   ucie_out_valid,
  output reg  [WIDTH-1:0]      ucie_out_data,
  input  wire                  ucie_out_ready,
  // UCIe -> CXL
  input  wire                  ucie_in_valid,
  input  wire [WIDTH-1:0]      ucie_in_data,
  output wire                  ucie_in_ready,
  output reg                   cxl_out_valid,
  output reg  [WIDTH-1:0]      cxl_out_data,
  input  wire                  cxl_out_ready
);

  // CXL -> UCIe: one-deep output register + bubble when downstream accepts
  assign cxl_in_ready = !ucie_out_valid || ucie_out_ready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ucie_out_valid <= 1'b0;
      ucie_out_data  <= {WIDTH{1'b0}};
    end else begin
      if (cxl_in_valid && cxl_in_ready) begin
        ucie_out_valid <= 1'b1;
        ucie_out_data  <= cxl_in_data;
      end else if (ucie_out_ready && ucie_out_valid)
        ucie_out_valid <= 1'b0;
    end
  end

  // UCIe -> CXL: same structure
  assign ucie_in_ready = !cxl_out_valid || cxl_out_ready;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cxl_out_valid <= 1'b0;
      cxl_out_data  <= {WIDTH{1'b0}};
    end else begin
      if (ucie_in_valid && ucie_in_ready) begin
        cxl_out_valid <= 1'b1;
        cxl_out_data  <= ucie_in_data;
      end else if (cxl_out_ready && cxl_out_valid)
        cxl_out_valid <= 1'b0;
    end
  end

endmodule
