`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [63:0] PI_wr_data;
  reg [0:0] PI_rst_n;
  reg [0:0] PI_rd_en;
  reg [0:0] PI_wr_en;
  wire [0:0] PI_clk = clock;
  sync_fifo UUT (
    .wr_data(PI_wr_data),
    .rst_n(PI_rst_n),
    .rd_en(PI_rd_en),
    .wr_en(PI_wr_en),
    .clk(PI_clk)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$255  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$247  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$253  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$259  = 1'b1;
    UUT._witness_.anyinit_procdff_156 = 3'b000;
    UUT._witness_.anyinit_procdff_161 = 3'b000;
    UUT._witness_.anyinit_procdff_166 = 4'b1000;
    UUT.\mem[0]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[1]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[2]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[3]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[4]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[5]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[6]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    UUT.\mem[7]  = 64'b0000000000000000000000000000000000000000000000000000000000000000;

    // state 0
    PI_wr_data = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_rst_n = 1'b1;
    PI_rd_en = 1'b0;
    PI_wr_en = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_wr_data <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_rst_n <= 1'b0;
      PI_rd_en <= 1'b0;
      PI_wr_en <= 1'b0;
    end

    genclock <= cycle < 1;
    cycle <= cycle + 1;
  end
endmodule
