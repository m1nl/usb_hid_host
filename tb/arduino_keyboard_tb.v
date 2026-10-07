`timescale 1ns/1ps

// Host-interface regression: source-derived AVR CDC+Keyboard descriptors and
// nine-byte reports. UKP/PHY are bypassed; no protocol timing claim is made.
module test;
  parameter KEYBOARD_SUPPORT = 1;
  parameter FORCE_ARDUINO_KEYBOARD = 1;
  localparam PROFILE_ENABLED = KEYBOARD_SUPPORT && FORCE_ARDUINO_KEYBOARD;
  reg clk = 0, reset = 1;
  always #5 clk = ~clk;
  reg ready = 0, strobe = 0, start = 0, connected = 0, save = 0, load = 0;
  reg [7:0] value = 0;
  reg [3:0] a = 0, b = 0;
  wire [1:0] typ;
  wire full_report;
  wire [7:0] modifiers, k0, k1, k2, k3, k4, k5;
  usb_hid_host #(.KEYBOARD_SUPPORT(KEYBOARD_SUPPORT),
                 .FORCE_ARDUINO_KEYBOARD(FORCE_ARDUINO_KEYBOARD)) dut (
    .clk(clk), .reset(reset), .cs(1'b0),
    .usb_dp_i(1'b1), .usb_dm_i(1'b0), .rom_dout(4'b0),
    .typ(typ), .full_report(full_report), .key_modifiers(modifiers),
    .key_0(k0), .key_1(k1), .key_2(k2), .key_3(k3), .key_4(k4), .key_5(k5)
  );
  reg [7:0] config_prefix [0:17];
  integer i, profile;
  reg [15:0] vendor, product;

  task tick; begin @(negedge clk); end endtask
  task begin_packet;
    begin start = 1; tick; start = 0; ready = 1; end
  endtask
  task byte_in(input [7:0] x);
    begin value = x; strobe = 1; tick; strobe = 0; tick; end
  endtask
  task end_packet;
    begin
      ready = 0; tick;
      if (connected && !full_report) $fatal(1, "Missing report pulse");
      repeat (2) tick;
    end
  endtask
  task save_reg(input [3:0] ra, input [3:0] rb);
    begin a = ra; b = rb; save = 1; tick; save = 0; tick; end
  endtask
  task key_report(input bit has_id, input [7:0] mods, input [7:0] first_key);
    begin
      begin_packet;
      if (has_id) byte_in(2);
      byte_in(mods); byte_in(0);
      for (i = 0; i < 6; i = i + 1) byte_in(first_key == 0 ? 0 : first_key + i);
      // Both report sizes are below the 16-byte receive limit, so CRC strobes
      // occur. Their values must not alter the selected eight payload bytes.
      byte_in(8'hac); byte_in(8'hdb);
      end_packet;
      if (typ !== 1 || modifiers !== mods || k0 !== first_key ||
          k1 !== (first_key == 0 ? 0 : first_key + 1) ||
          k2 !== (first_key == 0 ? 0 : first_key + 2) ||
          k3 !== (first_key == 0 ? 0 : first_key + 3) ||
          k4 !== (first_key == 0 ? 0 : first_key + 4) ||
          k5 !== (first_key == 0 ? 0 : first_key + 5))
        $fatal(1, "Keyboard decode failed: vendor=%h modifiers=%h keys=%h%h%h%h%h%h",
               vendor, modifiers, k0, k1, k2, k3, k4, k5);
    end
  endtask

  initial begin
    force dut.connerr = 0;
    force dut.ukprdy = ready;
    force dut.ukpstb = strobe;
    force dut.ukpstart = start;
    force dut.ukpdat = value;
    force dut.connected = connected;
    force dut.save = save;
    force dut.load = load;
    force dut.addra = a;
    force dut.addrb = b;
    // Configuration(9), CDC IAD(8), first interface length(1).
    config_prefix[0]=9; config_prefix[1]=2; config_prefix[2]=100; config_prefix[3]=0;
    config_prefix[4]=3; config_prefix[5]=1; config_prefix[6]=0;
    config_prefix[7]=8'ha0; config_prefix[8]=50;
    config_prefix[9]=8; config_prefix[10]=11; config_prefix[11]=0;
    config_prefix[12]=2; config_prefix[13]=2; config_prefix[14]=2;
    config_prefix[15]=0; config_prefix[16]=0; config_prefix[17]=9;

    for (profile = 0; profile < 4; profile = profile + 1) begin
      vendor = profile < 2 ? 16'h2341 : 16'h1b4f;
      product = profile % 2 == 0 ? 16'h8036 : 16'hffff;
      reset = 1; connected = 0; repeat (3) tick;
      reset = 0; repeat (3) tick;
      // Sixteen-byte device descriptor; VID/PID at offsets 8..11.
      begin_packet;
      for (i = 0; i < 16; i = i + 1) begin
        case (i)
          8: byte_in(vendor[7:0]); 9: byte_in(vendor[15:8]);
          10: byte_in(product[7:0]); 11: byte_in(product[15:8]);
          default: byte_in(0);
        endcase
      end
      end_packet;
      save_reg(0,0); save_reg(1,1); save_reg(2,2); save_reg(3,3);
      begin_packet;
      for (i = 0; i < 18; i = i + 1) byte_in(config_prefix[i]);
      end_packet;
      save_reg(4,6); save_reg(5,7); save_reg(6,0);
      repeat (3) tick;
      if ({dut.regs[4],dut.regs[5],dut.regs[6]} !== 24'h020000 ||
          dut.report_mask !== 16'hffff)
        $fatal(1, "Enumeration capture/mask failed");
      a = 14; load = 1; tick; load = 0;
      if (dut.load_data !== (PROFILE_ENABLED ? 8'd1 : 8'd0) ||
          dut.typ_next !== (PROFILE_ENABLED ? 2'd1 : 2'd0) || dut.x_input !== 0 ||
          {dut.in_payload[0],dut.in_payload[1]} !==
          (PROFILE_ENABLED ? 16'h01ba : 16'h8158))
        $fatal(1, "Profile classification/endpoint/acceptance failed");
      connected = 1; repeat (4) tick;
      if (dut.report_mask !== (PROFILE_ENABLED ? 16'h01fe : 16'h00ff))
        $fatal(1, "Polling mask failed");
      if (PROFILE_ENABLED) begin
        key_report(1, 8'h01, 4);  // first report, with all six keys
        key_report(1, 8'h80, 20); // subsequent report and different modifier
        key_report(1, 0, 0);     // release
      end
      $display("PASS Arduino profile: VID=%h PID=%h KEYBOARD_SUPPORT=%0d FORCE=%0d",
               vendor, product, KEYBOARD_SUPPORT, FORCE_ARDUINO_KEYBOARD);
      // Caterina: config header + first CDC interface, without an IAD.
      // Keep VID/PID unchanged to isolate rejection by descriptor layout.
      connected = 0; repeat (3) tick;
      begin_packet;
      byte_in(9); byte_in(2); byte_in(62); byte_in(0); byte_in(2);
      byte_in(1); byte_in(0); byte_in(8'h80); byte_in(50);
      byte_in(9); byte_in(4); byte_in(0); byte_in(0); byte_in(1);
      byte_in(2); byte_in(2); byte_in(1); byte_in(0);
      end_packet;
      save_reg(4,6); save_reg(5,7); save_reg(6,0);
      repeat (3) tick;
      a = 14; load = 1; tick; load = 0;
      if ({dut.regs[4],dut.regs[5],dut.regs[6]} !== 24'h020201 ||
          dut.arduino_keyboard !== 0 || dut.typ_next !== 0 || dut.load_data !== 0 ||
          {dut.in_payload[0],dut.in_payload[1]} !== 16'h8158 ||
          dut.report_mask !== 16'hffff)
        $fatal(1, "Bootloader descriptor accepted");
      // Replace it with the sketch descriptor, retaining the same device ID.
      begin_packet;
      for (i = 0; i < 18; i = i + 1) byte_in(config_prefix[i]);
      end_packet;
      save_reg(4,6); save_reg(5,7); save_reg(6,0);
      repeat (3) tick;
      a = 14; load = 1; tick; load = 0;
      if (dut.load_data !== (PROFILE_ENABLED ? 8'd1 : 8'd0))
        $fatal(1, "Application not accepted after bootloader descriptor");
      connected = 1; repeat (4) tick;
      if (PROFILE_ENABLED) begin key_report(1, 1, 4); key_report(1, 0, 0); end
      $display("PASS bootloader rejection and application descriptor transition");
    end

    // Nonmatching VID still uses the ordinary eight-byte boot layout.
    reset = 1; connected = 0; repeat (3) tick; reset = 0;
    vendor = 16'hfeed;
    dut.regs[0]=8'hed; dut.regs[1]=8'hfe;
    dut.regs[4]=3; dut.regs[5]=1; dut.regs[6]=1;
    repeat (3) tick;
    connected = 1; repeat (4) tick;
    if ({dut.in_payload[0],dut.in_payload[1]} !== 16'h8158 || dut.report_mask !== 16'h00ff)
      $fatal(1, "Default endpoint/mask changed");
    if (KEYBOARD_SUPPORT) begin key_report(0, 2, 4); key_report(0, 0, 0); end
    $display("PASS nonmatching boot keyboard control");
    if (KEYBOARD_SUPPORT && !FORCE_ARDUINO_KEYBOARD) begin
      // Disabling the override retains ordinary HID support on matching VIDs.
      connected = 0; vendor = 16'h2341;
      dut.regs[0]=8'h41; dut.regs[1]=8'h23;
      repeat (3) tick; connected = 1; repeat (4) tick;
      if (dut.typ_next !== 1 || dut.report_mask !== 16'h00ff ||
          {dut.in_payload[0],dut.in_payload[1]} !== 16'h8158)
        $fatal(1, "Disabled override changed ordinary HID handling");
      key_report(0, 1, 10); key_report(0, 0, 0);
      $display("PASS matching VID boot keyboard with override disabled");
    end
    $finish;
  end
  initial begin #100000; $fatal(1, "Test timeout"); end
endmodule
