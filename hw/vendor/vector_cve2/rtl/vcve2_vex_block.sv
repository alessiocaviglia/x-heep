/**
* Execution stage for Vector instructions
*
* Contains the vector ALU and MUL/DIV unit
*/

module vcve2_vex_block #(
    parameter int unsigned ELEN = 32,
    parameter int unsigned XLEN = 32
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,
    // Register file input
    input  logic [XLEN-1:0]           rf_rdata_a_i,
    // Output wb value
    output logic [ELEN-1:0]           vec_result_ex_o
);

    // Right now it only forwards this signal for move instructions
    assign vec_result_ex_o = rf_rdata_a_i;

endmodule
