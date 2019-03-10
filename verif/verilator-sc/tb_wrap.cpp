#include "tb_wrap.h"

SC_HAS_PROCESS( tb_wrap );

tb_wrap::tb_wrap(
        sc_core::sc_module_name name
        ) :
    sc_module(name)
{
    SC_THREAD(run);
    sensitive << clk.pos();
}

void tb_wrap::run() {
    rst_n = false;
    pull_rdy = false;
    push_rdy = false;

    wait(3);
    rst_n = true;

    wait();

    pull_dat = (unsigned int)0x55aa8118;
    pull_rdy = true;
    while (1) {
        wait();
        if (pull_pop) {
            pull_rdy = false;
            pull_dat = 0;
            break;
        }
    }

    wait();
    pull_dat = (unsigned int)0xdeadbeef;
    pull_rdy = true;
    while (1) {
        wait();
        if (pull_pop) {
            pull_rdy = false;
            pull_dat = 0;
            break;
        }
    }

    pull_dat = (unsigned int)0xffffffff;
    pull_rdy = true;
    while (1) {
        wait();
        if (pull_pop) {
            pull_rdy = false;
            pull_dat = 0;
            break;
        }
    }
}

