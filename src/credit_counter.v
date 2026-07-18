// Credit counter: parameterized 0..CREDITS counter for per-direction flow control.
// consume: spend a credit (no-op when at 0). ret: return/grant a credit (no-op at max).
// Simultaneous consume + ret: no net change.
//
// INIT sets the reset value: INIT=CREDITS (default) models a local loopback pool
// that starts full; INIT=0 models a received-grant accumulator (Phase 9) that
// starts empty and only gains credits from external grants on `ret`.

module credit_counter #(
  parameter integer CREDITS = 8,
  parameter integer INIT    = CREDITS
) (
  input  wire clk,
  input  wire rst_n,
  input  wire consume,
  input  wire ret,
  output wire available
);

  localparam integer CNT_W  = $clog2(CREDITS + 1);
  localparam [CNT_W-1:0] CNT_MAX = CREDITS[CNT_W-1:0];
  localparam [CNT_W-1:0] CNT_INIT = INIT[CNT_W-1:0];

  reg [CNT_W-1:0] cnt;

  assign available = (cnt != {CNT_W{1'b0}});

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      cnt <= CNT_INIT;
    else begin
      if (consume && !ret && available)
        cnt <= cnt - 1'b1;
      else if (ret && !consume && cnt < CNT_MAX)
        cnt <= cnt + 1'b1;
    end
  end

`ifdef FORMAL
  initial assume (cnt <= CNT_MAX);

  always_ff @(posedge clk) begin
    if (rst_n) begin
      assert (cnt <= CNT_MAX);
      cover (cnt == {CNT_W{1'b0}});
      cover (consume && ret);
      cover (cnt == CNT_MAX);
    end
  end
`endif

endmodule
