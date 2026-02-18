// ---------------------------------------------------------------------------
// Copyright 2026 Mateusz Nalewajski
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
// ---------------------------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype none
module usb_hid_host_dual #(
  parameter FULL_SPEED = 1,
  parameter MOUSE_SUPPORT = 0,
  parameter DEBUG = 1,  // debug usb_hid_host instance (0 - off, 1 - instance 0, 2 - instance 2)
  parameter DEBUG_MODE = 0  // debug mode (0 - HID report, 1 - HID registers, 2 - UKP state machine)
) (
  input wire clk,
  input wire reset,

  input wire usb_clk,

  input  wire [1:0] usb_dm_i, usb_dp_i,  // USB D- and D+
  output wire [1:0] usb_dm_o, usb_dp_o,  // USB D- and D+
  output wire [1:0] usb_oe,              // USB OE

  output wire connerr_0,
  output wire connerr_1,

  output wire game_l_0,
  output wire game_r_0,
  output wire game_u_0,
  output wire game_d_0,
  output wire game_a_0,
  output wire game_b_0,
  output wire game_x_0,
  output wire game_y_0,
  output wire game_sel_0,
  output wire game_sta_0,

  output wire game_l_1,
  output wire game_r_1,
  output wire game_u_1,
  output wire game_d_1,
  output wire game_a_1,
  output wire game_b_1,
  output wire game_x_1,
  output wire game_y_1,
  output wire game_sel_1,
  output wire game_sta_1,

  output wire       key_report,
  output wire [7:0] key_modifiers,
  output wire [7:0] key_0,
  output wire [7:0] key_1,
  output wire [7:0] key_2,
  output wire [7:0] key_3,

  output wire              mouse_report,
  output wire        [2:0] mouse_btn,
  output wire signed [7:0] mouse_dx,
  output wire signed [7:0] mouse_dy,

  output wire        hid_debug_valid,
  output wire [63:0] hid_debug
);

wire usb_reset;

util_reset_sync util_reset_sync_0 (
  .rst(reset),
  .clk(usb_clk),
  .out(usb_reset)
);

wire game_l_i [0:1];
wire game_r_i [0:1];
wire game_u_i [0:1];
wire game_d_i [0:1];
wire game_a_i [0:1];
wire game_b_i [0:1];
wire game_x_i [0:1];
wire game_y_i [0:1];
wire game_sel_i [0:1];
wire game_sta_i [0:1];

wire [7:0] key_modifiers_i [0:1];
wire [7:0] key_0_i [0:1];
wire [7:0] key_1_i [0:1];
wire [7:0] key_2_i [0:1];
wire [7:0] key_3_i [0:1];

wire [2:0] mouse_btn_i [0:1];
wire [7:0] mouse_dx_i [0:1];
wire [7:0] mouse_dy_i [0:1];

wire        hid_debug_valid_i [0:1];
wire [63:0] hid_debug_i [0:1];
wire [63:0] hid_regs_i  [0:1];
wire [1:0]  typ_i       [0:1];

wire [9:0] rom_addr_i [0:1];
wire [3:0] rom_dout_i [0:1];
wire       rom_en_i   [0:1];

wire connerr_i     [0:1];
wire full_report_i [0:1];
wire busy_i        [0:1];

usb_hid_host #(
  .FULL_SPEED(FULL_SPEED)
) usb_hid_host_0 (
  .clk(usb_clk),
  .reset(usb_reset),
  .cs(1),
  .usb_dm_i(usb_dm_i[0]),
  .usb_dp_i(usb_dp_i[0]),
  .usb_dm_o(usb_dm_o[0]),
  .usb_dp_o(usb_dp_o[0]),
  .usb_oe(usb_oe[0]),
  .typ(typ_i[0]),
  .rom_addr(rom_addr_i[0]),
  .rom_dout(rom_dout_i[0]),
  .rom_en(rom_en_i[0]),
  .connerr(connerr_i[0]),
  .busy(busy_i[0]),
  .full_report(full_report_i[0]),
  .dbg_hid_report(hid_debug_i[0]),
  .dbg_hid_regs(hid_regs_i[0]),
  .game_l(game_l_i[0]),
  .game_r(game_r_i[0]),
  .game_u(game_u_i[0]),
  .game_d(game_d_i[0]),
  .game_a(game_a_i[0]),
  .game_b(game_b_i[0]),
  .game_x(game_x_i[0]),
  .game_y(game_y_i[0]),
  .game_sel(game_sel_i[0]),
  .game_sta(game_sta_i[0]),
  .key_modifiers(key_modifiers_i[0]),
  .key_3(key_3_i[0]),
  .key_2(key_2_i[0]),
  .key_1(key_1_i[0]),
  .key_0(key_0_i[0]),
  .mouse_btn(mouse_btn_i[0]),
  .mouse_dx(mouse_dx_i[0]),
  .mouse_dy(mouse_dy_i[0])
);

