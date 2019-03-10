/*
Copyright 2019 Tomas Brabec

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Changelog:

  2019, Mar, Tomas Brabec
  - Created.

*/


/**
* Implements a pipeline stage for the ready--valid handshake protocol.
*/
module rdyval_pipe_stage #(
    parameter int DWIDTH = 1
) (
    input  logic vld,
    output logic rdy,
    input  logic [DWIDTH-1:0] i_dat,

    output logic vld_nxt,
    input  logic rdy_nxt,
    output logic [DWIDTH-1:0] o_dat,

    // rising edge active clock
    input  logic clk,
    // asynchronous reset, active low
    input  logic rst_n
);

// Implements the handshake signalling. Notice that the `rdy` flag is just
// an inverted version of `vld_nxt`. It is assumed the implementation tools
// will optimize this per available resources.
always_ff @(posedge clk or negedge rst_n) begin: p_handshake
    if (!rst_n) begin
        rdy     <= 1'b1;
        vld_nxt <= 1'b0;
    end
    else begin
        if (vld & ~vld_nxt) begin
            rdy     <= 1'b0;
            vld_nxt <= 1'b1;
        end
        else if (vld_nxt & rdy_nxt) begin
            rdy     <= 1'b1;
            vld_nxt <= 1'b0;
        end
    end
end: p_handshake

// Implements the data buffer flop. It is factored into a separate process as
// we do not need to have the reset for data path flops.
always_ff @(posedge clk) begin: p_data
    if (vld & ~vld_nxt)
        o_dat <= i_dat;
end: p_data

endmodule: rdyval_pipe_stage
