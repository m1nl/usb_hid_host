`default_nettype none
`timescale 1ns / 1ps
module usb_hid_host_dual_rom #(
  parameter MEMORY_FILE = "usb_hid_host_rom.mem"
) (
  input  wire       clk,

  input  wire [9:0] addra,
  output reg  [3:0] douta,
  input  wire       ena,

  input  wire [9:0] addrb,
  output reg  [3:0] doutb,
  input  wire       enb
);

reg [3:0] mem [0:1023];

initial
  $readmemh(MEMORY_FILE, mem);

always @(posedge clk)
  if (ena)
    douta <= mem[addra];

always @(posedge clk)
  if (enb)
    doutb <= mem[addrb];

endmodule
`default_nettype wire
// vim:ts=2 sw=2 tw=120 et
