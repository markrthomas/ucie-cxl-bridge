// Verilator coverage harness for cxl_ucie_bridge (dual-clock: clk=10ns, ucie_clk=10ns).
// Exercises: CXL→UCIe and UCIe→CXL packet translation, error injection, link_up toggle.
#include "Vcxl_ucie_bridge.h"
#include "verilated.h"
#if VM_COVERAGE
#include "verilated_cov.h"
#endif
#include <cstdint>

static uint64_t g_time = 0;
double sc_time_stamp() { return (double)g_time; }

static Vcxl_ucie_bridge* top;

// Packet field encoding matching cxl_ucie_bridge_defs.vh.
// kind[63:60] | code[59:56] | tag[55:48] | addr[47:16] | ln[15:12] | id[11:8] | aux[7:0(chk)]
static uint64_t make_cxl_pkt(uint8_t kind, uint8_t code, uint8_t tag,
                               uint32_t addr, uint8_t ln = 0, uint8_t id = 0) {
    return ((uint64_t)(kind & 0xF) << 60) |
           ((uint64_t)(code & 0xF) << 56) |
           ((uint64_t)(tag  & 0xFF) << 48) |
           ((uint64_t)(addr & 0xFFFFFFFF) << 16) |
           ((uint64_t)(ln   & 0xF) << 12) |
           ((uint64_t)(id   & 0xF) << 8);
    // checksum byte [7:0] left at 0; bridge accepts any value on the CXL-in side
}

static uint64_t make_ucie_pkt(uint8_t kind, uint8_t opcode, uint8_t tag,
                                uint32_t addr, uint8_t misc = 0) {
    return ((uint64_t)(kind   & 0xF) << 60) |
           ((uint64_t)(opcode & 0xFF) << 52) |
           ((uint64_t)(tag    & 0xFF) << 44) |
           ((uint64_t)(addr   & 0xFFFFFFFF) << 12) |
           ((uint64_t)(misc   & 0xF) << 8);
}

// Advance N clk-domain cycles (both clocks toggle at the same rate here).
static void tick(int n = 1) {
    for (int i = 0; i < n; i++) {
        top->clk = 0; top->ucie_clk = 0; top->eval();
        top->clk = 1; top->ucie_clk = 1; top->eval();
        ++g_time;
    }
}

// Send one packet on CXL input; wait for ready.
static void send_cxl(uint64_t pkt) {
    top->cxl_in_valid = 1;
    top->cxl_in_data  = pkt;
    for (int i = 0; i < 64; i++) {
        top->clk = 0; top->ucie_clk = 0; top->eval();
        top->clk = 1; top->ucie_clk = 1; top->eval();
        ++g_time;
        if (top->cxl_in_ready) { top->cxl_in_valid = 0; break; }
    }
    tick(2);
}

// Send one packet on UCIe input; wait for ready.
static void send_ucie(uint64_t pkt) {
    top->ucie_in_valid = 1;
    top->ucie_in_data  = pkt;
    for (int i = 0; i < 64; i++) {
        top->clk = 0; top->ucie_clk = 0; top->eval();
        top->clk = 1; top->ucie_clk = 1; top->eval();
        ++g_time;
        if (top->ucie_in_ready) { top->ucie_in_valid = 0; break; }
    }
    tick(2);
}

// Drain UCIe output side for up to n cycles.
static void drain_ucie_out(int n = 32) {
    top->ucie_out_ready = 1;
    tick(n);
    top->ucie_out_ready = 0;
}

// Drain CXL output side for up to n cycles.
static void drain_cxl_out(int n = 32) {
    top->cxl_out_ready = 1;
    tick(n);
    top->cxl_out_ready = 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vcxl_ucie_bridge;

    // Initialize all inputs.
    top->clk = 0; top->ucie_clk = 0; top->rst_n = 0;
    top->cxl_in_valid  = 0; top->cxl_in_data   = 0;
    top->ucie_in_valid = 0; top->ucie_in_data   = 0;
    top->ucie_out_ready = 0; top->cxl_out_ready = 0;
    top->link_up  = 0;
    top->err_inj_en = 0;
    top->eval();

    // Reset: 8 cycles with rst_n=0.
    tick(8);
    top->rst_n   = 1;
    top->link_up = 1;
    tick(8);

    // --- CXL → UCIe direction ---
    // CXL_PKT_KIND_IO_REQ = 0x1, code 0x0 (IO read)
    send_cxl(make_cxl_pkt(0x1, 0x0, 0x10, 0x00001000));
    drain_ucie_out(32);

    // CXL_PKT_KIND_MEM_REQ = 0x2, code 0x0 (Mem read)
    send_cxl(make_cxl_pkt(0x2, 0x0, 0x20, 0x00002000));
    drain_ucie_out(32);

    // CXL_PKT_KIND_MEM_REQ = 0x2, code 0x1 (Mem write)
    send_cxl(make_cxl_pkt(0x2, 0x1, 0x30, 0x00003000));
    drain_ucie_out(32);

    // CXL_PKT_KIND_CACHE_REQ = 0x3, code 0x0 (Cache read)
    send_cxl(make_cxl_pkt(0x3, 0x0, 0x40, 0x00004000));
    drain_ucie_out(32);

    // CXL_PKT_KIND_CACHE_REQ = 0x3, code 0x1 (Cache write)
    send_cxl(make_cxl_pkt(0x3, 0x1, 0x50, 0x00005000));
    drain_ucie_out(32);

    // --- UCIe → CXL direction ---
    // UCIE_PKT_KIND_AD_CPL = 0x5, opcode 0x10 (completion)
    send_ucie(make_ucie_pkt(0x5, 0x10, 0x10, 0x00001000));
    drain_cxl_out(32);

    // UCIE_PKT_KIND_AD_CPL = 0x5, opcode 0x20 (MEM_CPL)
    send_ucie(make_ucie_pkt(0x5, 0x20, 0x20, 0x00002000));
    drain_cxl_out(32);

    // UCIE_PKT_KIND_AD_CPL = 0x5, opcode 0x30 (CACHE_CPL)
    send_ucie(make_ucie_pkt(0x5, 0x30, 0x40, 0x00004000));
    drain_cxl_out(32);

    // --- Error injection path ---
    top->err_inj_en = 1;
    send_cxl(make_cxl_pkt(0x2, 0x0, 0x60, 0x00006000));
    drain_ucie_out(16);
    top->err_inj_en = 0;

    // --- Link down / drain_done path ---
    top->link_up = 0;
    tick(16);
    top->link_up = 1;
    tick(8);

    // Settle.
    tick(16);

#if VM_COVERAGE
    VerilatedCov::write("coverage.dat");
#endif
    delete top;
    return 0;
}
