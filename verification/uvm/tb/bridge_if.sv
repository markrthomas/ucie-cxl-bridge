interface bridge_if (input logic clk, input logic ucie_clk, input logic rst_n);
  parameter integer WIDTH = 64;

  // CXL -> UCIe path
  logic             cxl_in_valid;
  logic [WIDTH-1:0] cxl_in_data;
  logic             cxl_in_ready;
  logic             ucie_out_valid;
  logic [WIDTH-1:0] ucie_out_data;
  logic             ucie_out_ready;

  // UCIe -> CXL path
  logic             ucie_in_valid;
  logic [WIDTH-1:0] ucie_in_data;
  logic             ucie_in_ready;
  logic             cxl_out_valid;
  logic [WIDTH-1:0] cxl_out_data;
  logic             cxl_out_ready;

  // Control
  logic             link_up;
  logic             err_inj_en;
  logic             drain_done;

  clocking cxl_cb @(posedge clk);
    default input #1ns output #1ns;
    output cxl_in_valid, cxl_in_data;
    input  cxl_in_ready;
    input  cxl_out_valid, cxl_out_data;
    output cxl_out_ready;
    output link_up, err_inj_en;
    input  drain_done;
  endclocking

  clocking ucie_cb @(posedge ucie_clk);
    default input #1ns output #1ns;
    output ucie_in_valid, ucie_in_data;
    input  ucie_in_ready;
    input  ucie_out_valid, ucie_out_data;
    output ucie_out_ready;
  endclocking

  // Monitor clocking blocks
  clocking cxl_mon_cb @(posedge clk);
    default input #1ns output #1ns;
    input cxl_in_valid, cxl_in_data, cxl_in_ready;
    input cxl_out_valid, cxl_out_data, cxl_out_ready;
    input link_up, err_inj_en, drain_done;
  endclocking

  clocking ucie_mon_cb @(posedge ucie_clk);
    default input #1ns output #1ns;
    input ucie_in_valid, ucie_in_data, ucie_in_ready;
    input ucie_out_valid, ucie_out_data, ucie_out_ready;
  endclocking

endinterface
