// Safety properties for sync_fifo acting as a payload FIFO.
// Bound to sync_fifo in formal verification.

module payload_fifo_props #(
  parameter integer WIDTH = 64,
  parameter integer DEPTH = 8,
  parameter integer ADDR_W = $clog2(DEPTH)
) (
  input  wire                  clk,
  input  wire                  rst_n,
  input  wire                  wr_en,
  input  wire [WIDTH-1:0]      wr_data,
  input  wire                  full,
  input  wire                  empty,
  input  wire                  rd_en,
  input  wire [WIDTH-1:0]      rd_data,
  input  wire [ADDR_W-1:0]     wr_ptr,
  input  wire [ADDR_W-1:0]     rd_ptr,
  input  wire [ADDR_W:0]       count
);

  localparam [ADDR_W:0] DEPTH_CNT = DEPTH[ADDR_W:0];

  // Pointers and count range checks
  always @(posedge clk) begin
    if (rst_n === 1'b1) begin
      assert (wr_ptr < DEPTH);
      assert (rd_ptr < DEPTH);
      assert (count <= DEPTH_CNT);
      assert (full  == (count == DEPTH_CNT));
      assert (empty == (count == {(ADDR_W + 1) {1'b0}}));
    end
  end

  // Robustness against overflow: write when full must not change state
  always @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      if ($past(full) && $past(wr_en) && !$past(rd_en)) begin
        assert (wr_ptr == $past(wr_ptr));
        assert (count == $past(count));
      end
    end
  end

  // Robustness against underflow: read when empty must not change state
  always @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      if ($past(empty) && $past(rd_en) && !$past(wr_en)) begin
        assert (rd_ptr == $past(rd_ptr));
        assert (count == $past(count));
      end
    end
  end

  // Normal write increment
  always @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      if (!$past(full) && $past(wr_en) && !$past(rd_en)) begin
        assert (wr_ptr == $past(wr_ptr) + 1'b1);
        assert (count == $past(count) + 1'b1);
      end
    end
  end

  // Normal read increment
  always @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      if (!$past(empty) && $past(rd_en) && !$past(wr_en)) begin
        assert (rd_ptr == $past(rd_ptr) + 1'b1);
        assert (count == $past(count) - 1'b1);
      end
    end
  end

  // Simultaneous read/write when neither empty nor full
  always @(posedge clk) begin
    if (rst_n && $past(rst_n)) begin
      if (!$past(full) && $past(wr_en) && !$past(empty) && $past(rd_en)) begin
        assert (wr_ptr == $past(wr_ptr) + 1'b1);
        assert (rd_ptr == $past(rd_ptr) + 1'b1);
        assert (count == $past(count));
      end
    end
  end

endmodule

// Bind statement to attach properties to sync_fifo
bind sync_fifo payload_fifo_props #(
  .WIDTH(WIDTH),
  .DEPTH(DEPTH)
) u_payload_fifo_props (
  .clk(clk),
  .rst_n(rst_n),
  .wr_en(wr_en),
  .wr_data(wr_data),
  .full(full),
  .empty(empty),
  .rd_en(rd_en),
  .rd_data(rd_data),
  .wr_ptr(wr_ptr),
  .rd_ptr(rd_ptr),
  .count(count)
);
