#ifndef __verilatorsctracer_h
#define __verilatorsctracer_h

#include "systemc.h"
#include "defs.h"

#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_c.h>
#endif

class VerilatorScTracer : public sc_core::sc_module {

public:
    VerilatorScTracer(
            sc_core::sc_module_name name,
            t_dut* dut,
            std::string path
            );

    ~VerilatorScTracer();

    void dump();

    // Event on this input makes the tracer dump the actual state.
    // Normally you will bind this input to a clock signal.
    sc_in<bool> dumpEvent;

protected:
    t_dut* dut;

#if VM_TRACE
    VerilatedVcdC* tfp;
#endif

};

#endif // __verilatorsctracer_h
