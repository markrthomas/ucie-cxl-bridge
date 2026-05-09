"""
Shared packet helpers, gold models, and drivers for ucie-cxl-bridge cocotb tests.

Mirrors the Verilog pack helpers, bridge_checksum, expect_ucie_from_cxl, and
expect_cxl_from_ucie functions from cxl_ucie_bridge_defs.vh / tb_cxl_ucie_bridge.v.

CXLDriver   : drives cxl_in_* (clk domain) and reads cxl_out_* (clk domain).
UCIeDriver  : drives ucie_in_* (ucie_clk domain) and reads ucie_out_* (ucie_clk domain).
reset_dut   : asserts rst_n=0 for 6 clk cycles, then releases with link_up=1.
"""

from cocotb.triggers import RisingEdge

# ---- CXL packet kinds [63:60] ----
CXL_PKT_KIND_IO_REQ    = 0x1
CXL_PKT_KIND_IO_CPL    = 0x2
CXL_PKT_KIND_MEM_RD    = 0x3
CXL_PKT_KIND_MEM_WR    = 0x4
CXL_PKT_KIND_MEM_CPL   = 0x5
CXL_PKT_KIND_CACHE_RD  = 0x6
CXL_PKT_KIND_CACHE_WR  = 0x7
CXL_PKT_KIND_CACHE_CPL = 0x8
CXL_PKT_KIND_INVALID   = 0xF

# ---- CXL.io opcodes ----
CXL_IO_OP_CFG_RD = 0x1
CXL_IO_OP_CFG_WR = 0x2
CXL_IO_OP_MEM_RD = 0x3
CXL_IO_OP_MEM_WR = 0x4

# ---- CXL completion status ----
CXL_CPL_SC = 0x1
CXL_CPL_UR = 0x2
CXL_CPL_CA = 0x3

# ---- CXL mem/cache opcodes ----
CXL_MEM_OP_RD      = 0x0
CXL_MEM_OP_WR      = 0x1
CXL_MEM_OP_RD_DATA = 0x2
CXL_MEM_OP_WR_DATA = 0x3
CXL_CACHE_OP_RD      = 0x0
CXL_CACHE_OP_WR      = 0x1
CXL_CACHE_OP_RD_DATA = 0x2
CXL_CACHE_OP_WR_DATA = 0x3

# ---- UCIe adapter packet kinds [63:60] ----
UCIE_PKT_KIND_AD_REQ    = 0x8
UCIE_PKT_KIND_AD_CPL    = 0x9
UCIE_PKT_KIND_MEM_CPL   = 0xA
UCIE_PKT_KIND_CACHE_CPL = 0xB
UCIE_PKT_KIND_ERROR     = 0xE

# ---- UCIe AD_REQ message types (PKT_CODE) ----
UCIE_MSG_CFG        = 0x1
UCIE_MSG_MEM        = 0x2
UCIE_MSG_MEM_RD     = 0x3
UCIE_MSG_MEM_WR     = 0x4
UCIE_MSG_MEM_RD_DATA   = 0x5
UCIE_MSG_MEM_WR_DATA   = 0x6
UCIE_MSG_CACHE_RD      = 0x7
UCIE_MSG_CACHE_WR      = 0x8
UCIE_MSG_CACHE_RD_DATA = 0x9
UCIE_MSG_CACHE_WR_DATA = 0xA

# ---- UCIe completion status ----
UCIE_CPL_SC = 0x1
UCIE_CPL_UR = 0x2
UCIE_CPL_CA = 0x3


# ---- Packet field bit positions ----
PKT_KIND_MSB, PKT_KIND_LSB =  63, 60
PKT_CODE_MSB, PKT_CODE_LSB =  59, 56
PKT_TAG_MSB,  PKT_TAG_LSB  =  55, 48
PKT_ADDR_MSB, PKT_ADDR_LSB =  47, 32
PKT_LEN_MSB,  PKT_LEN_LSB  =  31, 24
PKT_ID_MSB,   PKT_ID_LSB   =  23, 16
PKT_AUX_MSB,  PKT_AUX_LSB  =  15,  8
PKT_MISC_MSB, PKT_MISC_LSB =   7,  0


