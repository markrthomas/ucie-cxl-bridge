// Credit pulse synchronizer: crosses a single-cycle credit return pulse 
// from the source clock domain to the destination clock domain.
// Uses a toggle-based handshake to ensure no pulses are lost.

module credit_pulse_sync (
  input  wire src_clk,
  input  wire src_rst_n,
  input  wire src_pulse,
  input  wire dst_clk,
  input  wire dst_rst_n,
  output wire dst_pulse
);

  reg src_toggle_r;
  always @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n)
      src_toggle_r <= 1'b0;
    else if (src_pulse)
      src_toggle_r <= ~src_toggle_r;
  end

  wire dst_toggle_sync;
  cdc_sync #(.STAGES(2)) u_toggle_cdc (
    .clk  (dst_clk),
    .rst_n(dst_rst_n),
    .d    (src_toggle_r),
    .q    (dst_toggle_sync)
  );

  reg dst_toggle_r;
  always @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n)
      dst_toggle_r <= 1'b0;
    else
      dst_toggle_r <= dst_toggle_sync;
  end

  assign dst_pulse = (dst_toggle_r != dst_toggle_sync);

endmodule
