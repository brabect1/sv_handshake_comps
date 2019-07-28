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

  2019, Jul, Tomas Brabec
  - Created.

*/


/**
* Converts an input Ready--Valid handshake into an output, two phase (`*_tph`)
* Request--Acknowledge handshake.
*
* The conversion may be useful for handshaking data over a clock domain boundary.
* Clock domains can be crossed only with the four phase handshake (i.e.
* Request--Acknowledge). The CDC synchronization is built in as an option,
* disabled by default.
*
* Note that the use of the CDC synchronization requires its use on both sides
* of the clock domain boundary, i.e. on the Request line of the receiving side
* and on the Acknowledge line of the transmitting side.
*/
module rdyval2reqack_tph #(
    // Data path bit width
    parameter int DWIDTH = 1,
    // When set, CDC flops will be instantiated on the Request--Acknowledge
    // handshake interface.
    parameter bit INCLUDE_CDC = 1'b0
) (
    // Input Ready--Valid handshake interface
    input  logic vld,
    output logic rdy,
    input  logic [DWIDTH-1:0] i_dat,

    // Output Request--Acknowledge two phase handshake interface
    output logic req,
    input  logic ack,
    output logic [DWIDTH-1:0] o_dat,

    // rising edge active clock
    input  logic clk,
    // asynchronous reset, active low
    input  logic rst_n
);

// Signals transferring data request from the input interface to the output
// interface.
logic req_accept;

// Signals a valid acknowledge from the output handshake interface.
logic ack_accept;

// Internal representation of the Acknowledge signal. It is either the direct
// `ack` input or its synchronized version.
logic ack_i;

// OPTION: CDC synchronization (on the output handshake interface)
if (INCLUDE_CDC) begin: g_cdc
    logic [1:0] cdc_sync_ack;

    // `ack_nxt` synchronizer
    always_ff @(posedge clk or negedge rst_n) begin: p_sync_ack
        if (!rst_n)
            cdc_sync_ack <= '0;
        else
            cdc_sync_ack <= {ack,cdc_sync_ack[$high(cdc_sync_ack):1]};
    end: p_sync_ack

    assign ack_i = cdc_sync_ack[0];
end: g_cdc

// OPTION: No CDC synchronization.
else begin: g_no_cdc
    assign ack_i = ack;
end: g_no_cdc


assign req_accept = rdy & vld;

// The input handshake interface indicates Ready whenever it can accept new
// data. This can be as soon as the output handshake interface acknowledge
// turned to the same level as the output handshake request.
// Note: This implementation uses combinational output to minimize latency. This
// could be improved (at the cost of larger latency) by adding an extra flop at
// the output.
assign rdy = ~(req ^ ack_i);

// Implements the Request part of the output handshake.
always_ff @(posedge clk or negedge rst_n) begin: p_req
    if (!rst_n)  req <= 1'b0;
    else if (req_accept)  req <= ~req;
end: p_req

// Implements the data buffer flop. It is factored into a separate process as
// we do not need to have the reset for data path flops.
always_ff @(posedge clk) begin: p_data
    if (req_accept)  o_dat <= i_dat;
end: p_data

endmodule: rdyval2reqack_tph
