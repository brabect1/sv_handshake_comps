#include "VerilatorScTracer.h"

SC_HAS_PROCESS(VerilatorScTracer);

VerilatorScTracer::VerilatorScTracer(
            sc_core::sc_module_name name,
            t_dut* dut,
            std::string path
        ) :
    tfp(NULL),
    dut(dut),
    sc_module(name)
{
#if VM_TRACE
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace (tfp, 99);
    tfp->open (path.c_str());
#endif
    SC_METHOD(dump);
    sensitive << dumpEvent;
}


VerilatorScTracer::~VerilatorScTracer() {
#if VM_TRACE
    if (tfp != NULL) {
        tfp->close();
        delete tfp;
    }
#endif
}


void VerilatorScTracer::dump() {
#if VM_TRACE
    if (tfp != NULL) {
        sc_core::sc_time t;
        t = sc_time_stamp();
        tfp->dump(t.to_double());
        //tfp->dump(1);
    }
#endif
}