usb_hid_host #(
  .FULL_SPEED(FULL_SPEED)
) usb_hid_host_1 (
  .clk(usb_clk),
  .reset(usb_reset),
  .cs(1),
  .usb_dm_i(usb_dm_i[1]),
  .usb_dp_i(usb_dp_i[1]),
  .usb_dm_o(usb_dm_o[1]),
  .usb_dp_o(usb_dp_o[1]),
  .usb_oe(usb_oe[1]),
  .typ(typ_i[1]),
  .rom_addr(rom_addr_i[1]),
  .rom_dout(rom_dout_i[1]),
  .rom_en(rom_en_i[1]),
  .connerr(connerr_i[1]),
  .busy(busy_i[1]),
  .full_report(full_report_i[1]),
  .dbg_hid_report(hid_debug_i[1]),
  .dbg_hid_regs(hid_regs_i[1]),
  .game_l(game_l_i[1]),
  .game_r(game_r_i[1]),
  .game_u(game_u_i[1]),
  .game_d(game_d_i[1]),
  .game_a(game_a_i[1]),
  .game_b(game_b_i[1]),
  .game_x(game_x_i[1]),
  .game_y(game_y_i[1]),
  .game_sel(game_sel_i[1]),
  .game_sta(game_sta_i[1]),
  .key_modifiers(key_modifiers_i[1]),
  .key_3(key_3_i[1]),
  .key_2(key_2_i[1]),
  .key_1(key_1_i[1]),
  .key_0(key_0_i[1]),
  .mouse_btn(mouse_btn_i[1]),
  .mouse_dx(mouse_dx_i[1]),
  .mouse_dy(mouse_dy_i[1])
);

usb_hid_host_dual_rom usb_hid_host_dual_rom_0 (
  .clk(usb_clk),
  .ena(rom_en_i[0]),
  .addra(rom_addr_i[0]),
  .douta(rom_dout_i[0]),
  .enb(rom_en_i[1]),
  .addrb(rom_addr_i[1]),
  .doutb(rom_dout_i[1])
);

xpm_cdc_pulse xpm_cdc_pulse_0 (
  .src_clk(usb_clk),
  .src_rst(usb_reset),
  .dest_clk(clk),
  .dest_rst(reset),
  .src_pulse(connerr_i[0]),
  .dest_pulse(connerr_0)
);

xpm_cdc_pulse xpm_cdc_pulse_1 (
  .src_clk(usb_clk),
  .src_rst(usb_reset),
  .dest_clk(clk),
  .dest_rst(reset),
  .src_pulse(connerr_i[1]),
  .dest_pulse(connerr_1)
);

xpm_cdc_array_single #(
  .WIDTH(10)
) xpm_cdc_array_single_1 (
  .src_clk(usb_clk),
  .dest_clk(clk),
  .src_in({game_l_i[0], game_r_i[0], game_u_i[0], game_d_i[0], game_a_i[0], game_b_i[0], game_x_i[0], game_y_i[0],
    game_sel_i[0], game_sta_i[0]}),
  .dest_out({game_l_0, game_r_0, game_u_0, game_d_0, game_a_0, game_b_0, game_x_0, game_y_0, game_sel_0, game_sta_0})
);

xpm_cdc_array_single #(
  .WIDTH(10)
) xpm_cdc_array_single_2 (
  .src_clk(usb_clk),
  .dest_clk(clk),
  .src_in({game_l_i[1], game_r_i[1], game_u_i[1], game_d_i[1], game_a_i[1], game_b_i[1], game_x_i[1], game_y_i[1],
    game_sel_i[1], game_sta_i[1]}),
  .dest_out({game_l_1, game_r_1, game_u_1, game_d_1, game_a_1, game_b_1, game_x_1, game_y_1, game_sel_1, game_sta_1})
);

wire key_device_num;

assign key_device_num = typ_i[0] == 1 ? 0 :
                        typ_i[1] == 1 ? 1 : 0;

wire key_report_src_rcv;
reg key_report_src_send;

reg full_key_report_strobe = 1;

always @(posedge usb_clk)
  if (usb_reset) begin
    key_report_src_send <= 0;
    full_key_report_strobe <= 1;
  end else if (full_report_i[key_device_num]) begin
    full_key_report_strobe <= 1;
  end else if (!key_report_src_send && !key_report_src_rcv) begin
    key_report_src_send <= full_key_report_strobe;
    full_key_report_strobe <= 0;
  end else if (key_report_src_rcv)
    key_report_src_send <= 0;

