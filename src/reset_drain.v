// Reset-drain FSM: gates the bridge open/closed based on link state.
//
//  S_DOWN  -> S_UP    when link_up asserted
//  S_UP    -> S_DRAIN when link_up deasserted
//  S_DRAIN -> S_DOWN  when all FIFOs empty (all_empty)
//
// open is high only in S_UP.
// drain_done is combinationally high when all_empty (safe to power-down / re-sequence).

module reset_drain (
  input  wire clk,
  input  wire rst_n,
  input  wire link_up,
  input  wire all_empty,
  output reg  open,
  output wire drain_done
);

  localparam [1:0] S_DOWN  = 2'd0;
  localparam [1:0] S_UP    = 2'd1;
  localparam [1:0] S_DRAIN = 2'd2;

  reg [1:0] state;

  assign drain_done = all_empty;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_DOWN;
      open  <= 1'b0;
    end else begin
      case (state)
        S_DOWN:  if ( link_up)   begin state <= S_UP;    open <= 1'b1; end
        S_UP:    if (!link_up)   begin state <= S_DRAIN; open <= 1'b0; end
        S_DRAIN: if ( all_empty)       state <= S_DOWN;
        default:                       state <= S_DOWN;
      endcase
    end
  end

`ifdef FORMAL
  initial assume (!rst_n);

  always_ff @(posedge clk) begin
    if (rst_n) begin
      // open is asserted iff the FSM is in S_UP
      if (state == S_UP) assert (open == 1'b1);
      else               assert (open == 1'b0);
      // legal 2-bit encoding (S_DOWN=0, S_UP=1, S_DRAIN=2; 3 is unused)
      assert (state != 2'd3);
      // drain_done tracks all_empty
      assert (drain_done == all_empty);
      // reachability
      cover (state == S_UP);
      cover (state == S_DRAIN);
      // full DOWN->UP->DRAIN->DOWN cycle
      cover (state == S_DOWN && $past(state) == S_DRAIN);
    end
  end
`endif

endmodule
