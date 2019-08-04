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
* Implements a pipeline stage for the request--acknowledge two phase handshake
* protocol.
*
* This implementation includes optional CDC synchronizers. Depending on which of
* the two handshake interfaces is considered asynchronous to `clk`, the user may
* choose to place CDC synchronizer on the previous stage Request input or the
* next stage Acknowledge input. Rarely CDC synchronizers need to be placed on
* both handshake interfaces.
*/
module reqack_tph_pipe_stage #(
    // Data path bit width
    parameter int DWIDTH = 1,
    // When set, CDC flops will be instantiated on the previous stage handshake
    // interface (i.e. Request input).
    parameter bit INCLUDE_CDC_PRV = 1'b0,
    // When set, CDC flops will be instantiated on the next stage handshake
    // interface (i.e. next stage Acknowledge input).
    parameter bit INCLUDE_CDC_NXT = 1'b0
) (
    input  logic req,
    output logic ack,
    input  logic [DWIDTH-1:0] i_dat,

    output logic req_nxt,
    input  logic ack_nxt,
    output logic [DWIDTH-1:0] o_dat,

    // rising edge active clock
    input  logic clk,
    // asynchronous reset, active low
    input  logic rst_n
);

// Signals accepting a previous stage Request. This is used to set the
// next stage Request and signal back Acknowledge to the previous stage.
logic req_accept;

logic req_i;
logic ack_nxt_i;

if (INCLUDE_CDC_PRV) begin: g_cdc_prv
    logic [1:0] cdc_sync_req;

    // `req` synchronizer and a delay flop for fall detection
    always_ff @(posedge clk or negedge rst_n) begin: p_sync_req
        if (!rst_n)
            cdc_sync_req <= '0;
        else
            cdc_sync_req <= {req,cdc_sync_req[$high(cdc_sync_req):1]};
    end: p_sync_req

    assign req_i = cdc_sync_req[0];
end: g_cdc_prv
else begin: g_no_cdc_prv
    assign req_i = req;
end: g_no_cdc_prv

if (INCLUDE_CDC_NXT) begin: g_cdc_nxt
    logic [1:0] cdc_sync_ack_nxt;

    // `ack_nxt` synchronizer
    always_ff @(posedge clk or negedge rst_n) begin: p_sync_ack_nxt
        if (!rst_n)
            cdc_sync_ack_nxt <= '0;
        else
            cdc_sync_ack_nxt <= {ack_nxt,cdc_sync_ack_nxt[$high(cdc_sync_ack_nxt):1]};
    end: p_sync_ack_nxt

    assign ack_nxt_i = cdc_sync_ack_nxt[0];
end: g_cdc_nxt
else begin: g_no_cdc_nxt
    assign ack_nxt_i = ack_nxt;
end: g_no_cdc_nxt

// In general, a new request from a previous stage is signalled by the input
// request being at a different level than the output request (to the next
// stage). The new request can be accepted only when the next stage has
// acknowledged the output request (i.e. the next stage acknowledge is
// at the same level as the next stage request output).
assign req_accept = (req_i ^ req_nxt) & (req_nxt ^ ~ack_nxt_i);

// Implements the Request forwarding to the next stage.
always_ff @(posedge clk or negedge rst_n) begin: p_req_nxt
    if (!rst_n)           req_nxt <= 1'b0;
    else if (req_accept)  req_nxt <= req_i;
end: p_req_nxt

// Implements the Acknowledge on the input stage. A new Request shall not be
// acknowledged until the next stage acknowledges processing of its (i.e. next
// stage) request.
// The input stage acknowledge aliases with the next stage request.
assign ack = req_nxt;

// Implements the data buffer flop. It is factored into a separate process as
// we do not need to have the reset for data path flops.
always_ff @(posedge clk) begin: p_data
    if (req_accept)  o_dat <= i_dat;
end: p_data

endmodule: reqack_tph_pipe_stage
