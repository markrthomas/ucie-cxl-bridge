// 2-flop CDC synchronizer for single-bit signals crossing asynchronous clock domains.
// STAGES must be >= 2.  Reset drives all stages to 0.

module cdc_sync #(
  parameter integer STAGES = 2
) (
  input  wire clk,
  input  wire rst_n,
  input  wire d,
  output wire q
);

  reg [STAGES-1:0] chain_r;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      chain_r <= {STAGES{1'b0}};
    else
      chain_r <= {chain_r[STAGES-2:0], d};
  end

  assign q = chain_r[STAGES-1];

endmodule
