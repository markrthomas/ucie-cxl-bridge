// Shared packet-field definitions for the CXL<->UCIe bridge.
// Phase 2: CXL.io (req/cpl), CXL.mem (rd/wr/cpl), CXL.cache (rd/wr/cpl),
//          and matching UCIe adapter request and completion kinds.

`ifndef CXL_UCIE_BRIDGE_DEFS_VH
`define CXL_UCIE_BRIDGE_DEFS_VH

// ---- CXL packet kinds [63:60] ----
localparam [3:0] CXL_PKT_KIND_IO_REQ    = 4'h1;
localparam [3:0] CXL_PKT_KIND_IO_CPL    = 4'h2;
localparam [3:0] CXL_PKT_KIND_MEM_RD    = 4'h3;
localparam [3:0] CXL_PKT_KIND_MEM_WR    = 4'h4;
localparam [3:0] CXL_PKT_KIND_MEM_CPL   = 4'h5;
localparam [3:0] CXL_PKT_KIND_CACHE_RD  = 4'h6;
localparam [3:0] CXL_PKT_KIND_CACHE_WR  = 4'h7;
localparam [3:0] CXL_PKT_KIND_CACHE_CPL = 4'h8;
localparam [3:0] CXL_PKT_KIND_INVALID   = 4'hf;

// ---- CXL.io opcodes (PKT_CODE field of IO_REQ) ----
localparam [3:0] CXL_IO_OP_CFG_RD      = 4'h1;
localparam [3:0] CXL_IO_OP_CFG_WR      = 4'h2;
localparam [3:0] CXL_IO_OP_MEM_RD      = 4'h3;
localparam [3:0] CXL_IO_OP_MEM_WR      = 4'h4;

// ---- CXL completion status (PKT_CODE field of *_CPL) ----
localparam [3:0] CXL_CPL_SC            = 4'h1; // Successful Completion
localparam [3:0] CXL_CPL_UR            = 4'h2; // Unsupported Request
localparam [3:0] CXL_CPL_CA            = 4'h3; // Completer Abort

// ---- UCIe adapter packet kinds [63:60] ----
localparam [3:0] UCIE_PKT_KIND_AD_REQ    = 4'h8;
localparam [3:0] UCIE_PKT_KIND_AD_CPL    = 4'h9;
localparam [3:0] UCIE_PKT_KIND_MEM_CPL   = 4'ha;
localparam [3:0] UCIE_PKT_KIND_CACHE_CPL = 4'hb;
localparam [3:0] UCIE_PKT_KIND_ERROR     = 4'he;

// ---- UCIe AD_REQ message types (PKT_CODE field) ----
localparam [3:0] UCIE_MSG_CFG           = 4'h1;
localparam [3:0] UCIE_MSG_MEM           = 4'h2;
localparam [3:0] UCIE_MSG_MEM_RD        = 4'h3;
localparam [3:0] UCIE_MSG_MEM_WR        = 4'h4;
localparam [3:0] UCIE_MSG_CACHE_RD      = 4'h5;
localparam [3:0] UCIE_MSG_CACHE_WR      = 4'h6;

// ---- UCIe completion status (PKT_CODE field of *_CPL) ----
localparam [3:0] UCIE_CPL_SC            = 4'h1;
localparam [3:0] UCIE_CPL_UR            = 4'h2;
localparam [3:0] UCIE_CPL_CA            = 4'h3;

// ---- 64-bit packet field bit-ranges ----
localparam integer PKT_KIND_MSB         = 63;
localparam integer PKT_KIND_LSB         = 60;
localparam integer PKT_CODE_MSB         = 59;
localparam integer PKT_CODE_LSB         = 56;
localparam integer PKT_TAG_MSB          = 55;
localparam integer PKT_TAG_LSB          = 48;
localparam integer PKT_ADDR_MSB         = 47;
localparam integer PKT_ADDR_LSB         = 32;
localparam integer PKT_LEN_MSB          = 31;
localparam integer PKT_LEN_LSB          = 24;
localparam integer PKT_ID_MSB           = 23;
localparam integer PKT_ID_LSB           = 16;
localparam integer PKT_AUX_MSB          = 15;
localparam integer PKT_AUX_LSB          = 8;
localparam integer PKT_MISC_MSB         = 7;
localparam integer PKT_MISC_LSB         = 0;

// ---- CXL pack helpers ----