def _pack64(kind, code, tag, addr, length, id_, aux, misc):
    return (
        ((kind   & 0xF)    << 60) |
        ((code   & 0xF)    << 56) |
        ((tag    & 0xFF)   << 48) |
        ((addr   & 0xFFFF) << 32) |
        ((length & 0xFF)   << 24) |
        ((id_    & 0xFF)   << 16) |
        ((aux    & 0xFF)   <<  8) |
        (misc    & 0xFF)
    )


def _get_field(pkt, msb, lsb):
    return (pkt >> lsb) & ((1 << (msb - lsb + 1)) - 1)


# ---- CXL pack helpers ----

def pack_cxl_io_req(opcode, tag, addr16, length_dw, req_id, first_dw_be):
    return _pack64(CXL_PKT_KIND_IO_REQ, opcode, tag, addr16, length_dw, req_id, first_dw_be, 0)

def pack_cxl_io_cpl(status, tag, byte_count, length_dw, completer_id, lower_addr):
    return _pack64(CXL_PKT_KIND_IO_CPL, status, tag, byte_count, length_dw, completer_id, lower_addr, 0)

def pack_cxl_mem_rd(opcode, tag, addr16, length_dw, req_id, attr):
    return _pack64(CXL_PKT_KIND_MEM_RD, opcode, tag, addr16, length_dw, req_id, attr, 0)

def pack_cxl_mem_wr(opcode, tag, addr16, length_dw, req_id, attr):
    return _pack64(CXL_PKT_KIND_MEM_WR, opcode, tag, addr16, length_dw, req_id, attr, 0)

def pack_cxl_mem_cpl(status, tag, byte_count, length_dw, completer_id, lower_addr):
    return _pack64(CXL_PKT_KIND_MEM_CPL, status, tag, byte_count, length_dw, completer_id, lower_addr, 0)

def pack_cxl_cache_rd(opcode, tag, addr16, length_dw, req_id, attr):
    return _pack64(CXL_PKT_KIND_CACHE_RD, opcode, tag, addr16, length_dw, req_id, attr, 0)

def pack_cxl_cache_wr(opcode, tag, addr16, length_dw, req_id, attr):
    return _pack64(CXL_PKT_KIND_CACHE_WR, opcode, tag, addr16, length_dw, req_id, attr, 0)

def pack_cxl_cache_cpl(status, tag, byte_count, length_dw, completer_id, lower_addr):
    return _pack64(CXL_PKT_KIND_CACHE_CPL, status, tag, byte_count, length_dw, completer_id, lower_addr, 0)


# ---- UCIe pack helpers ----

def pack_ucie_ad_req(msg_type, txn_id, addr16, length_dw, src_id, attr, checksum=0):
    return _pack64(UCIE_PKT_KIND_AD_REQ, msg_type, txn_id, addr16, length_dw, src_id, attr, checksum)

def pack_ucie_ad_cpl(cpl_status, txn_id, byte_count, length_dw, src_id, lower_addr, checksum=0):
    return _pack64(UCIE_PKT_KIND_AD_CPL, cpl_status, txn_id, byte_count, length_dw, src_id, lower_addr, checksum)

def pack_ucie_mem_cpl(cpl_status, txn_id, byte_count, length_dw, src_id, lower_addr, checksum=0):
    return _pack64(UCIE_PKT_KIND_MEM_CPL, cpl_status, txn_id, byte_count, length_dw, src_id, lower_addr, checksum)

def pack_ucie_cache_cpl(cpl_status, txn_id, byte_count, length_dw, src_id, lower_addr, checksum=0):
    return _pack64(UCIE_PKT_KIND_CACHE_CPL, cpl_status, txn_id, byte_count, length_dw, src_id, lower_addr, checksum)


# ---- Checksum ----

def _crc8_step(b):
    """One byte through 8 iterations of CRC-8/CCITT (poly=0x07). Matches Verilog crc8_step."""
    b &= 0xFF
    for _ in range(8):
        b = ((b << 1) ^ 0x07) & 0xFF if (b & 0x80) else (b << 1) & 0xFF
    return b


def bridge_checksum(pkt_64):
    """CRC-8/CCITT over bytes [63:8] of a 64-bit packet (byte [7:0] must be 0)."""
    c = 0
    for shift in (56, 48, 40, 32, 24, 16, 8):
        c = _crc8_step(c ^ ((pkt_64 >> shift) & 0xFF))
    return c


