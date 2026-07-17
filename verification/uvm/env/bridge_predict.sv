// Self-contained protocol prediction helpers for the UVM scoreboard.
//
// This mirrors the translation, checksum, and payload-length logic in
// src/cxl_ucie_bridge_defs.vh + src/cxl_ucie_bridge.v. It is intentionally a
// package-local copy rather than an `include of the RTL header: in a single
// VCS compilation unit the DUT includes cxl_ucie_bridge_defs.vh first, so its
// include guard would skip the header here, and $unit-scope params are not
// visible inside a package anyway. Keep this file in sync with the RTL defs.

// ---- Packet field positions (bit indices into a 64-bit flit) ----
// layout: {kind[63:60], code[59:56], tag[55:48], addr16[47:32],
//          len[31:24], id[23:16], aux[15:8], misc[7:0]}

// ---- CXL packet kinds ----
localparam bit [3:0] PK_CXL_IO_REQ    = 4'h1;
localparam bit [3:0] PK_CXL_IO_CPL    = 4'h2;
localparam bit [3:0] PK_CXL_MEM_RD    = 4'h3;
localparam bit [3:0] PK_CXL_MEM_WR    = 4'h4;
localparam bit [3:0] PK_CXL_MEM_CPL   = 4'h5;
localparam bit [3:0] PK_CXL_CACHE_RD  = 4'h6;
localparam bit [3:0] PK_CXL_CACHE_WR  = 4'h7;
localparam bit [3:0] PK_CXL_CACHE_CPL = 4'h8;
localparam bit [3:0] PK_CXL_INVALID   = 4'hf;

// ---- CXL.io opcodes (code field of IO_REQ) ----
localparam bit [3:0] OP_IO_CFG_RD = 4'h1;
localparam bit [3:0] OP_IO_CFG_WR = 4'h2;
localparam bit [3:0] OP_IO_MEM_RD = 4'h3;
localparam bit [3:0] OP_IO_MEM_WR = 4'h4;

// ---- CXL mem/cache opcodes that carry data ----
localparam bit [3:0] OP_MEM_RD_DATA   = 4'h2;
localparam bit [3:0] OP_MEM_WR_DATA   = 4'h3;
localparam bit [3:0] OP_CACHE_RD_DATA = 4'h2;
localparam bit [3:0] OP_CACHE_WR_DATA = 4'h3;

// ---- UCIe adapter packet kinds ----
localparam bit [3:0] PK_UCIE_AD_REQ    = 4'h8;
localparam bit [3:0] PK_UCIE_AD_CPL    = 4'h9;
localparam bit [3:0] PK_UCIE_MEM_CPL   = 4'ha;
localparam bit [3:0] PK_UCIE_CACHE_CPL = 4'hb;
localparam bit [3:0] PK_UCIE_ERROR     = 4'he;

// ---- UCIe AD_REQ message types (code field) ----
localparam bit [3:0] MSG_CFG          = 4'h1;
localparam bit [3:0] MSG_MEM          = 4'h2;
localparam bit [3:0] MSG_MEM_RD       = 4'h3;
localparam bit [3:0] MSG_MEM_WR       = 4'h4;
localparam bit [3:0] MSG_MEM_RD_DATA  = 4'h5;
localparam bit [3:0] MSG_MEM_WR_DATA  = 4'h6;
localparam bit [3:0] MSG_CACHE_RD     = 4'h7;
localparam bit [3:0] MSG_CACHE_WR     = 4'h8;
localparam bit [3:0] MSG_CACHE_RD_DATA = 4'h9;
localparam bit [3:0] MSG_CACHE_WR_DATA = 4'ha;

// ---- UCIe completion status (code field of *_CPL) ----
localparam bit [3:0] CPL_SC = 4'h1;
localparam bit [3:0] CPL_UR = 4'h2;
localparam bit [3:0] CPL_CA = 4'h3;

// ---- Field accessors ----
function automatic bit [3:0]  f_kind(bit [63:0] p); return p[63:60]; endfunction
function automatic bit [3:0]  f_code(bit [63:0] p); return p[59:56]; endfunction
function automatic bit [7:0]  f_tag (bit [63:0] p); return p[55:48]; endfunction
function automatic bit [15:0] f_addr(bit [63:0] p); return p[47:32]; endfunction
function automatic bit [7:0]  f_len (bit [63:0] p); return p[31:24]; endfunction
function automatic bit [7:0]  f_id  (bit [63:0] p); return p[23:16]; endfunction
function automatic bit [7:0]  f_aux (bit [63:0] p); return p[15:8];  endfunction
function automatic bit [7:0]  f_misc(bit [63:0] p); return p[7:0];   endfunction

