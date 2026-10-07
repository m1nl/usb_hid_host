`timescale 1ns/1ps

// Exercise SET_ADDRESS recovery with the production frame timer at several
// phases. Run with: python3 tb/test_control_read_status.py
module test;
  parameter FULL_SPEED = 1;
  parameter ENTRY = 0;
  localparam FRAME_CYCLES = FULL_SPEED ? 60000 : 12000;

  reg clk = 0, reset = 1;
  always #(FULL_SPEED ? 8.333333 : 41.666667) clk = ~clk;
  wire [9:0] addr;
  wire [3:0] inst;
  wire en;

  ukp #(.FULL_SPEED(FULL_SPEED)) dut (
    .clk(clk), .reset(reset), .cs(1'b1),
    .usb_dp_i(FULL_SPEED != 0), .usb_dm_i(FULL_SPEED == 0),
    .load_data(8'b0), .rom_addr(addr), .rom_dout(inst), .rom_en(en)
  );
  usb_hid_host_rom rom (
    .clk(clk), .addr(addr), .dout(inst), .en(en)
  );

  integer phase, idle_packets;
  integer prevstate = 0, nbytes = 0;
  reg [31:0] bytes;
  real started;

  initial begin
    for (phase = 0; phase < 3; phase = phase + 1) begin
      reset = 1;
      repeat (10) @(negedge clk);
      // Entry follows completion of the status ACK. No accelerated timing.
      reset = 0;
      dut.pc = ENTRY;
      dut.state = 0;
      dut.interval = phase == 0 ? 1 :
                     phase == 1 ? FRAME_CYCLES / 2 : FRAME_CYCLES - 20;
      rom.dout = rom.mem[ENTRY];
      prevstate = 0;
      nbytes = 0;
      bytes = 0;
      idle_packets = 0;
      started = $realtime;

      begin : recovery
        forever begin
          @(negedge clk);
          if (dut.state == 14 && prevstate != 14) begin  // S_TX2
            if (dut.insth == 6) begin  // OUTB
              bytes = (bytes << 8) | dut.sb;
              nbytes = nbytes + 1;
              // SETUP PID follows SYNC; fail as soon as SETUP begins.
              if (nbytes == 2 && dut.sb == 8'h2d) begin
                if ($realtime - started < 2000000.0)
                  $fatal(1, "SETUP too early: %0.3f ms",
                         ($realtime - started) / 1000000.0);
                if (idle_packets != 3)
                  $fatal(1, "Expected three SOFs/keep-alives, got %0d", idle_packets);
                $display("PASS address recovery: speed=%0d phase=%0d delay=%0.3f ms",
                         FULL_SPEED, phase, ($realtime - started) / 1000000.0);
                disable recovery;
              end
            end else if (dut.insth == 3) begin  // OUT4: EOP
              if (FULL_SPEED && (nbytes != 4 || bytes !== 32'h80a50010))
                $fatal(1, "Unexpected traffic during recovery: %h", bytes);
              if (!FULL_SPEED && nbytes != 0)
                $fatal(1, "Unexpected data during low-speed keep-alive");
              idle_packets = idle_packets + 1;
              bytes = 0;
              nbytes = 0;
            end
          end
          prevstate = dut.state;
        end
      end
    end
    $finish;
  end

  initial begin
    #12000000;
    $fatal(1, "Address recovery test timed out");
  end
endmodule
