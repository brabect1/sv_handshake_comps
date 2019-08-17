
#include "tb_wrap.h"
#include "defs.h"
#include "VerilatorScTracer.h"

int sc_main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    sc_clock clk ("clk", 10, SC_NS, 0.5, 3, SC_NS);
    sc_signal<bool> rst_n;
    sc_signal<bool> pull_rdy, pull_pop, push_rdy, push_push;
    sc_signal<unsigned int> pull_dat, push_dat;
    t_dut* dut;
    tb_wrap tb("tb");

    dut = new t_dut("top");
    dut->pull_rdy(pull_rdy);
    dut->pull_pop(pull_pop);
    dut->pull_dat(pull_dat);
    dut->push_rdy(push_rdy);
    dut->push_push(push_push);
    dut->push_dat(push_dat);
    dut->clk(clk);
    dut->rst_n(rst_n);

    tb.clk(clk);
    tb.rst_n(rst_n);
    tb.pull_rdy(pull_rdy);
    tb.pull_pop(pull_pop);
    tb.pull_dat(pull_dat);
    tb.push_rdy(push_rdy);
    tb.push_push(push_push);
    tb.push_dat(push_dat);

    VerilatorScTracer tracer("tracer", dut, "dump.vcd");
    tracer.dumpEvent(clk);

    //Run the Simulation for "200 nanosecnds"
    std::cout << "-- started" << std::endl;
    sc_start(300,SC_NS);
    std::cout << "-- finished" << std::endl;

    delete dut;
    return(0);
}
