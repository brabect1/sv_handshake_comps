package test_pkg;

    typedef enum bit {
        FALL,
        RISE
    } t_change;


    function void header(
            input  string label,
            input  byte char = "-"
        );
        localparam int len = 30;
        $display("\n%0s\n%0s %0s\n%0s", {len{char}}, {2{char}}, label, {len{char}});
    endfunction: header


    // Xilinx Vivado simulator seems to have problem with `function automatic`
    function bit check(
            input string name,
            input logic sig,
            input logic val,
            input bit report_on = 1
        );
        bit pass;
        pass = (sig === val);
        if (report_on) begin
            if (pass) begin
                $display("%0t: %0s value check: exp=%0b, act=%0b", $realtime, name, val, sig);
            end
            else begin
                $error("%0t: %0s value check: exp=%0b, act=%0b", $realtime, name, val, sig);
            end
        end
        return pass;
    endfunction: check

    // blocking
    task automatic drive(
            input  string name,
            output logic sig,
            input  logic val,
            input  realtime delay = 0ns,
            input  bit report_on = 1
        );
        if (delay > 0ns) begin
            #(delay);
        end
        sig = val;
        if (report_on) begin
            $display("%0t: Set: %0s=%0b (act=%0b)", $realtime, name, val, sig);
        end
    endtask: drive


    // non-blocking
    task automatic drive_nb(
            input  string name,
            output logic sig,
            input  logic val,
            input  realtime delay = 0ns,
            input  bit report_on = 1
        );
        if (delay > 0ns) begin
            fork begin
                #(delay);
                sig = val;
                if (report_on) begin
                    $display("%0t: Set: %0s=%0b (act=%0b)", $realtime, name, val, sig);
                end
            end join
        end
        else begin
            sig = val;
            if (report_on) begin
                $display("%0t: Set: %0s=%0b (act=%0b)", $realtime, name, val, sig);
            end
        end
    endtask: drive_nb


//    task automatic wait_for_value (
//            input string name,
//            input logic sig,
//            input logic val,
//            output bit err,
//            input realtime tout = 0ns,
//            input bit report_on = 1
//        );
//
//        if (sig === val) begin
//            if (report_on) $display("%0t: %0s already at '%0b'.", $realtime, name, val);
//            err = 0;
//        end
//        else begin
//            realtime tstamp;
//
//            tstamp = $realtime;
//            fork
//                @(sig iff sig === val);
//                if (tout > 0) #(tout);
//                else wait(0);
//            join_any
//            disable fork;
//            err = (sig !== val);
//            if (report_on) begin
//                if ((tstamp + tout) >= $realtime) begin
//                    $error("%0t: Timed out waiting on %0s = %0b: act=%0b", $realtime, name, val, sig);
//                end
//                else if (err) begin
//                    $error("%0t: %0s not got to %0b: act=%0b", $realtime, name, val, sig);
//                end
//                else begin
//                    $display("$0t: %0s got to %0b: act=%0b.", $realtime, name, val, sig);
//                end
//            end
//        end
//    endtask: wait_for_value

endpackage: test_pkg