def with_checksum(pkt_64):
    """Set the MISC byte [7:0] to the CRC-8 checksum of the other 7 bytes."""
    return (pkt_64 & ~0xFF) | bridge_checksum(pkt_64 & ~0xFF)


# ---- Gold models (mirror translate_* functions in bridge RTL) ----

def expect_ucie_from_cxl(cxl_pkt):
    """Expected UCIe output for a given CXL input packet."""
    kind = _get_field(cxl_pkt, PKT_KIND_MSB, PKT_KIND_LSB)
    code = _get_field(cxl_pkt, PKT_CODE_MSB, PKT_CODE_LSB)
    tag  = _get_field(cxl_pkt, PKT_TAG_MSB,  PKT_TAG_LSB)
    addr = _get_field(cxl_pkt, PKT_ADDR_MSB, PKT_ADDR_LSB)
    ln   = _get_field(cxl_pkt, PKT_LEN_MSB,  PKT_LEN_LSB)
    id_  = _get_field(cxl_pkt, PKT_ID_MSB,   PKT_ID_LSB)
    aux  = _get_field(cxl_pkt, PKT_AUX_MSB,  PKT_AUX_LSB)
    misc = _get_field(cxl_pkt, PKT_MISC_MSB, PKT_MISC_LSB)
    attr = (aux ^ misc) & 0xFF

    if kind == CXL_PKT_KIND_IO_REQ:
        msg = UCIE_MSG_CFG if code in (CXL_IO_OP_CFG_RD, CXL_IO_OP_CFG_WR) else UCIE_MSG_MEM
        return with_checksum(pack_ucie_ad_req(msg, tag, addr, ln, id_, attr))
    elif kind == CXL_PKT_KIND_MEM_RD:
        msg = UCIE_MSG_MEM_RD_DATA if code == CXL_MEM_OP_RD_DATA else UCIE_MSG_MEM_RD
        return with_checksum(pack_ucie_ad_req(msg, tag, addr, ln, id_, attr))
    elif kind == CXL_PKT_KIND_MEM_WR:
        msg = UCIE_MSG_MEM_WR_DATA if code == CXL_MEM_OP_WR_DATA else UCIE_MSG_MEM_WR
        return with_checksum(pack_ucie_ad_req(msg, tag, addr, ln, id_, attr))
    elif kind == CXL_PKT_KIND_CACHE_RD:
        msg = UCIE_MSG_CACHE_RD_DATA if code == CXL_CACHE_OP_RD_DATA else UCIE_MSG_CACHE_RD
        return with_checksum(pack_ucie_ad_req(msg, tag, addr, ln, id_, attr))
    elif kind == CXL_PKT_KIND_CACHE_WR:
        msg = UCIE_MSG_CACHE_WR_DATA if code == CXL_CACHE_OP_WR_DATA else UCIE_MSG_CACHE_WR
        return with_checksum(pack_ucie_ad_req(msg, tag, addr, ln, id_, attr))
    else:
        raw = (UCIE_PKT_KIND_ERROR << 60) | (tag << 48) | (id_ << 16)
        return with_checksum(raw)


def expect_cxl_from_ucie(ucie_pkt):
    """Expected CXL output for a given UCIe input packet (with valid checksum)."""
    kind = _get_field(ucie_pkt, PKT_KIND_MSB, PKT_KIND_LSB)
    code = _get_field(ucie_pkt, PKT_CODE_MSB, PKT_CODE_LSB)
    tag  = _get_field(ucie_pkt, PKT_TAG_MSB,  PKT_TAG_LSB)
    addr = _get_field(ucie_pkt, PKT_ADDR_MSB, PKT_ADDR_LSB)
    ln   = _get_field(ucie_pkt, PKT_LEN_MSB,  PKT_LEN_LSB)
    id_  = _get_field(ucie_pkt, PKT_ID_MSB,   PKT_ID_LSB)
    aux  = _get_field(ucie_pkt, PKT_AUX_MSB,  PKT_AUX_LSB)
    misc = _get_field(ucie_pkt, PKT_MISC_MSB, PKT_MISC_LSB)

    valid_chk = bridge_checksum(ucie_pkt & ~0xFF) == misc
    invalid   = _pack64(CXL_PKT_KIND_INVALID, 0, tag, 0, 0, id_, 0, 0)

    if kind == UCIE_PKT_KIND_AD_CPL:
        return pack_cxl_io_cpl(code, tag, addr, ln, id_, aux) if valid_chk else invalid
    elif kind == UCIE_PKT_KIND_MEM_CPL:
        return pack_cxl_mem_cpl(code, tag, addr, ln, id_, aux) if valid_chk else invalid
    elif kind == UCIE_PKT_KIND_CACHE_CPL:
        return pack_cxl_cache_cpl(code, tag, addr, ln, id_, aux) if valid_chk else invalid
    else:
        return invalid


