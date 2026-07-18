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
from cocotb.triggers import Timer

import random

from env import (
    CXLDriver, UCIeDriver, reset_dut,
    # Packet helpers
    pack_cxl_io_req, pack_cxl_mem_rd, pack_cxl_mem_wr,
    pack_cxl_cache_rd, pack_cxl_cache_wr,
    pack_ucie_ad_cpl, pack_ucie_mem_cpl, pack_ucie_cache_cpl,
    # Opcodes / constants
    CXL_IO_OP_CFG_RD, CXL_IO_OP_CFG_WR, CXL_IO_OP_MEM_RD, CXL_IO_OP_MEM_WR,
    CXL_MEM_OP_WR, CXL_MEM_OP_RD, CXL_CACHE_OP_RD, CXL_CACHE_OP_WR,
    UCIE_CPL_SC, UCIE_CPL_UR, UCIE_CPL_CA,
    # Gold models + payload-length helpers
    expect_ucie_from_cxl, expect_cxl_from_ucie, with_checksum,
    c2u_payload_len, u2c_payload_len,
)

# Both clocks 100 MHz (10 ns) for 1:1 ratio matching the first TB phase.
CXL_CLK_NS  = 10
UCIE_CLK_NS = 10


def _start_clocks(dut):
    # Phase-shift ucie_clk so it never rises on the same simulation timestamp as
    # clk. With both clocks aligned, the async-FIFO Gray-pointer CDC syncs race
    # in delta cycles and can intermittently stall (matches the 2.5 ns skew the
    # directed Verilog testbench uses for the same reason).
    cocotb.start_soon(Clock(dut.clk, CXL_CLK_NS, units="ns").start())

    async def _delayed_ucie():
        await Timer(UCIE_CLK_NS * 250, units="ps")   # quarter-period skew
        cocotb.start_soon(Clock(dut.ucie_clk, UCIE_CLK_NS, units="ns").start())

    cocotb.start_soon(_delayed_ucie())


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


@cocotb.test()
async def test_c2u_mem_wr_payload(dut):
    """A 4-beat MEM_WR payload burst reaches UCIe egress intact and in order."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = pack_cxl_mem_wr(CXL_MEM_OP_WR, 0x55, 0x5000, 0x07, 0x55, 0x00)  # (7+1)/2 = 4 beats
    await cxl.send(pkt)
    got = await ucie.recv()

    exp = expect_ucie_from_cxl(pkt)
    assert got == exp, f"Header: expected 0x{exp:016x}, got 0x{got:016x}"
    assert len(ucie.last_payload) == 4, f"expected 4 payload beats, got {len(ucie.last_payload)}"
    assert ucie.last_payload == cxl.last_payload, \
        f"payload mismatch: sent {[hex(x) for x in cxl.last_payload]} got {[hex(x) for x in ucie.last_payload]}"


@cocotb.test()
async def test_u2c_mem_cpl_payload(dut):
    """A 4-beat SC MEM_CPL payload burst reaches CXL egress intact and in order."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)

    pkt = with_checksum(pack_ucie_mem_cpl(UCIE_CPL_SC, 0x66, 0x0600, 0x07, 0x66, 0x00))  # 4 beats
    await ucie.send(pkt)
    got = await cxl.recv()

    exp = expect_cxl_from_ucie(pkt)
    assert got == exp, f"Header: expected 0x{exp:016x}, got 0x{got:016x}"
    assert len(cxl.last_payload) == 4, f"expected 4 payload beats, got {len(cxl.last_payload)}"
    assert cxl.last_payload == ucie.last_payload, \
        f"payload mismatch: sent {[hex(x) for x in ucie.last_payload]} got {[hex(x) for x in cxl.last_payload]}"


# ---- Constrained-random regression with functional coverage ----

def _plbucket(n):
    if n == 0:
        return "z"
    if n == 1:
        return "1"
    if n <= 4:
        return "2-4"
    return "5+"


