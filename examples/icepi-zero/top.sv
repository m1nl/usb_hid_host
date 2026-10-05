//
// USB HID host status for the IcePi Zero board.
//

`default_nettype none

module top (
    input  clk,

    // UART output over US1 USB port
    output usb_tx,

    // LEDs
    output logic [4:0] led,

    // US2 USB port
    output [1:0] usb_pull_dp,
    output [1:0] usb_pull_dn,
    inout  [1:0] usb_dp,
    inout  [1:0] usb_dn
);
    assign usb_pull_dp = 2'b0;
    assign usb_pull_dn = 2'b0;
    assign usb_tx = 1'b1; // UART idle
    assign usb_dp[1] = 1'bz;
    assign usb_dn[1] = 1'bz;

    wire sys_resetn;
    wire clk_usb;
    wire [1:0] usb_type;
    wire [7:0] key_modifiers, key_0, key_1, key_2, key_3, key_4, key_5;
    wire [2:0] mouse_btn;
    wire game_l, game_r, game_u, game_d;
    wire game_a, game_b, game_x, game_y;
    wire usb_dm_o, usb_dp_o, usb_oe;
    wire [9:0] rom_addr;
    wire [3:0] rom_dout;
    wire rom_en;

    assign usb_dn[0] = usb_oe ? usb_dm_o : 1'bz;
    assign usb_dp[0] = usb_oe ? usb_dp_o : 1'bz;

    pll_usb pll_usb(
        .clkin(clk),
        .clkout0(clk_usb),      // 60 MHz USB clock
        .locked(sys_resetn)
    );

    usb_hid_host #(.FULL_SPEED(1)) usb (
        .clk(clk_usb), .reset(~sys_resetn), .cs(1'b1),
        .usb_dm_i(usb_dn[0]), .usb_dp_i(usb_dp[0]),
        .usb_dm_o(usb_dm_o), .usb_dp_o(usb_dp_o), .usb_oe(usb_oe),
        .typ(usb_type), .full_report(),
        .connerr(), .busy(),
        .key_modifiers(key_modifiers),
        .key_0(key_0), .key_1(key_1), .key_2(key_2),
        .key_3(key_3), .key_4(key_4), .key_5(key_5),
        .mouse_btn(mouse_btn), .mouse_dx(), .mouse_dy(),
        .game_l(game_l), .game_r(game_r), .game_u(game_u), .game_d(game_d),
        .game_a(game_a), .game_b(game_b), .game_x(game_x), .game_y(game_y),
        .game_sel(), .game_sta(), .game_extra(),
        .dbg_hid_report(), .dbg_hid_regs(),
        .rom_addr(rom_addr), .rom_dout(rom_dout), .rom_en(rom_en)
    );

    usb_hid_host_rom rom (
        .clk(clk_usb), .addr(rom_addr), .dout(rom_dout), .en(rom_en)
    );

    // Show the current decoded input directly, without stretching or latching.
    always_comb begin
        led = 5'b0;
        if (sys_resetn) begin
            case (usb_type)
                2'd1: begin // keyboard
                    led[0] = |{key_0, key_1, key_2, key_3, key_4, key_5};
                    led[1] = |key_modifiers;
                end
                2'd2: led[2:0] = mouse_btn; // left, right, middle
                2'd3: begin // joystick/gamepad
                    led[0] = game_l;
                    led[1] = game_r;
                    led[2] = game_u;
                    led[3] = game_d;
                    led[4] = game_x | game_y | game_a | game_b;
                end
                default: led = 5'b0;
            endcase
        end
    end
endmodule

`default_nettype wire