# ---- Reset ----

async def reset_dut(dut, clk, ucie_clk):
    """Assert rst_n=0 for 6 clk cycles, release with link_up=1, settle both domains."""
    dut.rst_n.value          = 0
    dut.link_up.value        = 0
    dut.err_inj_en.value     = 0
    dut.cxl_in_valid.value   = 0
    dut.cxl_in_data.value    = 0
    dut.ucie_out_ready.value = 0
    dut.ucie_in_valid.value  = 0
    dut.ucie_in_data.value   = 0
    dut.cxl_out_ready.value  = 0

    for _ in range(6):
        await RisingEdge(clk)

    dut.rst_n.value   = 1
    dut.link_up.value = 1

    for _ in range(4):
        await RisingEdge(clk)
    for _ in range(4):
        await RisingEdge(ucie_clk)


# ---- CXL-domain driver ----

class CXLDriver:
    """Drives cxl_in_* and reads cxl_out_* on the CXL (clk) domain."""

    def __init__(self, dut, clk):
        self.dut = dut
        self.clk = clk

    async def send(self, pkt, timeout=64):
        """Drive cxl_in_valid/data and wait for cxl_in_ready handshake."""
        dut = self.dut
        clk = self.clk
        dut.cxl_in_data.value  = pkt
        dut.cxl_in_valid.value = 1
        for _ in range(timeout):
            await RisingEdge(clk)
            if int(dut.cxl_in_ready.value) == 1:
                dut.cxl_in_valid.value = 0
                return
        raise AssertionError(f"Timeout on cxl_in handshake (pkt=0x{pkt:016x})")

    async def recv(self, timeout=64):
        """Wait for cxl_out_valid and consume one packet on the clk domain."""
        dut = self.dut
        clk = self.clk
        dut.cxl_out_ready.value = 1
        for _ in range(timeout):
            await RisingEdge(clk)
            if int(dut.cxl_out_valid.value) == 1:
                data = int(dut.cxl_out_data.value)
                dut.cxl_out_ready.value = 0
                return data
        raise AssertionError("Timeout waiting for cxl_out_valid")


# ---- UCIe-domain driver ----

class UCIeDriver:
    """Drives ucie_in_* and reads ucie_out_* on the UCIe (ucie_clk) domain."""

    def __init__(self, dut, ucie_clk):
        self.dut      = dut
        self.ucie_clk = ucie_clk

    async def send(self, pkt, timeout=64):
        """Drive ucie_in_valid/data and wait for ucie_in_ready handshake."""
        dut = self.dut
        clk = self.ucie_clk
        dut.ucie_in_data.value  = pkt
        dut.ucie_in_valid.value = 1
        for _ in range(timeout):
            await RisingEdge(clk)
            if int(dut.ucie_in_ready.value) == 1:
                dut.ucie_in_valid.value = 0
                return
        raise AssertionError(f"Timeout on ucie_in handshake (pkt=0x{pkt:016x})")

    async def recv(self, timeout=64):
        """Wait for ucie_out_valid and consume one packet on the ucie_clk domain."""
        dut = self.dut
        clk = self.ucie_clk
        dut.ucie_out_ready.value = 1
        for _ in range(timeout):
            await RisingEdge(clk)
            if int(dut.ucie_out_valid.value) == 1:
                data = int(dut.ucie_out_data.value)
                dut.ucie_out_ready.value = 0
                return data
        raise AssertionError("Timeout waiting for ucie_out_valid")
