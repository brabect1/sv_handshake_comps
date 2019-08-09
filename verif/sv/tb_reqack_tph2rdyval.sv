module tb_reqack_tph2rdyval #(
    // Data path bit width
    parameter int DWIDTH = 1,
    // When set, CDC flops will be instantiated on the previous stage handshake
    // interface (i.e. Request input).
    parameter bit INCLUDE_CDC = 1'b0,
    // Clock period.
    parameter realtime CLK_PERIOD = 10ns,
    // Time after clock rise when to change DUT inputs.
    parameter realtime HOLD_TIME  = CLK_PERIOD/10,
    // Max time after clock rise when to expect vldid DUT outputs.
    parameter realtime CTO_TIME = CLK_PERIOD/5
);

bit test_done = 1'b1;
logic rst_n;
logic clk = 1'b0;

logic req;
logic ack;
logic [DWIDTH-1:0] i_dat;

logic rdy;
logic vld;
logic [DWIDTH-1:0] o_dat;


task drive_data(
        input  string name,
        output logic[DWIDTH-1:0] sig,
        input  logic[DWIDTH-1:0] val,
        input  realtime delay = 0ns,
        input  bit report_on = 1
    );
    if (delay > 0ns) begin
        #(delay);
    end
    sig = val;
    if (report_on) begin
        $display("%0t: Set: %0s=%0hh (act=%0hh)", $realtime, name, val, sig);
    end
endtask: drive_data


function automatic bit check_data(
        input string name,
        input logic[DWIDTH-1:0] sig,
        input logic[DWIDTH-1:0] val,
        input bit report_on = 1
    );
    bit pass;
    pass = (sig === val);
    if (report_on) begin
        if (pass) begin
            $display("%0t: %0s value check: exp=%0hh, act=%0hh", $realtime, name, val, sig);
        end
        else begin
            $error("%0t: %0s value check: exp=%0hh, act=%0hh", $realtime, name, val, sig);
        end
    end
    return pass;
endfunction: check_data


reqack_tph2rdyval #(
    .DWIDTH(DWIDTH),
    .INCLUDE_CDC(INCLUDE_CDC)
) dut ( .* );


// Clock generator (active only when not `test_done`)
always begin: p_clk_gen
    @(negedge test_done);
    clk = 1'b0;
    while (!test_done) begin
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
        clk = 1'b0;
    end
end: p_clk_gen


// Test
initial begin: p_test
    bit err;
    $timeformat(-9, 5, " ns", 10);

    // start of the test
    test_done = 1'b0;
    req = 1'b0;
    rdy = 1'b1;

    // Assert reset
    // ------------
    rst_n = 1'b0;
    $display("%0t: Setting rst_n=%0b", $realtime, rst_n);
    repeat (2) @(posedge clk);

    // check expected outputs
    err = test_pkg::check( "ack", ack, 1'b0);
    err = test_pkg::check("vld", vld, 1'b0);

    // Remove reset
    // ------------
    #(HOLD_TIME);
    rst_n = 1'b1;
    $display("%0t: Setting rst_n=%0b", $realtime, rst_n);
    repeat (2) @(posedge clk);

    // check expected outputs
    err = test_pkg::check( "ack", ack, 1'b0);
    err = test_pkg::check("vld", vld, 1'b0);

    // Testcase: tc_handshake
    // ----------------------
    // In this test case we do handshake on the input interface,
    // then complete the handshake on the output interface. This
    // way we know that after test case completion DUT shall be
    // ready to accept new data.
    for (int i=0; i < 10; i++) begin
        logic[DWIDTH-1:0] data;
        realtime tstamp;

        // Handshake new data
        // ------------------
        test_pkg::header( $sformatf("tc_handshake (i=%0d)",i) );
        @(posedge clk);
        #(HOLD_TIME);
        assert( std::randomize( data ) );
        drive_data("i_dat", i_dat, data);
        test_pkg::drive("req", req, ~req);
        drive_data("rdy", rdy, 1'b1);

        // check ACK and VAL response
        begin
            repeat(1) @(posedge clk);
            tstamp = $realtime;
            #(CTO_TIME);
            test_pkg::check("ack", ack, req);
            test_pkg::check("vld", vld, 1'b1);
            check_data("o_dat", o_dat, data);
        end

        // complete the handshake on the output side
        // (as we keep RDY asserted, VAL shall de-assert one clock later)
        if (vld === 1'b1) begin
            @(posedge clk);
            #(CTO_TIME);
            test_pkg::check("vld", vld, 1'b0);
        end

    end

    // end of the test
    test_done = 1'b1;
   $display("============\nTest finished\n============");
end: p_test

endmodule: tb_reqack_tph2rdyval
