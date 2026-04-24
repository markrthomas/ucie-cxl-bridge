// Shared packet-field definitions for the first protocol-bearing bridge model.
// Scope in this revision is intentionally narrow:
// - CXL -> UCIe carries a simplified CXL.io request
// - UCIe -> CXL carries a simplified UCIe completion

`ifndef CXL_UCIE_BRIDGE_DEFS_VH
`define CXL_UCIE_BRIDGE_DEFS_VH

localparam [3:0] CXL_PKT_KIND_IO_REQ  = 4'h1;
localparam [3:0] CXL_PKT_KIND_IO_CPL  = 4'h2;
localparam [3:0] CXL_PKT_KIND_INVALID = 4'hf;

localparam [3:0] CXL_IO_OP_CFG_RD     = 4'h1;
localparam [3:0] CXL_IO_OP_CFG_WR     = 4'h2;
localparam [3:0] CXL_IO_OP_MEM_RD     = 4'h3;
localparam [3:0] CXL_IO_OP_MEM_WR     = 4'h4;

localparam [3:0] UCIE_PKT_KIND_AD_REQ = 4'h8;
localparam [3:0] UCIE_PKT_KIND_AD_CPL = 4'h9;
localparam [3:0] UCIE_PKT_KIND_ERROR  = 4'he;

localparam [3:0] UCIE_MSG_CFG         = 4'h1;
localparam [3:0] UCIE_MSG_MEM         = 4'h2;
localparam [3:0] UCIE_CPL_SC          = 4'h1;
localparam [3:0] UCIE_CPL_UR          = 4'h2;

localparam integer PKT_KIND_MSB       = 63;
localparam integer PKT_KIND_LSB       = 60;
localparam integer PKT_CODE_MSB       = 59;
localparam integer PKT_CODE_LSB       = 56;
localparam integer PKT_TAG_MSB        = 55;
localparam integer PKT_TAG_LSB        = 48;
localparam integer PKT_ADDR_MSB       = 47;
localparam integer PKT_ADDR_LSB       = 32;
localparam integer PKT_LEN_MSB        = 31;
localparam integer PKT_LEN_LSB        = 24;
localparam integer PKT_ID_MSB         = 23;
localparam integer PKT_ID_LSB         = 16;
localparam integer PKT_AUX_MSB        = 15;
localparam integer PKT_AUX_LSB        = 8;
localparam integer PKT_MISC_MSB       = 7;
localparam integer PKT_MISC_LSB       = 0;

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
