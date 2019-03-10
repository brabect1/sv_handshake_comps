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
* Converts an input Request--Acknowledge handshake into an output Ready--Valid
* handshake.
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
module reqack2rdyval #(
    // Data path bit width
    parameter int DWIDTH = 1,
    // When set, CDC flops will be instantiated on the Request--Acknowledge
    // handshake interface.
    parameter bit INCLUDE_CDC = 1'b0
) (
    // Output Ready--Valid handshake interface
    output logic vld,
    input  logic rdy,
    output logic [DWIDTH-1:0] o_dat,

    // Input Request--Acknowledge handshake interface
    input  logic req,
    output logic ack,
    input  logic [DWIDTH-1:0] i_dat,

    // rising edge active clock
    input  logic clk,
    // asynchronous reset, active low
    input  logic rst_n
);

// Signals accepting a previous stage Request. This is used to set the
// next stage Request and signal back Acknowledge to the previous stage.
logic req_accept;

// Detects fall on Request (i.e. request removal). The pipeline stage in response
// clears Acknowledge to let a new Request start. The new request, though, will
// not be acknowledged until the former request has been fully handshaked on the
// next stage interface.
// Note: Clearing the Acknowledge earlier, rather than later (i.e. after completing
// the next stage handshake), may improve latency in case when there is a CDC
// synchronizer on the previous stage Request path.
logic req_fall;

// Internal Request signal. Comes either directly from `req` or through
// a CDC synchronizer.
logic req_i;

// Flopped version of `rdy_i` used for fall detection.
logic req_d;


if (INCLUDE_CDC) begin: g_cdc
    logic [1:0] cdc_sync_req;

    // `req` synchronizer and a delay flop for fall detection
    always_ff @(posedge clk or negedge rst_n) begin: p_sync_req
        if (!rst_n)
            cdc_sync_req <= '0;
        else
            cdc_sync_req <= {req,cdc_sync_req[$high(cdc_sync_req):1]};
    end: p_sync_req

    assign req_i = cdc_sync_req[0];
end: g_cdc
else begin: g_no_cdc
    assign req_i = req;
end: g_no_cdc


// Implements a delay flop for fall detection.
always_ff @(posedge clk or negedge rst_n) begin: p_req_d
    if (!rst_n)
        req_d <= 1'b0;
    else
        req_d <= req_i;
end: p_req_d

assign req_fall = req_d & ~req_i;
assign req_accept = req_i & ~ack & ~vld;

// Implements the Acknowledge part of the input handshake interface. 
always_ff @(posedge clk or negedge rst_n) begin: p_ack
    if (!rst_n)
        ack <= 1'b0;
    else begin
        // Request shall not be accepted at the same time when it is being
        // removed.
        assert (!(req_accept & req_fall));

        if (req_accept)
            ack <= 1'b1;
        else if (req_fall)
            ack <= 1'b0;
    end
end: p_ack

// Implements the Valid part of the output handshake interface. 
always_ff @(posedge clk or negedge rst_n) begin: p_vld
    if (!rst_n)
        vld <= 1'b0;
    else begin
        // Request shall not be accepted at the same time when the
        // output side handshake is being completed.
        assert (!(req_accept & (vld & rdy)));

        if (req_accept)
            vld <= 1'b1;
        else if (vld & rdy)
            vld <= 1'b0;
    end
end: p_vld

// Implements the data buffer flop. It is factored into a separate process as
// we do not need to have the reset for data path flops.
always_ff @(posedge clk) begin: p_data
    if (req_accept)
        o_dat <= i_dat;
end: p_data

endmodule: reqack2rdyval
