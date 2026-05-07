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
  wire [0:0] PI_clk = clock;
  reg [0:0] PI_link_up;
  reg [0:0] PI_rst_n;
  reg [0:0] PI_all_empty;
  reset_drain UUT (
    .clk(PI_clk),
    .link_up(PI_link_up),
    .rst_n(PI_rst_n),
    .all_empty(PI_all_empty)
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
    // UUT.$auto$async2sync.\cc:107:execute$96  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$100  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$106  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$94  = 1'b1;
    UUT._witness_.anyinit_procdff_57 = 2'b00;
    UUT._witness_.anyinit_procdff_62 = 1'b0;
    UUT._witness_.anyinit_procdff_67 = 2'b00;

    // state 0
    PI_link_up = 1'b0;
    PI_rst_n = 1'b0;
    PI_all_empty = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_link_up <= 1'b1;
      PI_rst_n <= 1'b1;
      PI_all_empty <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_link_up <= 1'b0;
      PI_rst_n <= 1'b1;
      PI_all_empty <= 1'b0;
    end

    // state 3
    if (cycle == 2) begin
      PI_link_up <= 1'b0;
      PI_rst_n <= 1'b1;
      PI_all_empty <= 1'b0;
    end

    // state 4
    if (cycle == 3) begin
      PI_link_up <= 1'b0;
      PI_rst_n <= 1'b0;
      PI_all_empty <= 1'b0;
    end

    genclock <= cycle < 4;
    cycle <= cycle + 1;
  end
endmodule
