`default_nettype none
`timescale 1ns / 1ps
module usb_hid_host_tb_top #(
  parameter FULL_SPEED = 1
) (
  input wire clk,
  input wire reset,
  input wire cs,

  input  wire usb_dm_i, usb_dp_i,
  output wire usb_dm_o, usb_dp_o,
  output wire usb_oe,

  output wire full_report,
  output wire [1:0] typ,
  output wire connerr,
  output wire busy,

  output wire [7:0] key_modifiers,
  output wire [7:0] key_0, key_1, key_2, key_3,

  output wire [2:0] mouse_btn,
  output wire signed [7:0] mouse_dx,
  output wire signed [7:0] mouse_dy,

  output wire game_l, game_r, game_u, game_d,
  output wire game_a, game_b, game_x, game_y, game_sel, game_sta,

  output wire [63:0] dbg_hid_report,
  output wire [63:0] dbg_hid_regs,

  output wire [9:0] rom_addr,
  output wire [3:0] rom_dout,
  output wire       rom_en
);

wire [9:0] rom_addr_int;
wire [3:0] rom_dout_int;
wire       rom_en_int;

usb_hid_host #(
  .FULL_SPEED(FULL_SPEED)
) usb_hid_host_inst (
  .clk(clk),
  .reset(reset),
  .cs(cs),
  .usb_dm_i(usb_dm_i),
  .usb_dp_i(usb_dp_i),
  .usb_dm_o(usb_dm_o),
  .usb_dp_o(usb_dp_o),
  .usb_oe(usb_oe),
  .full_report(full_report),
  .typ(typ),
  .connerr(connerr),
  .busy(busy),
  .key_modifiers(key_modifiers),
  .key_0(key_0),
  .key_1(key_1),
  .key_2(key_2),
  .key_3(key_3),
  .mouse_btn(mouse_btn),
  .mouse_dx(mouse_dx),
  .mouse_dy(mouse_dy),
  .game_l(game_l),
  .game_r(game_r),
  .game_u(game_u),
  .game_d(game_d),
  .game_a(game_a),
  .game_b(game_b),
  .game_x(game_x),
  .game_y(game_y),
  .game_sel(game_sel),
  .game_sta(game_sta),
  .dbg_hid_report(dbg_hid_report),
  .dbg_hid_regs(dbg_hid_regs),
  .rom_addr(rom_addr_int),
  .rom_dout(rom_dout_int),
  .rom_en(rom_en_int)
);

usb_hid_host_rom rom_inst (
  .clk(clk),
  .addr(rom_addr_int),
  .dout(rom_dout_int),
  .en(rom_en_int)
);

assign rom_addr = rom_addr_int;
assign rom_dout = rom_dout_int;
assign rom_en = rom_en_int;

endmodule
`default_nettype wire
