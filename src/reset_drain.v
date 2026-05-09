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
  output wire open,
  output wire drain_done
);

  localparam [1:0] S_DOWN  = 2'd0;
  localparam [1:0] S_UP    = 2'd1;
  localparam [1:0] S_DRAIN = 2'd2;

  reg [1:0] state;

  assign open       = (state == S_UP);
  assign drain_done = (state == S_DOWN || state == S_DRAIN) && all_empty;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_DOWN;
    end else begin
      case (state)
        S_DOWN:  if ( link_up)   state <= S_UP;
        S_UP:    if (!link_up)   state <= S_DRAIN;
        S_DRAIN: if ( all_empty) state <= S_DOWN;
        default:                 state <= S_DOWN;
      endcase
    end
  end

`ifdef FORMAL
  initial assume (!rst_n);

  always_ff @(posedge clk) begin
    if (rst_n) begin
      // legal 2-bit encoding (S_DOWN=0, S_UP=1, S_DRAIN=2; 3 is unused)
      assert (state != 2'd3);
      // drain_done tracks (S_DOWN || S_DRAIN) && all_empty
      assert (drain_done == ((state == S_DOWN || state == S_DRAIN) && all_empty));
      // reachability
      cover (state == S_UP);
      cover (state == S_DRAIN);
      // full DOWN->UP->DRAIN->DOWN cycle
      cover (state == S_DOWN && $past(state) == S_DRAIN);
    end
  end
`endif

endmodule
