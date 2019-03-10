#ifndef __tb_wrap_h
#define __tb_wrap_h

#include "systemc.h"

class tb_wrap : public sc_core::sc_module {

public:
    sc_in<bool> clk;
    sc_out<bool> rst_n;
    sc_out<bool> pull_rdy;
    sc_in<bool> pull_pop;
    sc_out<unsigned int> pull_dat;
    sc_out<bool> push_rdy;
    sc_in<bool> push_push;
    sc_in<unsigned int> push_dat;

    void run();

    tb_wrap(
            sc_core::sc_module_name name
           );
//    SC_CTOR(tb_wrap) {
//        SC_THREAD(run);
//        sensitive << clk.pos();
//    }
};

#endif // __tb_wrap_h
