#include "tb_wrap.h"
#include <vector>
#include <iostream>

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
    int i;
    int tout = 12; // timeout in cycles (pipeline depth + some margin)
    std::vector<int> exp;
    rst_n = false;
    pull_rdy = false;
    push_rdy = false;

    wait(3);
    rst_n = true;

    // 1st data feed
    wait();
    exp.push_back( (unsigned int)0x55aa8118 );
    pull_dat = exp[exp.size()-1];
    pull_rdy = true;
    std::cout << "Sending: " << std::hex << exp[exp.size()-1] << std::endl;
    while (1) {
        wait();
        if (pull_pop) {
            pull_rdy = false;
            pull_dat = 0;
            break;
        }
    }

    // 2nd data feed
    wait();
    exp.push_back( (unsigned int)0xdeadbeef );
    pull_dat = exp[exp.size()-1];
    pull_rdy = true;
    std::cout << "Sending: " << std::hex << exp[exp.size()-1] << std::endl;
    while (1) {
        wait();
        if (pull_pop) {
            pull_rdy = false;
            pull_dat = 0;
            break;
        }
    }

    // 3rd data feed
    // (Notice we don't synchronize to clock edge this time.)
    exp.push_back( (unsigned int)0xffffffff );
    pull_dat = exp[exp.size()-1];
    pull_rdy = true;
    std::cout << "Sending: " << std::hex << exp[exp.size()-1] << std::endl;
    while (1) {
        wait();
        if (pull_pop) {
            pull_rdy = false;
            pull_dat = 0;
            break;
        }
    }

    // indicate the output side is ready
    push_rdy = true;

    // wait for the data and check we got it all
    for (std::vector<int>::iterator it = exp.begin(); it != exp.end(); it++) {
        i = 0;
        while(1) {
            wait();
            if (push_push) {
                cout << "Received: " << push_dat << endl;
                if (push_dat != *it) {
                    cout << "ERROR: Data mismatch!" << endl;
                }
                break;
            }
            if (i++ > tout) {
                cout << "ERROR: No data received in " << i << " cycles!" << endl;
                break;
            }
        }
    }

    // for the rest of the test expect no more data
    while (1) {
        wait();
        if (push_push) {
            std::cout << "ERROR: New data signalled but none expected!" << std::endl;
            break;
        }
    }
}

