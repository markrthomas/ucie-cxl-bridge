"""
cocotb tests for cxl_ucie_bridge.

Mirrors the directed test scenarios from tb_cxl_ucie_bridge.v:
  Smoke 1  — CXL.io IO_REQ (MEM_RD) → UCIe AD_REQ, then UCIe AD_CPL → CXL IO_CPL
  Smoke 2  — all new packet kinds: MEM_RD, MEM_WR, CACHE_RD, CACHE_WR, MEM_CPL, CACHE_CPL

The gold model (expect_ucie_from_cxl / expect_cxl_from_ucie) in env.py is a pure
Python port of the translate_* functions in the bridge RTL.
"""

import cocotb
from cocotb.clock import Clock

from env import (
    CXLDriver, UCIeDriver, reset_dut,
    # Packet helpers
    pack_cxl_io_req, pack_cxl_mem_rd, pack_cxl_mem_wr,
    pack_cxl_cache_rd, pack_cxl_cache_wr,
    pack_ucie_ad_cpl, pack_ucie_mem_cpl, pack_ucie_cache_cpl,
    # Opcodes / constants
    CXL_IO_OP_MEM_RD, CXL_MEM_OP_WR, CXL_MEM_OP_RD, CXL_CACHE_OP_RD, CXL_CACHE_OP_WR,
    UCIE_CPL_SC, UCIE_CPL_UR, UCIE_CPL_CA,
    # Gold models
    expect_ucie_from_cxl, expect_cxl_from_ucie, with_checksum,
)

# Both clocks 100 MHz (10 ns) for 1:1 ratio matching the first TB phase.
CXL_CLK_NS  = 10
UCIE_CLK_NS = 10


def _start_clocks(dut):
    cocotb.start_soon(Clock(dut.clk,      CXL_CLK_NS,  units="ns").start())
    cocotb.start_soon(Clock(dut.ucie_clk, UCIE_CLK_NS, units="ns").start())


@cocotb.test()
async def test_c2u_io_req(dut):
    """CXL.io IO_REQ (MEM_RD) is translated to UCIe AD_REQ(MEM) with correct checksum."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = pack_cxl_io_req(CXL_IO_OP_MEM_RD, 0x3C, 0xBEEF, 0x04, 0xA1, 0x0F)
    await cxl.send(pkt)
    got = await ucie.recv()

    exp = expect_ucie_from_cxl(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_u2c_ad_cpl(dut):
    """UCIe AD_CPL is translated to CXL IO_CPL on the clk-domain output."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = with_checksum(pack_ucie_ad_cpl(UCIE_CPL_SC, 0x5A, 0x0040, 0x04, 0xC3, 0x18))
    await ucie.send(pkt)
    got = await cxl.recv()

    exp = expect_cxl_from_ucie(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_c2u_mem_rd(dut):
    """CXL.mem MEM_RD is translated to UCIe AD_REQ(MEM_RD)."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = pack_cxl_mem_rd(CXL_MEM_OP_RD, 0x11, 0x2000, 0x08, 0xD4, 0xF5)
    await cxl.send(pkt)
    got = await ucie.recv()

    exp = expect_ucie_from_cxl(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_c2u_mem_wr(dut):
    """CXL.mem MEM_WR (posted) is translated to UCIe AD_REQ(MEM_WR)."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = pack_cxl_mem_wr(CXL_MEM_OP_WR, 0x22, 0x4000, 0x04, 0xE5, 0xA3)
    await cxl.send(pkt)
    got = await ucie.recv()

    exp = expect_ucie_from_cxl(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_c2u_cache_rd(dut):
    """CXL.cache CACHE_RD is translated to UCIe AD_REQ(CACHE_RD)."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = pack_cxl_cache_rd(CXL_CACHE_OP_RD, 0x33, 0x8000, 0x02, 0xF6, 0x77)
    await cxl.send(pkt)
    got = await ucie.recv()

    exp = expect_ucie_from_cxl(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_c2u_cache_wr(dut):
    """CXL.cache CACHE_WR (posted) is translated to UCIe AD_REQ(CACHE_WR)."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = pack_cxl_cache_wr(CXL_CACHE_OP_WR, 0x44, 0xC000, 0x01, 0xA7, 0x5B)
    await cxl.send(pkt)
    got = await ucie.recv()

    exp = expect_ucie_from_cxl(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_u2c_mem_cpl(dut):
    """UCIe MEM_CPL is translated to CXL MEM_CPL."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = with_checksum(pack_ucie_mem_cpl(UCIE_CPL_SC, 0x11, 0x0800, 0x08, 0xD4, 0xF5))
    await ucie.send(pkt)
    got = await cxl.recv()

    exp = expect_cxl_from_ucie(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_u2c_cache_cpl(dut):
    """UCIe CACHE_CPL (UR status) is translated to CXL CACHE_CPL."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = with_checksum(pack_ucie_cache_cpl(UCIE_CPL_UR, 0x33, 0x0200, 0x02, 0xF6, 0x77))
    await ucie.send(pkt)
    got = await cxl.recv()

    exp = expect_cxl_from_ucie(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"


@cocotb.test()
async def test_u2c_ad_cpl_ca(dut):
    """UCIe AD_CPL with CA (Completer Abort) status is translated to CXL IO_CPL(CA)."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = with_checksum(pack_ucie_ad_cpl(UCIE_CPL_CA, 0x5A, 0x0040, 0x04, 0xC3, 0x18))
    await ucie.send(pkt)
    got = await cxl.recv()

    exp = expect_cxl_from_ucie(pkt)
    assert got == exp, f"Expected 0x{exp:016x}, got 0x{got:016x}"
