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

Change log:
    2019, Mar.
    - Created.
*/


/**
* Implements a fair policy arbiter between two Request--Acknowledge producers
* to a single Request--Acknowledge consumer. The arbiter acts as an extra
* pipeline stage with interface to two producers.
*
* All ports implement the four-phase, request--acknowledge protocol. The
* phases are as follows:
*
* - Request asserts (i.e goes high),
* - acknowledge asserts (i.e. goes high),
* - request de-asserts,
* - acknowledge de-asserts.
*
* Acknowledges on the producer ports are implemented so that they de-assert
* only after the request--acknowledge handshake has been fully completed on
* the consumer port.
*
* A sample waveform may look like as follows:
*
*                      ___          ______
*     Producer0 req __|   |________|     
*                        ________        _
*     Producer0 ack ____|        |______|  (Request ack. extends over the consumer handshake)
*                        ____
*     Consumer req  ____|    |____________
*                          ____
*     Consumer ack  ______|    |__________
*
* @todo Add optional synchronization, separately for each port.
*/
module reqack_arbiter_two2one #(
    // Data path bit width
    parameter int DWIDTH = 1
)(
    // 1st Input Request--Acknowledge handshake interface
    input  logic prod0_req,
    output logic prod0_ack,
    input  logic [DWIDTH-1:0] prod0_dat,

    // 2nd Input Request--Acknowledge handshake interface
    input  logic prod1_req,
    output logic prod1_ack,
    input  logic [DWIDTH-1:0] prod1_dat,


    // Output Request--Acknowledge handshake interface
    output logic cons_req,
    input  logic cons_ack,
    output logic [DWIDTH-1:0] cons_dat,

    // rising edge active clock
    input  logic clk,
    // asynchronous reset, active low
    input  logic rst_n
);


// ----------------------------------------------
// Producer to Consumer Data Path
// ----------------------------------------------

// enables accepting requests from Producer0
logic prod0_req_allow;
// strobe indicating to proceed with processing Producer0 request
logic prod0_req_accept;
// strobe indicating Producer0 request fall
logic prod0_req_req_fall;
// makes the internal Producer0 request asserted until Consumer's acknowledge
logic prod0_req_pend;
// Producer0 request synchronizer
logic [1:0] sync_prod0_req_req;
// internal Producer0 request
logic prod0_req_req_i;
// flopped version of Producer0 request (for fall detection)
logic prod0_req_req_d;


// Producer1 signals with the same meaning as for Producer0
logic prod1_req_allow;
logic prod1_req_accept;
logic prod1_req_req_fall;
logic prod1_req_pend;
logic [1:0] sync_prod1_req_req;
logic prod1_req_req_i;
logic prod1_req_req_d;

// delayed consumer acknowledge (used for detecting the acknowledge fall)
logic cons_ack_d;
// strobe indicating the Consumer acknowledge fall
logic cons_ack_fall;
// Consumer acknowledge synchronizer
logic [1:0] sync_cons_ack;
// clears Consumer request
logic cons_req_clr;


// flopped versions of internal signals (used for fall detection of those signals)
always_ff @(posedge clk or negedge rst_n) begin: p_req_flopped_sigs
    if (!rst_n) begin
        prod0_req_req_d <= 1'b0;
        prod1_req_req_d <= 1'b0;
        cons_ack_d      <= 1'b0;
    end
    else begin
        prod0_req_req_d <= prod0_req_req_i;
        prod1_req_req_d <= prod1_req_req_i;
        cons_ack_d      <= sync_cons_ack[0];
    end
end: p_req_flopped_sigs


// Consumer (Output) Port
// ----------------------

// Consumer acknowledge synchronizer (avoids potential CDC issues)
always_ff @(posedge clk or negedge rst_n) begin: p_cons_ack_sync
    if (!rst_n)
        sync_cons_ack <= '0;
    else 
        sync_cons_ack <= {cons_ack, sync_cons_ack[$high(sync_cons_ack):1]};
end: p_cons_ack_sync


// Consumer request data (latches request data bits from a producer port,
// request of which gets accepted)
always_ff @(posedge clk or negedge rst_n) begin: p_cons_data
    if (!rst_n)
        cons_dat <= '0;
    else if (prod0_req_accept)
        cons_dat <= prod0_dat;
    else if (prod1_req_accept)
        cons_dat <= prod1_dat;
end: p_cons_data


// clear Consumer request after acknowledge from Consumer (conditioned by asserted
// request for extra safety, but may be omitted if the Consumer follows the handshake
// protocol correctly)
assign cons_req_clr = cons_req & sync_cons_ack[0];


// Consumer request indication (set on acceptance of a request from an either
// producer port, cleared on consumer acknowledge)
always_ff @(posedge clk or negedge rst_n) begin: p_cons_req
    if (!rst_n)
        cons_req <= 1'b0;
    else if (prod0_req_accept | prod1_req_accept | cons_req_clr)
        cons_req <= prod0_req_accept | prod1_req_accept | (~cons_req_clr);
end: p_cons_req


// detect fall on Consumer acknowledge
// (It is used to clear the request pending flag on the corresponding producer port.)
assign cons_ack_fall = cons_ack_d & ~sync_cons_ack[0];


// Producer0 (Input) Port
// ----------------------

// internal Producer0 request
// (It is an OR combination of the actual request and the request pending flag.)
assign prod0_req_req_i = sync_prod0_req_req[0] | prod0_req_pend;

