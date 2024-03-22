module ram_1p #(
    parameter int unsigned Width = 32,
    parameter int unsigned Depth = 256
) (
    input logic clk_i,
    input logic req_i,
    input logic we_i,
    input logic [$clog2(Depth)-1:0] addr_i,
    input logic [Width-1:0] wdata_i,
    output logic [Width-1:0] rdata_o
);

    logic [Width-1:0] mem [0:Depth-1];

    initial begin
        mem[0] = 128'h11111111111111111111111111111111;
        mem[1] = 128'h22222222222222222222222222222222;
        mem[2] = 128'h33333333333333333333333333333333;
    end

    always_ff @(posedge clk_i) begin
        if (req_i) begin
            if (we_i) begin
                mem[addr_i] <= wdata_i;
            end else begin
                rdata_o <= mem[addr_i];
            end
        end
    end

endmodule