@cocotb.test()
async def test_random_traffic(dut):
    """Constrained-random legal traffic in both directions with payload beats,
    per-transaction translation + payload-content checks, and functional
    coverage closure (kind x direction x status x payload-length bucket)."""
    _start_clocks(dut)
    await reset_dut(dut, dut.clk, dut.ucie_clk)
    cxl  = CXLDriver(dut, dut.clk)
    ucie = UCIeDriver(dut, dut.ucie_clk)
    rng  = random.Random(0xC0FFEE)

    # (name, builder(tag, addr, len, id, aux) -> 64-bit CXL request)
    c2u_kinds = [
        ("io_cfg_rd", lambda t, a, l, i, x: pack_cxl_io_req(CXL_IO_OP_CFG_RD, t, a, l, i, x)),
        ("io_cfg_wr", lambda t, a, l, i, x: pack_cxl_io_req(CXL_IO_OP_CFG_WR, t, a, l, i, x)),
        ("io_mem_wr", lambda t, a, l, i, x: pack_cxl_io_req(CXL_IO_OP_MEM_WR, t, a, l, i, x)),
        ("mem_rd",    lambda t, a, l, i, x: pack_cxl_mem_rd(CXL_MEM_OP_RD, t, a, l, i, x)),
        ("mem_wr",    lambda t, a, l, i, x: pack_cxl_mem_wr(CXL_MEM_OP_WR, t, a, l, i, x)),
        ("cache_rd",  lambda t, a, l, i, x: pack_cxl_cache_rd(CXL_CACHE_OP_RD, t, a, l, i, x)),
        ("cache_wr",  lambda t, a, l, i, x: pack_cxl_cache_wr(CXL_CACHE_OP_WR, t, a, l, i, x)),
    ]
    u2c_kinds = [
        ("ad_cpl",    pack_ucie_ad_cpl),
        ("mem_cpl",   pack_ucie_mem_cpl),
        ("cache_cpl", pack_ucie_cache_cpl),
    ]
    statuses = [("sc", UCIE_CPL_SC), ("ur", UCIE_CPL_UR), ("ca", UCIE_CPL_CA)]

    cov = set()
    c2u_n = u2c_n = 0
    N = 240

    for _it in range(N):
        t = rng.randint(0, 255)
        a = rng.randint(0, 0xFFFF)
        i = rng.randint(0, 255)
        x = rng.randint(0, 255)
        l = rng.randint(0, 24)   # ceil(l/2) <= 12 payload beats (< FIFO depth 16)

        if rng.random() < 0.5:
            name, mk = rng.choice(c2u_kinds)
            pkt = mk(t, a, l, i, x)
            exp = expect_ucie_from_cxl(pkt)
            nb  = c2u_payload_len(pkt)
            await cxl.send(pkt)
            got = await ucie.recv(payload_beats=nb)
            assert got == exp, f"txn{_it} C2U {name}: exp {exp:016x} got {got:016x}"
            assert ucie.last_payload == cxl.last_payload, \
                f"txn{_it} C2U {name} payload mismatch: sent {cxl.last_payload} got {ucie.last_payload}"
            cov.add(("c2u", name, _plbucket(nb)))
            c2u_n += 1
        else:
            name, mk = rng.choice(u2c_kinds)
            sname, st = rng.choice(statuses)
            pkt = with_checksum(mk(st, t, a, l, i, x))
            exp = expect_cxl_from_ucie(pkt)
            nb  = u2c_payload_len(pkt)
            await ucie.send(pkt)
            got = await cxl.recv(payload_beats=nb)
            assert got == exp, f"txn{_it} U2C {name}/{sname}: exp {exp:016x} got {got:016x}"
            assert cxl.last_payload == ucie.last_payload, \
                f"txn{_it} U2C {name}/{sname} payload mismatch: sent {ucie.last_payload} got {cxl.last_payload}"
            cov.add(("u2c", name, sname, _plbucket(nb)))
            u2c_n += 1

    # ---- Functional coverage closure ----
    c2u_seen  = {c[1] for c in cov if c[0] == "c2u"}
    u2c_seen  = {c[1] for c in cov if c[0] == "u2c"}
    stat_seen = {c[2] for c in cov if c[0] == "u2c"}
    plb_seen  = {c[-1] for c in cov}

    dut._log.info(f"random: {c2u_n} C2U + {u2c_n} U2C txns; {len(cov)} coverage bins")
    dut._log.info(f"  c2u kinds={sorted(c2u_seen)}")
    dut._log.info(f"  u2c kinds={sorted(u2c_seen)} status={sorted(stat_seen)} plbuckets={sorted(plb_seen)}")

    assert c2u_seen == {"io_cfg_rd", "io_cfg_wr", "io_mem_wr", "mem_rd",
                        "mem_wr", "cache_rd", "cache_wr"}, f"c2u kind gap: {c2u_seen}"
    assert u2c_seen == {"ad_cpl", "mem_cpl", "cache_cpl"}, f"u2c kind gap: {u2c_seen}"
    assert stat_seen == {"sc", "ur", "ca"}, f"status gap: {stat_seen}"
    assert {"z", "1", "2-4", "5+"} <= plb_seen, f"payload-bucket gap: {plb_seen}"
