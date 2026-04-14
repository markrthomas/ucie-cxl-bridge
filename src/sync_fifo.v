// Synchronous FIFO: same clock for read and write. DEPTH must be a power of 2.
// First-word fall-through: rd_data is combinational from mem[rd_ptr]; empty/full
// are registered-path stable after each posedge.

module sync_fifo #(
  parameter integer WIDTH = 64,
  parameter integer DEPTH = 8
) (
  input  wire                  clk,
  input  wire                  rst_n,
  input  wire                  wr_en,
  input  wire [WIDTH-1:0]      wr_data,
  output wire                  full,
  output wire                  empty,
  input  wire                  rd_en,
  output wire [WIDTH-1:0]      rd_data
);

  generate
    if (DEPTH < 1 || (DEPTH & (DEPTH - 1)) != 0) begin : gen_depth_check
      initial $fatal(1, "sync_fifo: DEPTH must be a power of 2 and >= 1");
    end
  endgenerate

  localparam integer ADDR_W = $clog2(DEPTH);
  // Sized depth for comparisons (avoids tool-specific width mismatch on count).
  localparam [ADDR_W:0] DEPTH_CNT = DEPTH[ADDR_W:0];

  reg [WIDTH-1:0] mem[0:DEPTH-1];
  reg [ADDR_W-1:0] wr_ptr;
  reg [ADDR_W-1:0] rd_ptr;
  reg [ADDR_W:0] count;

  assign full  = (count == DEPTH_CNT);
  assign empty = (count == {(ADDR_W + 1) {1'b0}});
  assign rd_data = mem[rd_ptr];

  wire wr = wr_en && !full;
  wire rd = rd_en && !empty;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= {ADDR_W{1'b0}};
      rd_ptr <= {ADDR_W{1'b0}};
      count  <= {(ADDR_W + 1) {1'b0}};
    end else begin
      if (wr)
        mem[wr_ptr] <= wr_data;
      if (wr && !rd)
        count <= count + 1'b1;
      else if (rd && !wr)
        count <= count - 1'b1;
      if (wr)
        wr_ptr <= wr_ptr + 1'b1;
      if (rd)
        rd_ptr <= rd_ptr + 1'b1;
    end
  end

`ifdef FORMAL
  // BMC must not start from physically impossible register values (unconstrained init).
  initial begin
    assume (count <= DEPTH_CNT);
    assume (wr_ptr < DEPTH);
    assume (rd_ptr < DEPTH);
  end

  // Bounded-model properties (SymbiYosys / Yosys); not enabled for normal simulation.
  always_ff @(posedge clk) begin
    if (rst_n === 1'b1) begin
      assert (count <= DEPTH_CNT);
      assert (count >= {(ADDR_W + 1) {1'b0}});
    end
  end

  // Reachability (cover mode): show FIFO can fill, drain partially, and do same-cycle wr+rd.
  always_ff @(posedge clk) begin
    if (rst_n === 1'b1) begin
      cover (full);
      cover (wr && rd);
      cover ((count > {(ADDR_W + 1) {1'b0}}) && (count < DEPTH_CNT));
    end
  end
`endif

endmodule
