module vregfile_wrapper #(
    parameter int unsigned VLEN = 128,
    parameter int unsigned ELEN = 32,
    parameter int unsigned AddrWidth = 5
) (
    // Clock and Reset
    input   logic                 clk_i,
    input   logic                 rst_ni,

    // Read ports
    input   logic                 req_i,     // maybe I could remove it and use num_operands_i instead (when != 0 request), also rigth now it's not needed fot it to stay high should I change?
    input   logic                 we_i,
    input   logic [AddrWidth-1:0] raddr_a_i, raddr_b_i,
    output  logic [ELEN-1:0]      rdata_a_o, rdata_b_o, rdata_c_o, // TO CHANGE THE WIDTH

    // Write port
    input   logic [AddrWidth-1:0] waddr_i,
    input   logic [ELEN-1:0]      wdata_i,

    // VRF related FSM signals
    input logic [1:0]             num_operands_i,

    // Pipeline related FSM signals
    output  logic                 vector_done_o              // signals the pipeline that the vector operation is finished (most likely with a write to the VRF)
);

  typedef enum {
    VRF_IDLE,
    VRF_READ1,
    VRF_READ2,
    VRF_READ3,
    V_OP,
    VRF_WRITE
  } vrf_state_t;

  parameter COUNT = VLEN/ELEN;

  // RAM interface
  logic req_s, we_s;
  logic [AddrWidth-1:0] addr_s;
  logic [VLEN-1:0] rdata_s;

  // VRF FSM signals
  vrf_state_t vrf_state, vrf_next_state;
  int count_d, count_q;       // I could need it to be bigger

  // Internal registers signals
  logic rs1_en, rs2_en, rs3_en, rs1_shift, rs2_shift, rs3_shift, rd_shift;
  logic [VLEN-1:0] rs1_q, rs2_q, rs3_q;
  logic [VLEN-1:0] rd_q;

  // Output signals
  assign rdata_a_o = rs1_q[VLEN-1:VLEN-ELEN];
  assign rdata_b_o = rs2_q[VLEN-1:VLEN-ELEN];
  assign rdata_c_o = rs3_q[VLEN-1:VLEN-ELEN];

  /////////////
  // VRF FSM //
  /////////////

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vrf_state <= VRF_IDLE;
      count_q <= 0;
    end else begin
      vrf_state <= vrf_next_state;
      count_q <= count_d;
    end
  end

  always_comb begin
    rs1_en = 0;
    rs2_en = 0;
    rs3_en = 0;
    rs1_shift = 0;
    rs2_shift = 0;
    rs3_shift = 0;
    rd_shift = 0;
    vector_done_o = 0;
    req_s = 0;
    we_s = 0;
    case (vrf_state)

      VRF_IDLE: begin
        count_d = COUNT;
        if (!req_i) begin
          vrf_next_state = VRF_IDLE;
        end else begin
          if (num_operands_i==2'b00) begin
            vrf_next_state = V_OP;
          end else begin
            // RAM read request
            req_s = 1;
            we_s = 0;
            addr_s = raddr_a_i;
            vrf_next_state = VRF_READ1;
          end
        end
      end

      VRF_READ1: begin
        rs1_en = 1;
        if (num_operands_i==2'b01) begin
          vrf_next_state = V_OP;
        end else begin
          // RAM read request
          req_s = 1;
          we_s = 0;
          addr_s = raddr_b_i;
          vrf_next_state = VRF_READ2;
        end
      end

      VRF_READ2: begin
        rs2_en = 1;
        if (num_operands_i==2'b10) begin
          vrf_next_state = V_OP;
        end else begin
          // RAM read request
          req_s = 1;
          we_s = 0;
          addr_s = waddr_i;
          vrf_next_state = VRF_READ3;
        end
      end
      
      VRF_READ3: begin
        rs3_en = 1;
        vrf_next_state = V_OP;
      end

      V_OP: begin
        if (we_i==1) rd_shift = 1;
        if (num_operands_i>0) rs1_shift = 1;
        if (num_operands_i>1) rs2_shift = 1;
        if (num_operands_i>2) rs3_shift = 1;
        count_d = count_d-1;
        if (count_d==0)
          vrf_next_state = VRF_WRITE;
        else
          vrf_next_state = V_OP;
      end

      VRF_WRITE: begin
        if (we_i==1) begin
          // RAM write request
          req_s = 1;
          we_s = 1;
          addr_s = waddr_i;
        end
        vrf_next_state = VRF_IDLE;
        vector_done_o = 1;
      end

      default: begin
        vrf_next_state = VRF_IDLE;
      end
    endcase
  end

  ////////////////////////
  // Internal registers //
  ////////////////////////

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rs1_q <= '0;
      rs2_q <= '0;
      rs3_q <= '0;
      rd_q  <= '0;
    end else begin
      // source registers can be loaded in parallel and shifted left by 32
      if (rs1_en) rs1_q <= rdata_s;
      else if (rs1_shift) rs1_q <= {rs1_q[VLEN-1-ELEN:0], 32'h00000000};
      if (rs2_en) rs2_q <= rdata_s;
      else if (rs2_shift) rs2_q <= {rs2_q[VLEN-1-ELEN:0], 32'h00000000};
      if (rs3_en) rs3_q <= rdata_s;
      else if (rs3_shift) rs3_q <= {rs3_q[VLEN-1-ELEN:0], 32'h00000000};
      // destination register can be shifted left to load new data sequentially
      if (rd_shift) rd_q <= {rd_q[VLEN-1-ELEN:0], wdata_i};
    end
  end

  /////////
  // VRF //
  /////////

  // Instantiate prim_generic_ram_1p
  ram_1p #(
      .Width(VLEN),
      .Depth(2 ** AddrWidth)
  ) ram_inst (
      .clk_i(clk_i),
      .req_i(req_s),
      .we_i(we_s),
      .addr_i(addr_s),
      .wdata_i(rd_q),
      .rdata_o(rdata_s)
  );

endmodule
