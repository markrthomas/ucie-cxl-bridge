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
  reg [0:0] PI_ucie_in_valid;
  reg [63:0] PI_cxl_in_data;
  reg [0:0] PI_ucie_clk;
  reg [0:0] PI_cxl_in_valid;
  reg [63:0] PI_ucie_in_data;
  reg [0:0] PI_link_up;
  reg [0:0] PI_ucie_out_ready;
  reg [0:0] PI_cxl_out_ready;
  wire [0:0] PI_clk = clock;
  reg [0:0] PI_rst_n;
  reg [0:0] PI_err_inj_en;
  cxl_ucie_bridge UUT (
    .ucie_in_valid(PI_ucie_in_valid),
    .cxl_in_data(PI_cxl_in_data),
    .ucie_clk(PI_ucie_clk),
    .cxl_in_valid(PI_cxl_in_valid),
    .ucie_in_data(PI_ucie_in_data),
    .link_up(PI_link_up),
    .ucie_out_ready(PI_ucie_out_ready),
    .cxl_out_ready(PI_cxl_out_ready),
    .clk(PI_clk),
    .rst_n(PI_rst_n),
    .err_inj_en(PI_err_inj_en)
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
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$assert$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:440$277_EN#sampled$9878  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$assert$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:444$285_EN#sampled$9898  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9388#sampled$9876  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9394#sampled$9886  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9400#sampled$9896  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9406#sampled$9906  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9412#sampled$9916  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9418#sampled$9926  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9424#sampled$9936  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9430#sampled$9946  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9436#sampled$9956  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9442#sampled$9966  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9448#sampled$9976  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9454#sampled$9986  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9460#sampled$9996  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9392#sampled$10136  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9398#sampled$10146  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9404#sampled$10156  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9410#sampled$10166  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9416#sampled$10176  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9422#sampled$10186  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9428#sampled$10196  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9434#sampled$10206  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9440#sampled$10216  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9446#sampled$10226  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9452#sampled$10236  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9458#sampled$10246  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9464#sampled$10256  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9466#sampled$10268  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9468#sampled$10280  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$10267#sampled$10270  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$10279#sampled$10282  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$cover$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:451$288_EN#sampled$9998  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$eq$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:440$278_Y#sampled$10138  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$eq$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:441$281_Y#sampled$10148  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:451$290_Y#sampled$10168  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:452$293_Y#sampled$10178  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:453$296_Y#sampled$10188  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:454$299_Y#sampled$10198  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:455$304_Y#sampled$10208  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:456$306_Y#sampled$10218  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:464$311_Y#sampled$10238  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:465$314_Y#sampled$10248  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/cxl_ucie_bridge .\v:466$317_Y#sampled$10258  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$/arb_sel_final#sampled$10158  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:101:sample_data$/drain_done#sampled$10228  = 1'b0;
    // UUT.$auto$clk2fflogic.\cc:87:sample_control_edge$/clk#sampled$10170  = 1'b1;
    // UUT.$auto$clk2fflogic.\cc:87:sample_control_edge$/ucie_clk#sampled$9990  = 1'b1;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9370#sampled$9690  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9372#sampled$9702  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9374#sampled$9714  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9376#sampled$9726  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9378#sampled$9738  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9380#sampled$9750  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9382#sampled$9842  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9384#sampled$9854  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8172#sampled$9762  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8179#sampled$9772  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8186#sampled$9782  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8193#sampled$9792  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8200#sampled$9802  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8207#sampled$9812  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8214#sampled$9822  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8221#sampled$9832  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9689#sampled$9692  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9701#sampled$9704  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9713#sampled$9716  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9725#sampled$9728  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9737#sampled$9740  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9749#sampled$9752  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9841#sampled$9844  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9853#sampled$9856  = 4'b0000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[0]#sampled$9760  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[1]#sampled$9770  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[2]#sampled$9780  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[3]#sampled$9790  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[4]#sampled$9800  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[5]#sampled$9810  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[6]#sampled$9820  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:101:sample_data$/mem[7]#sampled$9830  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:87:sample_control_edge$/r_clk#sampled$9730  = 1'b1;
    // UUT.u_c2u_np.$auto$clk2fflogic.\cc:87:sample_control_edge$/w_clk#sampled$9858  = 1'b1;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9370#sampled$9690  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9372#sampled$9702  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9374#sampled$9714  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9376#sampled$9726  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9378#sampled$9738  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9380#sampled$9750  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9382#sampled$9842  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9384#sampled$9854  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8172#sampled$9762  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8179#sampled$9772  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8186#sampled$9782  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8193#sampled$9792  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8200#sampled$9802  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8207#sampled$9812  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8214#sampled$9822  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8221#sampled$9832  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9689#sampled$9692  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9701#sampled$9704  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9713#sampled$9716  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9725#sampled$9728  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9737#sampled$9740  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9749#sampled$9752  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9841#sampled$9844  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9853#sampled$9856  = 4'b0000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[0]#sampled$9760  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[1]#sampled$9770  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[2]#sampled$9780  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[3]#sampled$9790  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[4]#sampled$9800  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[5]#sampled$9810  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[6]#sampled$9820  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:101:sample_data$/mem[7]#sampled$9830  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:87:sample_control_edge$/r_clk#sampled$9730  = 1'b1;
    // UUT.u_c2u_posted.$auto$clk2fflogic.\cc:87:sample_control_edge$/w_clk#sampled$9858  = 1'b1;
    // UUT.u_np_empty_cdc.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9386#sampled$9866  = 2'b00;
    // UUT.u_np_empty_cdc.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9865#sampled$9868  = 2'b00;
    // UUT.u_np_empty_cdc.$auto$clk2fflogic.\cc:87:sample_control_edge$/clk#sampled$9870  = 1'b1;
    // UUT.u_open_cdc.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9386#sampled$9866  = 2'b00;
    // UUT.u_open_cdc.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9865#sampled$9868  = 2'b00;
    // UUT.u_open_cdc.$auto$clk2fflogic.\cc:87:sample_control_edge$/clk#sampled$9870  = 1'b1;
    // UUT.u_p_empty_cdc.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9386#sampled$9866  = 2'b00;
    // UUT.u_p_empty_cdc.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9865#sampled$9868  = 2'b00;
    // UUT.u_p_empty_cdc.$auto$clk2fflogic.\cc:87:sample_control_edge$/clk#sampled$9870  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$assert$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:47$45_EN#sampled$10342  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9470#sampled$10290  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9476#sampled$10300  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9482#sampled$10310  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9492#sampled$10320  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9498#sampled$10330  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:107:execute$9504#sampled$10340  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9474#sampled$10410  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9480#sampled$10420  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9486#sampled$10430  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9496#sampled$10440  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9502#sampled$10450  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:116:execute$9508#sampled$10460  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9510#sampled$10482  = 1'b1;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9512#sampled$10494  = 2'b00;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$10481#sampled$10484  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$10493#sampled$10496  = 2'b00;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$eq$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:47$46_Y#sampled$10442  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$eq$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:47$47_Y#sampled$10412  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$eq$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:54$55_Y#sampled$10452  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$logic_and$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:56$59_Y#sampled$10462  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$ne$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:49$49_Y#sampled$10422  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$$past$ ..\/ ..\/ ..\/ ..\/src/reset_drain .\v:56$39$0#sampled$10470  = 2'b00;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$/state#sampled$10472  = 2'b00;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:101:sample_data$1'1#sampled$10432  = 1'b0;
    // UUT.u_reset_drain.$auto$clk2fflogic.\cc:87:sample_control_edge$/clk#sampled$10474  = 1'b1;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9370#sampled$9690  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9372#sampled$9702  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9374#sampled$9714  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9376#sampled$9726  = 4'b1000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9378#sampled$9738  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9380#sampled$9750  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9382#sampled$9842  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$async2sync .\cc:253:execute$9384#sampled$9854  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8172#sampled$9762  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8179#sampled$9772  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8186#sampled$9782  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8193#sampled$9792  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8200#sampled$9802  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8207#sampled$9812  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8214#sampled$9822  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$8221#sampled$9832  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9689#sampled$9692  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9701#sampled$9704  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9713#sampled$9716  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9725#sampled$9728  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9737#sampled$9740  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9749#sampled$9752  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9841#sampled$9844  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$$auto$rtlil .\cc:3390:Mux$9853#sampled$9856  = 4'b0000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[0]#sampled$9760  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[1]#sampled$9770  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[2]#sampled$9780  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[3]#sampled$9790  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[4]#sampled$9800  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[5]#sampled$9810  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[6]#sampled$9820  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:101:sample_data$/mem[7]#sampled$9830  = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:87:sample_control_edge$/r_clk#sampled$9730  = 1'b1;
    // UUT.u_u2c.$auto$clk2fflogic.\cc:87:sample_control_edge$/w_clk#sampled$9858  = 1'b1;

    // state 0
    PI_ucie_in_valid = 1'b0;
    PI_cxl_in_data = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_ucie_clk = 1'b0;
    PI_cxl_in_valid = 1'b0;
    PI_ucie_in_data = 64'b0000000000000000000000000000000000000000000000000000000000000000;
    PI_link_up = 1'b0;
    PI_ucie_out_ready = 1'b0;
    PI_cxl_out_ready = 1'b0;
    PI_rst_n = 1'b0;
    PI_err_inj_en = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_ucie_in_valid <= 1'b0;
      PI_cxl_in_data <= 64'b0111000000000000000000000000000000000000000000000000000000000000;
      PI_ucie_clk <= 1'b0;
      PI_cxl_in_valid <= 1'b1;
      PI_ucie_in_data <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_link_up <= 1'b0;
      PI_ucie_out_ready <= 1'b0;
      PI_cxl_out_ready <= 1'b0;
      PI_rst_n <= 1'b1;
      PI_err_inj_en <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      PI_ucie_in_valid <= 1'b0;
      PI_cxl_in_data <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_ucie_clk <= 1'b0;
      PI_cxl_in_valid <= 1'b0;
      PI_ucie_in_data <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
      PI_link_up <= 1'b0;
      PI_ucie_out_ready <= 1'b0;
      PI_cxl_out_ready <= 1'b0;
      PI_rst_n <= 1'b0;
      PI_err_inj_en <= 1'b0;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