// ---- CRC-8/CCITT (poly 0x07) checksum over bytes [63:8], misc byte = 0 ----
function automatic bit [7:0] crc8_step(bit [7:0] b);
  bit [7:0] c;
  int i;
  begin
    c = b;
    for (i = 0; i < 8; i++)
      c = c[7] ? ((c << 1) ^ 8'h07) : (c << 1);
    return c;
  end
endfunction

function automatic bit [7:0] bridge_checksum(bit [63:0] p);
  bit [7:0] c;
  begin
    c = 8'h00;
    c = crc8_step(c ^ p[63:56]);
    c = crc8_step(c ^ p[55:48]);
    c = crc8_step(c ^ p[47:40]);
    c = crc8_step(c ^ p[39:32]);
    c = crc8_step(c ^ p[31:24]);
    c = crc8_step(c ^ p[23:16]);
    c = crc8_step(c ^ p[15:8]);
    return c;
  end
endfunction

// ---- Ordering class of a CXL request (mirrors RTL is_posted) ----
function automatic bit is_posted_cxl(bit [63:0] p);
  return (f_kind(p) == PK_CXL_MEM_WR) || (f_kind(p) == PK_CXL_CACHE_WR);
endfunction

// A translated UCIe egress request that could only have come from the posted
// C2U FIFO (posted writes map to MEM_WR / CACHE_WR message types).
function automatic bit is_ucie_posted(bit [63:0] p);
  bit [3:0] c = f_code(p);
  return (c == MSG_MEM_WR) || (c == MSG_CACHE_WR);
endfunction

// ---- Payload beat counts (mirror RTL get_*_payload_len) ----
function automatic int c2u_payload_len(bit [63:0] p);
  bit [3:0] kind = f_kind(p);
  bit [3:0] code = f_code(p);
  if (kind == PK_CXL_MEM_WR || kind == PK_CXL_CACHE_WR ||
      (kind == PK_CXL_IO_REQ && (code == OP_IO_CFG_WR || code == OP_IO_MEM_WR)))
    return (int'(f_len(p)) + 1) >> 1;
  return 0;
endfunction

function automatic int u2c_payload_len(bit [63:0] p);
  bit [3:0] kind = f_kind(p);
  if ((kind == PK_UCIE_AD_CPL || kind == PK_UCIE_MEM_CPL || kind == PK_UCIE_CACHE_CPL) &&
      (f_code(p) == CPL_SC) && (f_len(p) > 0))
    return (int'(f_len(p)) + 1) >> 1;
  return 0;
endfunction

// ---- Translation prediction (mirror translate_cxl_to_ucie in the RTL) ----
function automatic bit [63:0] predict_ucie_from_cxl(bit [63:0] c);
  bit [3:0]  kind = f_kind(c);
  bit [3:0]  code = f_code(c);
  bit [7:0]  attr = f_aux(c) ^ f_misc(c);
  bit [3:0]  msg;
  bit [63:0] raw;
  begin
    case (kind)
      PK_CXL_IO_REQ:   msg = (code == OP_IO_CFG_RD || code == OP_IO_CFG_WR) ? MSG_CFG : MSG_MEM;
      PK_CXL_MEM_RD:   msg = (code == OP_MEM_RD_DATA)   ? MSG_MEM_RD_DATA   : MSG_MEM_RD;
      PK_CXL_MEM_WR:   msg = (code == OP_MEM_WR_DATA)   ? MSG_MEM_WR_DATA   : MSG_MEM_WR;
      PK_CXL_CACHE_RD: msg = (code == OP_CACHE_RD_DATA) ? MSG_CACHE_RD_DATA : MSG_CACHE_RD;
      PK_CXL_CACHE_WR: msg = (code == OP_CACHE_WR_DATA) ? MSG_CACHE_WR_DATA : MSG_CACHE_WR;
      default:         msg = 4'h0;
    endcase
    if (kind == PK_CXL_IO_REQ || kind == PK_CXL_MEM_RD || kind == PK_CXL_MEM_WR ||
        kind == PK_CXL_CACHE_RD || kind == PK_CXL_CACHE_WR)
      raw = {PK_UCIE_AD_REQ, msg, f_tag(c), f_addr(c), f_len(c), f_id(c), attr, 8'h00};
    else
      raw = {PK_UCIE_ERROR, 4'h0, f_tag(c), 16'h0000, 8'h00, f_id(c), 8'h00, 8'h00};
    raw[7:0] = bridge_checksum({raw[63:8], 8'h00});
    return raw;
  end
endfunction

// ---- Translation prediction (mirror translate_ucie_to_cxl in the RTL) ----
function automatic bit [63:0] predict_cxl_from_ucie(bit [63:0] u);
  bit [3:0]  kind = f_kind(u);
  bit        ok   = (bridge_checksum({u[63:8], 8'h00}) == f_misc(u));
  bit [63:0] inv  = {PK_CXL_INVALID, 4'h0, f_tag(u), 16'h0000, 8'h00, f_id(u), 8'h00, 8'h00};
  begin
    case (kind)
      PK_UCIE_AD_CPL:
        return ok ? {PK_CXL_IO_CPL,    f_code(u), f_tag(u), f_addr(u), f_len(u), f_id(u), f_aux(u), 8'h00} : inv;
      PK_UCIE_MEM_CPL:
        return ok ? {PK_CXL_MEM_CPL,   f_code(u), f_tag(u), f_addr(u), f_len(u), f_id(u), f_aux(u), 8'h00} : inv;
      PK_UCIE_CACHE_CPL:
        return ok ? {PK_CXL_CACHE_CPL, f_code(u), f_tag(u), f_addr(u), f_len(u), f_id(u), f_aux(u), 8'h00} : inv;
      default:
        return inv;
    endcase
  end
endfunction