function automatic [63:0] pack_cxl_io_req;
  input [3:0] opcode;
  input [7:0] tag;
  input [15:0] addr16;
  input [7:0] length_dw;
  input [7:0] requester_id;
  input [7:0] first_dw_be;
  begin
    pack_cxl_io_req = {CXL_PKT_KIND_IO_REQ, opcode, tag, addr16,
                       length_dw, requester_id, first_dw_be, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_io_cpl;
  input [3:0] status;
  input [7:0] tag;
  input [15:0] byte_count;
  input [7:0] length_dw;
  input [7:0] completer_id;
  input [7:0] lower_addr;
  begin
    pack_cxl_io_cpl = {CXL_PKT_KIND_IO_CPL, status, tag, byte_count,
                       length_dw, completer_id, lower_addr, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_mem_rd;
  input [3:0] opcode;
  input [7:0] tag;
  input [15:0] addr16;
  input [7:0] length_dw;
  input [7:0] requester_id;
  input [7:0] attr;
  begin
    pack_cxl_mem_rd = {CXL_PKT_KIND_MEM_RD, opcode, tag, addr16,
                       length_dw, requester_id, attr, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_mem_wr;
  input [3:0] opcode;
  input [7:0] tag;
  input [15:0] addr16;
  input [7:0] length_dw;
  input [7:0] requester_id;
  input [7:0] attr;
  begin
    pack_cxl_mem_wr = {CXL_PKT_KIND_MEM_WR, opcode, tag, addr16,
                       length_dw, requester_id, attr, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_mem_cpl;
  input [3:0] status;
  input [7:0] tag;
  input [15:0] byte_count;
  input [7:0] length_dw;
  input [7:0] completer_id;
  input [7:0] lower_addr;
  begin
    pack_cxl_mem_cpl = {CXL_PKT_KIND_MEM_CPL, status, tag, byte_count,
                        length_dw, completer_id, lower_addr, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_cache_rd;
  input [3:0] opcode;
  input [7:0] tag;
  input [15:0] addr16;
  input [7:0] length_dw;
  input [7:0] requester_id;
  input [7:0] attr;
  begin
    pack_cxl_cache_rd = {CXL_PKT_KIND_CACHE_RD, opcode, tag, addr16,
                         length_dw, requester_id, attr, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_cache_wr;
  input [3:0] opcode;
  input [7:0] tag;
  input [15:0] addr16;
  input [7:0] length_dw;
  input [7:0] requester_id;
  input [7:0] attr;
  begin
    pack_cxl_cache_wr = {CXL_PKT_KIND_CACHE_WR, opcode, tag, addr16,
                         length_dw, requester_id, attr, 8'h00};
  end
endfunction

function automatic [63:0] pack_cxl_cache_cpl;
  input [3:0] status;
  input [7:0] tag;
  input [15:0] byte_count;
  input [7:0] length_dw;
  input [7:0] completer_id;
  input [7:0] lower_addr;
  begin
    pack_cxl_cache_cpl = {CXL_PKT_KIND_CACHE_CPL, status, tag, byte_count,
                          length_dw, completer_id, lower_addr, 8'h00};
  end
endfunction

// ---- UCIe pack helpers ----

function automatic [63:0] pack_ucie_ad_req;
  input [3:0] msg_type;
  input [7:0] txn_id;
  input [15:0] addr16;
  input [7:0] length_dw;
  input [7:0] src_id;
  input [7:0] attr;
  input [7:0] checksum;
  begin
    pack_ucie_ad_req = {UCIE_PKT_KIND_AD_REQ, msg_type, txn_id, addr16,
                        length_dw, src_id, attr, checksum};
  end
endfunction

function automatic [63:0] pack_ucie_ad_cpl;
  input [3:0] cpl_status;
  input [7:0] txn_id;
  input [15:0] byte_count;
  input [7:0] length_dw;
  input [7:0] src_id;
  input [7:0] lower_addr;
  input [7:0] checksum;
  begin
    pack_ucie_ad_cpl = {UCIE_PKT_KIND_AD_CPL, cpl_status, txn_id, byte_count,
                        length_dw, src_id, lower_addr, checksum};
  end
endfunction

function automatic [63:0] pack_ucie_mem_cpl;
  input [3:0] cpl_status;
  input [7:0] txn_id;
  input [15:0] byte_count;
  input [7:0] length_dw;
  input [7:0] src_id;
  input [7:0] lower_addr;
  input [7:0] checksum;
  begin
    pack_ucie_mem_cpl = {UCIE_PKT_KIND_MEM_CPL, cpl_status, txn_id, byte_count,
                         length_dw, src_id, lower_addr, checksum};
  end
endfunction

function automatic [63:0] pack_ucie_cache_cpl;
  input [3:0] cpl_status;
  input [7:0] txn_id;
  input [15:0] byte_count;
  input [7:0] length_dw;
  input [7:0] src_id;
  input [7:0] lower_addr;
  input [7:0] checksum;
  begin
    pack_ucie_cache_cpl = {UCIE_PKT_KIND_CACHE_CPL, cpl_status, txn_id, byte_count,
                           length_dw, src_id, lower_addr, checksum};
  end
endfunction

// ---- Checksum ----
// 8-bit XOR over all 8 bytes. Caller must zero the misc byte before calling.
function automatic [7:0] bridge_checksum;
  input [63:0] packet_wo_checksum;
  begin
    bridge_checksum = packet_wo_checksum[63:56] ^ packet_wo_checksum[55:48] ^
                      packet_wo_checksum[47:40] ^ packet_wo_checksum[39:32] ^
                      packet_wo_checksum[31:24] ^ packet_wo_checksum[23:16] ^
                      packet_wo_checksum[15:8] ^ packet_wo_checksum[7:0];
  end
endfunction

`endif