xpm_cdc_handshake #(
  .DEST_EXT_HSK(0),
  .WIDTH(40)
) xpm_cdc_handshake_0 (
  .src_clk(usb_clk),
  .src_in({key_modifiers_i[key_device_num], key_0_i[key_device_num],
    key_1_i[key_device_num], key_2_i[key_device_num], key_3_i[key_device_num]}),
  .src_send(key_report_src_send),
  .src_rcv(key_report_src_rcv),
  .dest_clk(clk),
  .dest_out({key_modifiers, key_0, key_1, key_2, key_3}),
  .dest_req(key_report)
);

generate
  if (MOUSE_SUPPORT) begin
    wire mouse_device_num;

    assign mouse_device_num = typ_i[0] == 2 ? 0 :
                              typ_i[1] == 2 ? 1 : 0;

    wire mouse_report_src_rcv;
    reg mouse_report_src_send;

    reg full_mouse_report_strobe = 1;

    always @(posedge usb_clk)
      if (usb_reset) begin
        mouse_report_src_send <= 0;
        full_mouse_report_strobe <= 1;
      end else if (full_report_i[mouse_device_num]) begin
        full_mouse_report_strobe <= 1;
      end else if (!mouse_report_src_send && !mouse_report_src_rcv) begin
        mouse_report_src_send <= full_mouse_report_strobe;
        full_mouse_report_strobe <= 0;
      end else if (mouse_report_src_rcv)
        mouse_report_src_send <= 0;

    xpm_cdc_handshake #(
      .DEST_EXT_HSK(0),
      .WIDTH(19)
    ) xpm_cdc_handshake_1 (
      .src_clk(usb_clk),
      .src_in({mouse_btn_i[mouse_device_num], mouse_dx_i[mouse_device_num],
        mouse_dy_i[mouse_device_num]}),
      .src_send(mouse_report_src_send),
      .src_rcv(mouse_report_src_rcv),
      .dest_clk(clk),
      .dest_out({mouse_btn, mouse_dx, mouse_dy}),
      .dest_req(mouse_report)
    );

  end else begin

    assign mouse_report = 0;
    assign mouse_btn = 3'b0;
    assign mouse_dx = 8'b0;
    assign mouse_dy = 8'b0;
  end
endgenerate

generate
  if (DEBUG) begin
    localparam DEBUG_INSTANCE = DEBUG - 1;

    wire [63:0] hid_debug_fifo_wr_data;

    reg hid_debug_fifo_wr_data_valid;

    if (DEBUG_MODE == 0) begin
      assign hid_debug_fifo_wr_data = hid_debug_i[DEBUG_INSTANCE];
    end else if (DEBUG_MODE == 1) begin
      assign hid_debug_fifo_wr_data = hid_regs_i[DEBUG_INSTANCE];
    end else begin
      assign hid_debug_fifo_wr_data = {6'b0, rom_addr_i[DEBUG_INSTANCE], rom_dout_i[DEBUG_INSTANCE], 4'b0, 8'b0, 6'b0,
        typ_i[DEBUG_INSTANCE], usb_dm_i, 2'b0, usb_dp_i, 2'b0, usb_dm_o, 2'b0, usb_dp_o, 2'b0, 6'b0, usb_oe};
    end

    always @(*)
      hid_debug_fifo_wr_data_valid = busy_i[DEBUG_INSTANCE];

    // hid_debug_fifo

    wire hid_debug_fifo_full, hid_debug_fifo_empty;
    wire hid_debug_fifo_wr_rst_busy, hid_debug_fifo_rd_rst_busy;

    wire hid_debug_fifo_wr_en_i, hid_debug_fifo_rd_en_i;

    assign hid_debug_fifo_wr_en_i =
      !hid_debug_fifo_full && hid_debug_fifo_wr_data_valid && !hid_debug_fifo_wr_rst_busy &&
      !usb_reset;

    assign hid_debug_fifo_rd_en_i =
      !hid_debug_fifo_empty && !hid_debug_fifo_rd_rst_busy && !reset;

    xpm_fifo_async #(
      .RELATED_CLOCKS(0),
      .FIFO_WRITE_DEPTH(16),
      .WRITE_DATA_WIDTH(64),
      .READ_DATA_WIDTH(64),
      .USE_ADV_FEATURES("1000")
    ) xpm_fifo_async_0 (
      .rst(usb_reset),
      .wr_clk(usb_clk),
      .rd_clk(clk),
      .wr_en(hid_debug_fifo_wr_en_i),
      .rd_en(hid_debug_fifo_rd_en_i),
      .din(hid_debug_fifo_wr_data),
      .dout(hid_debug),
      .data_valid(hid_debug_valid),
      .wr_rst_busy(hid_debug_fifo_wr_rst_busy),
      .rd_rst_busy(hid_debug_fifo_rd_rst_busy),
      .full(hid_debug_fifo_full),
      .empty(hid_debug_fifo_empty)
    );

  end else begin

    assign hid_debug = 64'b0;
    assign hid_debug_valid = 0;
  end
endgenerate

endmodule
`default_nettype wire
// vim:ts=2 sw=2 tw=120 et
