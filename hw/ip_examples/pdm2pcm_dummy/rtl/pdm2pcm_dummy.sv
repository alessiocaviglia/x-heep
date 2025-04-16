// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Author: Pierre Guillod <pierre.guillod@epfl.ch>, EPFL, STI-SEL
// Date: 19.02.2022

module pdm2pcm_dummy (
    input logic clk_i,
    input logic rst_ni,

    // input ports
    input logic pdm_clk_i,

    // output ports
    output logic pdm_data_o
);

  int fpdm;
  int lineidx;
  string line;

  logic pdm_clk_h;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      lineidx = 0;
      pdm_data_o <= 0;
    end else begin

      if (pdm_clk_i == 1 & pdm_clk_h == 0) begin
        $fgets(line, fpdm);
        line = line.substr(0, 0);
        if (line == "1") begin
          pdm_data_o <= 1;
        end else begin
          pdm_data_o <= 0;
        end
        lineidx = lineidx + 1;
      end

      pdm_clk_h = pdm_clk_i;

      if (lineidx >= 65536) begin
        $fclose(fpdm);
        $stop;
      end
    end
  end

endmodule
