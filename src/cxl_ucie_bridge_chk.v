// Simulation-only checks for cxl_ucie_bridge egress ready/valid behavior.
// Instantiated from tb_cxl_ucie_bridge; not intended for synthesis.

module cxl_ucie_bridge_chk #(
  parameter integer WIDTH = 64
) (
  input wire                  clk,
  input wire                  rst_n,
  input wire                  ucie_out_valid,
  input wire [WIDTH-1:0]      ucie_out_data,
  input wire                  ucie_out_ready,
  input wire                  cxl_out_valid,
  input wire [WIDTH-1:0]      cxl_out_data,
  input wire                  cxl_out_ready
);

  reg                 prev_uv, prev_ur;
  reg [WIDTH-1:0]     prev_ud;
  reg                 prev_cv, prev_cr;
  reg [WIDTH-1:0]     prev_cd;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_uv <= 1'b0;
      prev_ur <= 1'b0;
      prev_ud <= {WIDTH{1'b0}};
      prev_cv <= 1'b0;
      prev_cr <= 1'b0;
      prev_cd <= {WIDTH{1'b0}};
    end else begin
      if (prev_uv && !prev_ur) begin
        if (!ucie_out_valid) begin
          $display("ASSERT: ucie_out_valid dropped while sink not ready");
          $finish(1);
        end
        if (ucie_out_data !== prev_ud) begin
          $display("ASSERT: ucie_out_data changed while valid && !ready");
          $finish(1);
        end
      end

      if (prev_cv && !prev_cr) begin
        if (!cxl_out_valid) begin
          $display("ASSERT: cxl_out_valid dropped while sink not ready");
          $finish(1);
        end
        if (cxl_out_data !== prev_cd) begin
          $display("ASSERT: cxl_out_data changed while valid && !ready");
          $finish(1);
        end
      end

      prev_uv <= ucie_out_valid;
      prev_ur <= ucie_out_ready;
      prev_ud <= ucie_out_data;
      prev_cv <= cxl_out_valid;
      prev_cr <= cxl_out_ready;
      prev_cd <= cxl_out_data;
    end
  end

endmodule
