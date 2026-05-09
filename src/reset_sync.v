// Reset synchronizer: asynchronous assert, synchronous deassert.
// Ensures that the reset signal is released cleanly on a clock edge.

module reset_sync #(
  parameter integer STAGES = 2
) (
  input  wire clk,
  input  wire async_rst_n,
  output wire sync_rst_n
);

  /* verilator lint_off SYNCASYNCNET */
  reg [STAGES-1:0] sync_r;
  /* verilator lint_on SYNCASYNCNET */

  always @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n)
      sync_r <= {STAGES{1'b0}};
    else
      sync_r <= {sync_r[STAGES-2:0], 1'b1};
  end

  assign sync_rst_n = sync_r[STAGES-1];

endmodule
