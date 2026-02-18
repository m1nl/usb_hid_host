/*

Copyright (c) 2025 Mateusz Nalewajski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

/*
 * Synchronizes an active-high asynchronous reset signal to a given clock by
 * using a pipeline of N registers and stretches with D synchronous registers.
 */
module util_reset_sync #
(
    // depth of synchronizer
    parameter N = 3,
    // duration of pulse
    parameter D = 2
)
(
    input  wire clk,
    input  wire rst,
    output wire out
);

(* ASYNC_REG = "TRUE" *)
reg [N-1:0] rst_hold = {N{1'b0}};
reg [D-1:0] sync_reg = {D{1'b0}};

assign out = |sync_reg[D-1:0];

always @(posedge clk or posedge rst) begin
  if (rst) begin
    rst_hold <= {N{1'b1}};
  end else begin
    rst_hold[N-1:0] <= {rst_hold[N-2:0], 1'b0};
  end
end

always @(posedge clk) begin
  sync_reg[0] <= rst_hold[N-1];
  sync_reg[D-1:1] <= sync_reg[D-2:0];
end

endmodule

`resetall
