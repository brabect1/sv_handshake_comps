/**
* Implements a 32-bit data path chain that includes all the handshake components.
* The chain starts with a pull interface and ends with a push interface.
*/
module wrap(
    input  logic pull_rdy,
    output logic pull_pop,
    input  int   pull_dat,

    input  logic push_rdy,
    output logic push_push,
    output int   push_dat,

    input  logic clk,
    input  logic rst_n
);

logic first_rdy;
logic second_rdy;
logic second_vld;
int   second_dat;
logic third_rdy;
logic third_vld;
int   third_dat;
logic forth_req;
logic forth_ack;
int   forth_dat;
logic fifth_req;
logic fifth_ack;
int   fifth_dat;
logic sixth_req;
logic sixth_ack;
int   sixth_dat;
logic seventh_vld;

assign pull_pop = first_rdy & pull_rdy;

rdyval_pipe_stage #(.DWIDTH(32)) u_first (
    //---input---
    .vld    (pull_rdy),
    .rdy    (first_rdy),
    .i_dat  (pull_dat),
    //---output---
    .vld_nxt(second_vld),
    .rdy_nxt(second_rdy),
    .o_dat  (second_dat),
    //---others---
    .*
);

rdyval_pipe_stage #(.DWIDTH(32)) u_second (
    //---input---
    .vld    (second_vld),
    .rdy    (second_rdy),
    .i_dat  (second_dat),
    //---output---
    .vld_nxt(third_vld),
    .rdy_nxt(third_rdy),
    .o_dat  (third_dat),
    //---others---
    .*
);

rdyval2reqack #(.DWIDTH(32)) u_third (
    //---input---
    .vld    (third_vld),
    .rdy    (third_rdy),
    .i_dat  (third_dat),
    //---output---
    .req    (forth_req),
    .ack    (forth_ack),
    .o_dat  (forth_dat),
    //---others---
    .*
);

reqack_pipe_stage #(.DWIDTH(32)) u_forth (
    //---input---
    .req    (forth_req),
    .ack    (forth_ack),
    .i_dat  (forth_dat),
    //---output---
    .req_nxt(fifth_req),
    .ack_nxt(fifth_ack),
    .o_dat  (fifth_dat),
    //---others---
    .*
);

reqack_pipe_stage #(.DWIDTH(32)) u_fifth (
    //---input---
    .req    (fifth_req),
    .ack    (fifth_ack),
    .i_dat  (fifth_dat),
    //---output---
    .req_nxt(sixth_req),
    .ack_nxt(sixth_ack),
    .o_dat  (sixth_dat),
    //---others---
    .*
);

reqack2rdyval #(.DWIDTH(32)) u_sixth (
    //---input---
    .req    (sixth_req),
    .ack    (sixth_ack),
    .i_dat  (sixth_dat),
    //---output---
    .vld    (seventh_vld),
    .rdy    (push_rdy),
    .o_dat  (push_dat),
    //---others---
    .*
);

assign push_push = push_rdy & seventh_vld;

endmodule: wrap