// detect fall of the internal Producer0 request
// (Used to clear Producer0 acknowledge and hence complete the handshake.)
assign prod0_req_req_fall = prod0_req_req_d & ~prod0_req_req_i;

// acceptance of the Producer0 request
// (The use of the acknowledge signal blocks accepting another request until
// the active one completes. The "allow" condition is determined by the
// arbitration policy and the progress of the Request-Response transaction.)
assign prod0_req_accept = prod0_req_req_i & ~prod0_ack & prod0_req_allow;


// Producer0 request synchronizer (avoids potential CDC problems)
always_ff @(posedge clk or negedge rst_n) begin: p_prod0_req_sync
    if (!rst_n)
        sync_prod0_req_req <= '0;
    else 
        sync_prod0_req_req <= {prod0_req, sync_prod0_req_req[$high(sync_prod0_req_req):1]};
end: p_prod0_req_sync


// Producer0 Request acknowledge
// (Set when Producer0 Request gets accepted, cleared when Producer0 de-asserts the request
// and the Request has also been fully handshaked on the Consumer port. The latter part
// is accomplished by using the Producer0 request pending flag.)
always_ff @(posedge clk or negedge rst_n) begin: p_prod0_ack
    if (!rst_n) begin
        prod0_ack <= 1'b0;
    end
    else if (prod0_req_accept | prod0_req_req_fall) begin
        prod0_ack <= prod0_req_accept | (~prod0_req_req_fall);
    end
end: p_prod0_ack


// Producer0 request pending flag
// (Set when Producer0 request gets accepted, cleared when the request has been fully
// handshaked on the Consumer port. The flag is ORed with the incoming Producer0 request
// to keep the internal request signal asserted until the Consumer port handshake
// completes.)
always_ff @(posedge clk or negedge rst_n) begin: p_prod0_req_pend
    if (!rst_n) begin
        prod0_req_pend <= 1'b0;
    end
    else if (prod0_req_accept | cons_ack_fall) begin
        prod0_req_pend <= prod0_req_accept | (~cons_ack_fall);
    end
end: p_prod0_req_pend


// Producer1 (Input) Port
// ----------------------
// (The implementation is the same as for Producer0 and hence requires no extra
// comments.)

// internal Producer1 request
assign prod1_req_req_i = sync_prod1_req_req[0] | prod1_req_pend;

// detect fall of the internal Producer1 request
assign prod1_req_req_fall = prod1_req_req_d & ~prod1_req_req_i;

// acceptance of the Producer1 request
assign prod1_req_accept = prod1_req_req_i & ~prod1_ack & prod1_req_allow;


// Producer1 request synchronizer (avoids potential CDC problems)
always_ff @(posedge clk or negedge rst_n) begin: p_prod1_req_sync
    if (!rst_n)
        sync_prod1_req_req <= '0;
    else 
        sync_prod1_req_req <= {prod1_req, sync_prod1_req_req[$high(sync_prod1_req_req):1]};
end: p_prod1_req_sync


// Producer1 request acknowledge
always_ff @(posedge clk or negedge rst_n) begin: p_prod1_ack
    if (!rst_n) begin
        prod1_ack <= 1'b0;
    end
    else if (prod1_req_accept | prod1_req_req_fall) begin
        prod1_ack <= prod1_req_accept | (~prod1_req_req_fall);
    end
end: p_prod1_ack


// Producer1 request pending flag
always_ff @(posedge clk or negedge rst_n) begin: p_prod1_req_pend
    if (!rst_n) begin
        prod1_req_pend <= 1'b0;
    end
    else if (prod1_req_accept | cons_ack_fall) begin
        prod1_req_pend <= prod1_req_accept | (~cons_ack_fall);
    end
end: p_prod1_req_pend


// ----------------------------------------------
// Arbitration Policy
// ----------------------------------------------
// (This is a fair arbitration policy. For two producer ports, this is represented
// by a single flop that holds the index of the last arbitrated producer port.)

// Identifies which producer port has been serviced last.
logic prod_src_last;


// Producer arbitration policy
// (If both producer ports indicate a request at the same time, the policy selects
// which port is allowed to proceed with the request. The policy is based on
// the last port allowed to proceed, and translates into the following Boolean
// table.)
//
// last    req0    req1 |  last'
// ---------------------+------
// 0       0       0    |  0
// 0       0       1    |  1
// 0       1       0    |  0
// 0       1       1    |  1
// 1       0       0    |  1
// 1       0       1    |  1
// 1       1       0    |  0
// 1       1       1    |  0
//
// The above Boolean table is yielded through "accept" and "allow" signals for
// both producer ports.
always_ff @(posedge clk or negedge rst_n) begin: p_prod_src_last
    if (!rst_n)
        prod_src_last <= 1'b0;
    else begin
        // Request from both ports cannot be accepted at the same time.
        assert( ~(prod0_req_accept & prod1_req_accept) );
        if (prod0_req_accept | prod1_req_accept) begin
            prod_src_last <= prod1_req_accept;
        end
    end
end: p_prod_src_last

// DTM Request is allowed when a) no other request is in progress, and
// b) the request is arbitrated.
assign prod0_req_allow = ( prod_src_last | ~prod1_req_req_i);
assign prod1_req_allow = (~prod_src_last | ~prod0_req_req_i);


endmodule: reqack_arbiter_two2one
