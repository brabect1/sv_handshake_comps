module tb_rdyval2reqack_tph #(
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

logic rdy;
logic vld;
logic [DWIDTH-1:0] i_dat;

logic req;
logic ack;
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


rdyval2reqack_tph #(
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
    bit ign;
    $timeformat(-9, 5, " ns", 10);

    // start of the test
    test_done = 1'b0;
    vld = 1'b0;
    ack = 1'b0;

    // Assert reset
    // ------------
    rst_n = 1'b0;
    $display("%0t: Setting rst_n=%0b", $realtime, rst_n);
    repeat (2) @(posedge clk);

    // check expected outputs
    ign = test_pkg::check( "rdy", rdy, 1'b1);
    ign = test_pkg::check( "req", req, 1'b0);

    // Remove reset
    // ------------
    #(HOLD_TIME);
    rst_n = 1'b1;
    $display("%0t: Setting rst_n=%0b", $realtime, rst_n);
    repeat (2) @(posedge clk);

    // check expected outputs
    ign = test_pkg::check( "rdy", rdy, 1'b1);
    ign = test_pkg::check( "req", req, 1'b0);

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
        test_pkg::drive("vld", vld, 1'b1);

        // check RDY and REQ response
        begin
            repeat(1) @(posedge clk);
            tstamp = $realtime;
            fork
                begin
                    #(CTO_TIME);
                    ign = test_pkg::check("rdy", rdy, 1'b0);
                    ign = test_pkg::check("req", req, ~ack);
                    ign = check_data("o_dat", o_dat, data);
                end
                begin
                    #(HOLD_TIME);
                    test_pkg::drive("vld", vld, 1'b0);
                end
            join
        end

        // complete the handshake on the output side
        // (as we keep RDY asserted, VAL shall de-assert one clock later)
        if (req !== ack) begin
            test_pkg::drive("ack", ack, ~ack);
            @(posedge clk);
            #(CTO_TIME);
            ign = test_pkg::check("req", req, ack);
            ign = test_pkg::check("rdy", rdy, 1'b1);
        end

    end


    // Testcase: tc_delayed_responses
    // ------------------------------
    // In this test case we control each side of DUT independently.
    test_pkg::header( "tc_delayed_responses" );
    fork
        semaphore smScoreBoard = new(1);
        logic[DWIDTH-1:0] scoreBoard[$];
        bit input_done = 1'b0;

        // input side (generates data and requests its passing to
        // the other side)
        begin
            int ticks;
            logic[DWIDTH-1:0] data;
            bit err;
            realtime tstamp;

            // make sure the input side is ready
            assert( test_pkg::check( "rdy", rdy, 1'b1 ) );
            @(posedge clk);
            #(HOLD_TIME);

            for (int i=0; i < 10; i++) begin
                // randomize next valid time
                assert( std::randomize( ticks, data ) with { ticks inside{[0:3]}; } );
                smScoreBoard.get();
                scoreBoard.push_back(data);
                smScoreBoard.put();

                // drive new data
                if (ticks > 0) begin
                    repeat(ticks) @(posedge clk);
                    #(HOLD_TIME);
                end
                drive_data("i_dat", i_dat, data);
                test_pkg::drive("vld", vld, 1'b1);

                // wait for RDY response
                @(posedge clk);
                tstamp = $realtime;
                fork
                    begin
                        #(HOLD_TIME);
                        drive_data("i_dat", i_dat, ~data);
                        test_pkg::drive("vld", vld, 1'b0);
                    end
                join_none
                #(CTO_TIME);

                // wait for next RDY
                err = 0;
                fork
                    if (rdy !== 1'b1) @(rdy iff rdy === 1'b1);
                    begin
                        #(10*CLK_PERIOD);
                        err = 1;
                    end
                join_any
                disable fork;
                ign = test_pkg::check( "rdy", rdy, 1'b1);
                if (err) break;

                // wait long enough so that potential VLD assertion
                // cannot violate timing requirements
                tstamp = HOLD_TIME - ($realtime - tstamp);
                if (tstamp > 0ns) #(tstamp);
            end

            input_done = 1'b1;
        end

        // output side (reacts to new request and acknowledges in a random number
        // of cycles)
        begin
            int ticks;
            logic[DWIDTH-1:0] data;
            bit err;
            int i;

            while (!input_done) begin
                // wait for next request on the output
                err = 0;
                fork
                    @(req iff req === ~ack or posedge input_done);
                    begin
                        #(10*CLK_PERIOD);
                        err = 1;
                    end
                join_any
                disable fork;
                if (input_done) break;
                ign = test_pkg::check( "req", req, ~ack );
                if (err) break;

                // check data
                smScoreBoard.get();
                if (scoreBoard.size() == 0) begin
                    $error("%0t: Output side signalled new request but no data expected!", $realtime);
                end
                else begin
                    data = scoreBoard.pop_front();
                    ign = check_data("o_dat", o_dat, data);
                end
                smScoreBoard.put();

                // respond with acknowledge
                assert( std::randomize( ticks ) with { ticks inside{[0:3]}; } );
                if (ticks > 0) begin
                    repeat(ticks) @(posedge clk);
                    #(HOLD_TIME);
                end
                test_pkg::drive("ack", ack, req);
            end

            // check we received all generated data
            smScoreBoard.get();
            if (scoreBoard.size() > 0) begin
                $error("%0t: Output side missed %0d data records!", $realtime, scoreBoard.size());
            end
            smScoreBoard.put();
        end
    join


    // Testcase: tc_reset (Reset test)
    // -------------------------------
    repeat(10) @(posedge clk);
    test_pkg::header( "tc_reset" );

    // make `rdy` and `req` outputs change to a non-reset value
    if (req !== 1'b1) begin
        @(posedge clk);
        #(HOLD_TIME);
        test_pkg::drive("vld", vld, 1'b1);

        repeat(1) @(posedge clk);
        fork
            #(CTO_TIME);
            begin
                test_pkg::drive("vld", vld, 1'b0);
            end
        join
    end
    ign = test_pkg::check("rdy", rdy, 1'b0);
    ign = test_pkg::check("req", req, 1'b1);

    // stop clocks
    test_done = 1'b1;
    #(4*CLK_PERIOD);

    // assert reset
    rst_n = 1'b0;
    $display("%0t: Setting rst_n=%0b", $realtime, rst_n);
    #(CTO_TIME);

    // check outputs changed to reset value
    ign = test_pkg::check("rdy", rdy, 1'b1);
    ign = test_pkg::check("req", req, 1'b0);

    // end of the test
    #(CLK_PERIOD);
    test_done = 1'b1;
   $display("============\nTest finished\n============");
end: p_test

endmodule: tb_rdyval2reqack_tph
