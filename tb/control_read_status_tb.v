`timescale 1ns/1ps

// Focused status-stage test using the production UKP and synchronous ROM.
// Run with: python3 tb/test_control_read_status.py
module test;
  parameter FULL_SPEED = 1;
  parameter ENTRY = 0, ERROR = 0, RETURN = 0;
  localparam BIT_CYCLES = FULL_SPEED ? 5 : 8;

  reg clk = 0, reset = 1, dp = 1, dm = 0;
  always #8.333 clk = ~clk;

  wire [9:0] addr;
  wire [3:0] inst;
  wire en;

  ukp #(.FULL_SPEED(FULL_SPEED)) dut (
    .clk(clk), .reset(reset), .cs(1'b1),
    .usb_dp_i(dp), .usb_dm_i(dm), .load_data(8'b0),
    .rom_addr(addr), .rom_dout(inst), .rom_en(en)
  );
  usb_hid_host_rom rom (
    .clk(clk), .addr(addr), .dout(inst), .en(en)
  );

  localparam S_OPCODE = 0, S_RX0 = 10, S_RX1 = 11, S_TX2 = 14;
  integer prevstate = S_OPCODE, packet = 0, nbytes = 0;
  integer responses = 0, mode;
  reg [31:0] bytes;

  task tick;
    begin
      @(negedge clk);
    end
  endtask

  // ACK/NAK/STALL and SYNC never require bit stuffing.
  task bitout(input bit b);
    begin
      if (!b) begin
        dp = ~dp;
        dm = ~dm;
      end
      repeat (BIT_CYCLES) tick;
    end
  endtask

  task byteout(input [7:0] b);
    integer i;
    begin
      for (i = 0; i < 8; i = i + 1)
        bitout(b[i]);
    end
  endtask

  task handshake(input [7:0] pid);
    begin
      repeat (5) tick;
      byteout(8'h80);
      byteout(pid);
      dp = 0;
      dm = 0;
      repeat (2 * BIT_CYCLES) tick;
      dp = FULL_SPEED;
      dm = !FULL_SPEED;
      repeat (BIT_CYCLES) tick;
    end
  endtask

  // Check the bytes handed to the serializer, including both CRC fields.
  always @(negedge clk) begin
    if (reset) begin
      prevstate = S_OPCODE;
      packet = 0;
      nbytes = 0;
      bytes = 0;
    end else begin
      if (dut.state == S_TX2 && prevstate != S_TX2) begin
        if (dut.insth == 6) begin  // OUTB
          bytes = (bytes << 8) | dut.sb;
          nbytes = nbytes + 1;
        end else if (dut.insth == 3) begin  // OUT4: EOP
          case (packet % 3)
            0: begin
              if (FULL_SPEED && (nbytes != 4 || bytes !== 32'h80a50010))
                $fatal(1, "Bad SOF %h", bytes);
              if (!FULL_SPEED && nbytes != 0)
                $fatal(1, "Low-speed keep-alive contains data");
            end
            1: begin
              if (nbytes != 4 || bytes !== 32'h80e10010)
                $fatal(1, "Bad OUT status token %h", bytes);
            end
            2: begin
              if (nbytes != 4 || bytes !== 32'h804b0000)
                $fatal(1, "Bad DATA1 ZLP %h", bytes);
            end
          endcase
          packet = packet + 1;
          bytes = 0;
          nbytes = 0;
        end
      end
      prevstate = dut.state;
    end
  end

  initial begin
    // Accelerate WAIT only; production receive timeout remains enabled.
    force dut.interval_frame = 1;
    // Avoid watchdog expiration with the artificially accelerated frame clock.
    force dut.conct = 0;

    // 0: ACK, 1: NAK then ACK, 2: STALL, 3: no response.
    for (mode = 0; mode < 4; mode = mode + 1) begin
      reset = 1;
      dp = FULL_SPEED;
      dm = !FULL_SPEED;
      repeat (10) tick;
      reset = 0;
      // Enter the routine as if called by enumeration. Its nested calls must
      // preserve this return address using the actual two-entry UKP stack.
      dut.pc = ENTRY;
      dut.state = S_OPCODE;
      dut.wpc[0] = RETURN;
      rom.dout = rom.mem[ENTRY];
      responses = 0;

      fork : scenario
        begin : device
          forever begin
            wait (dut.state == S_RX0);
            responses = responses + 1;
            case (mode)
              0: handshake(8'hd2);
              1: handshake(responses == 1 ? 8'h5a : 8'hd2);
              2: handshake(8'h1e);
              3: repeat (120) tick;
            endcase
            wait (dut.state != S_RX0 && dut.state != S_RX1);
          end
        end
        begin : check
          wait ((dut.pc == RETURN || dut.pc == ERROR) && dut.state == S_OPCODE);
          if (mode < 2) begin
            if (dut.pc != RETURN || packet != (mode == 0 ? 3 : 6) ||
                responses != (mode == 0 ? 1 : 2))
              $fatal(1, "ACK/NAK failure: mode=%0d packets=%0d responses=%0d pc=%h",
                     mode, packet, responses, dut.pc);
          end else if (dut.pc != ERROR || packet != 3) begin
            $fatal(1, "Error handling failure");
          end
          $display("PASS speed=%0d mode=%0d packets=%0d responses=%0d",
                   FULL_SPEED, mode, packet, responses);
        end
      join_any
      disable scenario;
    end
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "Test timeout: state=%0d pc=%h", dut.state, dut.pc);
  end
endmodule
