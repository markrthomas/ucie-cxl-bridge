// Simulation-only checker: verifies that each payload async FIFO carries beats
// through intact and in order. Taps the DUT's payload-FIFO write/read strobes.
// Phase 7 verification.
//
// C2U payload is split posted/NP (u_c2u_pp / u_c2u_npp) so a reordering egress
// arbiter keeps each header paired with its own payload; U2C payload is a single
// in-order FIFO. One gold queue per physical FIFO.

module cxl_ucie_bridge_payload_chk #(
  parameter integer WIDTH = 64
) (
  input wire                  clk,       // CXL domain
  input wire                  ucie_clk,  // UCIe domain
  input wire                  rst_n,

  // C2U posted payload FIFO (write @clk, read @ucie_clk)
  input wire                  c2u_pp_wr,
  input wire [WIDTH-1:0]      c2u_pp_w_data,
  input wire                  c2u_pp_rd,
  input wire [WIDTH-1:0]      c2u_pp_rd_data,

  // C2U non-posted payload FIFO (write @clk, read @ucie_clk)
  input wire                  c2u_npp_wr,
  input wire [WIDTH-1:0]      c2u_npp_w_data,
  input wire                  c2u_npp_rd,
  input wire [WIDTH-1:0]      c2u_npp_rd_data,

  // U2C payload FIFO (write @ucie_clk, read @clk)
  input wire                  u2c_payload_wr,
  input wire [WIDTH-1:0]      u2c_payload_w_data,
  input wire                  u2c_payload_rd,
  input wire [WIDTH-1:0]      u2c_payload_rd_data
);

  // SystemVerilog queues for simulation-only golden modeling.
  reg [WIDTH-1:0] c2u_pp_q[$];
  reg [WIDTH-1:0] c2u_npp_q[$];
  reg [WIDTH-1:0] u2c_q[$];

  integer c2u_pp_beats;
  integer c2u_npp_beats;
  integer u2c_beats;

  initial begin
    c2u_pp_beats  = 0;
    c2u_npp_beats = 0;
    u2c_beats     = 0;
  end

  // --- Ingress: record written beats ---
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      c2u_pp_q.delete();
      c2u_npp_q.delete();
    end else begin
      if (c2u_pp_wr)  c2u_pp_q.push_back(c2u_pp_w_data);
      if (c2u_npp_wr) c2u_npp_q.push_back(c2u_npp_w_data);
    end
  end

  always @(posedge ucie_clk or negedge rst_n) begin
    if (!rst_n) begin
      u2c_q.delete();
    end else begin
      if (u2c_payload_wr) u2c_q.push_back(u2c_payload_w_data);
    end
  end

  // --- Egress: check read beats against the recorded gold ---
  reg [WIDTH-1:0] exp_pp, exp_npp, exp_u2c;

  always @(posedge ucie_clk) begin
    if (rst_n) begin
      if (c2u_pp_rd) begin
        if (c2u_pp_q.size() == 0) begin
          $display("ASSERT FAIL [payload_chk]: c2u posted payload read but gold queue empty");
          $finish(1);
        end else begin
          exp_pp = c2u_pp_q.pop_front();
          if (c2u_pp_rd_data !== exp_pp) begin
            $display("ASSERT FAIL [payload_chk]: c2u posted payload mismatch exp=%h got=%h",
                     exp_pp, c2u_pp_rd_data);
            $finish(1);
          end
          c2u_pp_beats = c2u_pp_beats + 1;
        end
      end
      if (c2u_npp_rd) begin
        if (c2u_npp_q.size() == 0) begin
          $display("ASSERT FAIL [payload_chk]: c2u NP payload read but gold queue empty");
          $finish(1);
        end else begin
          exp_npp = c2u_npp_q.pop_front();
          if (c2u_npp_rd_data !== exp_npp) begin
            $display("ASSERT FAIL [payload_chk]: c2u NP payload mismatch exp=%h got=%h",
                     exp_npp, c2u_npp_rd_data);
            $finish(1);
          end
          c2u_npp_beats = c2u_npp_beats + 1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (rst_n) begin
      if (u2c_payload_rd) begin
        if (u2c_q.size() == 0) begin
          $display("ASSERT FAIL [payload_chk]: u2c payload read but gold queue empty");
          $finish(1);
        end else begin
          exp_u2c = u2c_q.pop_front();
          if (u2c_payload_rd_data !== exp_u2c) begin
            $display("ASSERT FAIL [payload_chk]: u2c payload mismatch exp=%h got=%h",
                     exp_u2c, u2c_payload_rd_data);
            $finish(1);
          end
          u2c_beats = u2c_beats + 1;
        end
      end
    end
  end

endmodule
