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

`default_nettype none
`timescale 1ns / 1ps
module usb_hid_host_dual_rom(
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
  $readmemh("usb_hid_host_rom.mem", mem);

always @(posedge clk)
  if (ena)
    douta <= mem[addra];

always @(posedge clk)
  if (enb)
    doutb <= mem[addrb];

endmodule
`default_nettype wire
// vim:ts=2 sw=2 tw=120 et
