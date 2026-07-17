// Sequence library for the CXL<->UCIe bridge UVM environment.
//
// bridge_base_seq   : legacy 10-item fully-random beat sequence (kept for
//                     smoke use; the scoreboard tolerates arbitrary beats).
// bridge_cxl_seq    : constrained-random *legal* CXL requests. A write header
//                     is followed by ceil(len/2) payload beats, matching the
//                     RTL's multi-beat protocol so the scoreboard's payload
//                     path is exercised end-to-end.
// bridge_ucie_seq   : constrained-random *legal* UCIe completions (valid CRC-8
//                     checksum). SC completions with len>0 emit payload beats.

class bridge_base_seq extends uvm_sequence#(bridge_item);
  `uvm_object_utils(bridge_base_seq)

  function new(string name = "bridge_base_seq");
    super.new(name);
  endfunction

  task body();
    repeat(10) begin
      `uvm_do(req)
    end
  endtask
endclass


// ---- Legal CXL request stimulus (drives the CXL / clk-domain sequencer) ----
class bridge_cxl_seq extends uvm_sequence#(bridge_item);
  `uvm_object_utils(bridge_cxl_seq)

  rand int num;
  constraint c_num { num inside {[20:60]}; }

  function new(string name = "bridge_cxl_seq");
    super.new(name);
  endfunction

  // Emit one beat carrying `data`.
  task send_beat(bit [63:0] data);
    bridge_item it = bridge_item::type_id::create("it");
    start_item(it);
    it.data  = data;
    it.delay = $urandom_range(0, 3);
    finish_item(it);
  endtask

  task body();
    int sel;
    bit [3:0] kind, code;
    bit [7:0] tag, len, id, aux;
    bit [15:0] addr;
    bit [63:0] hdr;
    int nb, i;
    repeat (num) begin
      tag  = $urandom; addr = $urandom; id = $urandom; aux = $urandom;
      len  = $urandom_range(0, 12);   // ceil(len/2) up to ~6 payload beats
      sel  = $urandom_range(0, 5);
      case (sel)
        0: begin kind = PK_CXL_IO_REQ;   code = OP_IO_CFG_RD; end
        1: begin kind = PK_CXL_IO_REQ;   code = OP_IO_MEM_WR; end   // NP write (payload)
        2: begin kind = PK_CXL_MEM_RD;   code = 4'h0;         end
        3: begin kind = PK_CXL_MEM_WR;   code = 4'h1;         end   // posted write (payload)
        4: begin kind = PK_CXL_CACHE_RD; code = 4'h0;         end
        5: begin kind = PK_CXL_CACHE_WR; code = 4'h1;         end   // posted write (payload)
      endcase
      hdr = {kind, code, tag, addr, len, id, aux, 8'h00};
      send_beat(hdr);
      nb = c2u_payload_len(hdr);
      for (i = 0; i < nb; i++)
        send_beat({16'hC2DA, tag, addr, id, len, 8'(i)});  // 16+8+16+8+8+8 = 64
    end
  endtask
endclass


// ---- Legal UCIe completion stimulus (drives the UCIe / ucie_clk sequencer) ----
class bridge_ucie_seq extends uvm_sequence#(bridge_item);
  `uvm_object_utils(bridge_ucie_seq)

  rand int num;
  constraint c_num { num inside {[20:60]}; }

  function new(string name = "bridge_ucie_seq");
    super.new(name);
  endfunction

  task send_beat(bit [63:0] data);
    bridge_item it = bridge_item::type_id::create("it");
    start_item(it);
    it.data  = data;
    it.delay = $urandom_range(0, 3);
    finish_item(it);
  endtask

  task body();
    int sel, ssel;
    bit [3:0] kind, status;
    bit [7:0] tag, len, id, laddr;
    bit [15:0] bc;
    bit [63:0] hdr;
    int nb, i;
    repeat (num) begin
      tag = $urandom; bc = $urandom; id = $urandom; laddr = $urandom;
      len = $urandom_range(0, 12);
      ssel = $urandom_range(0, 2);
      status = (ssel == 0) ? CPL_SC : (ssel == 1) ? CPL_UR : CPL_CA;
      sel = $urandom_range(0, 2);
      case (sel)
        0: kind = PK_UCIE_AD_CPL;
        1: kind = PK_UCIE_MEM_CPL;
        2: kind = PK_UCIE_CACHE_CPL;
      endcase
      hdr = {kind, status, tag, bc, len, id, laddr, 8'h00};
      hdr[7:0] = bridge_checksum(hdr);   // valid checksum
      send_beat(hdr);
      nb = u2c_payload_len(hdr);
      for (i = 0; i < nb; i++)
        send_beat({16'h2CDA, tag, bc, id, len, 8'(i)});  // 16+8+16+8+8+8 = 64
    end
  endtask
endclass
