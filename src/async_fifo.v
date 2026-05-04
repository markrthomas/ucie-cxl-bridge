// Dual-clock asynchronous FIFO with Gray-code pointer synchronization.
// DEPTH must be a power of two and >= 4.
// r_data is combinational (FWFT); valid when !r_empty.
// rst_n is used for both domains (common async reset; suitable for simulation
// and experimental RTL where a single power-on reset drives both domains).

module async_fifo #(
  parameter integer WIDTH = 64,
  parameter integer DEPTH = 8
) (
  // Write side (w_clk domain)
  input  wire             w_clk,
  input  wire             w_rst_n,
  input  wire             w_en,
  input  wire [WIDTH-1:0] w_data,
  output wire             w_full,

  // Read side (r_clk domain)
  input  wire             r_clk,
  input  wire             r_rst_n,
  input  wire             r_en,
  output wire [WIDTH-1:0] r_data,
  output wire             r_empty
);

  localparam integer ADDR_W = $clog2(DEPTH);

  generate
    if (DEPTH < 4 || (DEPTH & (DEPTH-1)) != 0) begin : gen_depth_check
      initial $fatal(1, "async_fifo: DEPTH must be a power of two and >= 4");
    end
  endgenerate

  // Full when top-two Gray bits differ between write and synchronized-read pointer,
  // rest match.  Expressed as a constant XOR mask so there are no variable selects.
  localparam [ADDR_W:0] FULL_MASK = {2'b11, {(ADDR_W-1){1'b0}}};

  // ---- Shared memory (written on w_clk, read combinationally) ----
  (* ram_style = "distributed" *)
  reg [WIDTH-1:0] mem [0:DEPTH-1];

  // All pointer registers declared together to avoid forward-reference errors in iverilog.
  reg [ADDR_W:0] w_ptr_bin;
  reg [ADDR_W:0] w_ptr_gray;
  reg [ADDR_W:0] r_ptr_bin;
  reg [ADDR_W:0] r_ptr_gray;

  // ---- Write domain ----

  // 2-flop sync: r_ptr_gray -> w_clk
  reg [ADDR_W:0] r_sync0_w, r_sync1_w;
  /* verilator lint_off SYNCASYNCNET */
  always @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) begin
      r_sync0_w <= {(ADDR_W+1){1'b0}};
      r_sync1_w <= {(ADDR_W+1){1'b0}};
    end else begin
      r_sync0_w <= r_ptr_gray;
      r_sync1_w <= r_sync0_w;
    end
  end
  /* verilator lint_on SYNCASYNCNET */
  wire [ADDR_W:0] r_ptr_gray_sync = r_sync1_w;

  assign w_full = ((w_ptr_gray ^ r_ptr_gray_sync) == FULL_MASK);

  always @(posedge w_clk or negedge w_rst_n) begin
    if (!w_rst_n) begin
      w_ptr_bin  <= {(ADDR_W+1){1'b0}};
      w_ptr_gray <= {(ADDR_W+1){1'b0}};
    end else if (w_en && !w_full) begin
      mem[w_ptr_bin[ADDR_W-1:0]] <= w_data;
      w_ptr_bin  <= w_ptr_bin + 1'b1;
      w_ptr_gray <= (w_ptr_bin + 1'b1) ^ ((w_ptr_bin + 1'b1) >> 1);
    end
  end

  // ---- Read domain ----

  // 2-flop sync: w_ptr_gray -> r_clk
  reg [ADDR_W:0] w_sync0_r, w_sync1_r;
  /* verilator lint_off SYNCASYNCNET */
  always @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      w_sync0_r <= {(ADDR_W+1){1'b0}};
      w_sync1_r <= {(ADDR_W+1){1'b0}};
    end else begin
      w_sync0_r <= w_ptr_gray;
      w_sync1_r <= w_sync0_r;
    end
  end
  /* verilator lint_on SYNCASYNCNET */
  wire [ADDR_W:0] w_ptr_gray_sync = w_sync1_r;

  assign r_empty = (r_ptr_gray == w_ptr_gray_sync);

  always @(posedge r_clk or negedge r_rst_n) begin
    if (!r_rst_n) begin
      r_ptr_bin  <= {(ADDR_W+1){1'b0}};
      r_ptr_gray <= {(ADDR_W+1){1'b0}};
    end else if (r_en && !r_empty) begin
      r_ptr_bin  <= r_ptr_bin + 1'b1;
      r_ptr_gray <= (r_ptr_bin + 1'b1) ^ ((r_ptr_bin + 1'b1) >> 1);
    end
  end

  assign r_data = mem[r_ptr_bin[ADDR_W-1:0]];

endmodule
