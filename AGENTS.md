# Project notes for future runs

## Structure

- `rtl/usb_hid_host.v` contains both the public `usb_hid_host` module and the
  `ukp` microcode processor. There is no separate `rtl/ukp.v`.
- The host handles descriptor registers, endpoint selection, polling intervals,
  report storage, and keyboard/mouse/gamepad decoding. UKP handles USB signaling,
  instruction execution, speed detection, and byte strobes.
- `rom/ukp.s` is the microcode source. `rom/asukp.py` generates
  `rom/ukp.lst` and `rom/usb_hid_host_rom.mem`. Run it from `rom/`:
  `cd rom && python3 asukp.py`. Keep both generated files consistent with source.
- `rtl/usb_hid_host_rom.v` and `rtl/usb_hid_host_dual_rom.v` provide synchronous
  ROM interfaces. ROM capacity is 1024 nibbles; the refactored version reviewed
  on 2026-10-07 uses all 1024, so check capacity after microcode edits. Branch/call
  targets are aligned to four-nibble boundaries by the assembler.
- ROM loading uses a filename relative to the simulator's working directory.
  Ensure `usb_hid_host_rom.mem` is available there when running simulations.
- `Xilinx/` contains dual-port integration, reset synchronization, and timing/
  pin constraints. `README.md` covers hardware setup and tested devices.
- `examples/icepi-zero/` is the runnable ECP5 board example: `top.sv`, `pll.sv`,
  `icepi-zero.lpf`, and a Makefile. It uses a 50 MHz input and a 60 MHz USB PLL.
- `tb/` contains a cocotb wrapper, USB line driver, and an enumeration waveform
  exercise. It does not provide comprehensive assertions for decoded reports.
- Root `wow.v` was supplied as a previous 16-byte-buffer implementation for
  comparison. It defines the same module names as the active RTL; do not compile
  them together. Its availability/tracking may change between runs.

## Report handling and a verified regression fix

- `FULL_SPEED=1` requires a 60 MHz clock; `FULL_SPEED=0` requires 12 MHz.
- `typ`: 0 = no identified device, 1 = keyboard, 2 = mouse, 3 = gamepad.
  `typ_next` is derived from captured interface descriptors. `connected` becomes
  true when enumeration finishes; `typ` changes at the first received report.
- Descriptor registers 0..3 contain VID/PID, little-endian; 4..6 contain interface
  class/subclass/protocol. Enumeration relies on report-buffer wraparound.
- The reviewed host keeps eight storage bytes while polling up to 16 payload
  bytes. `report_mask` selects original byte offsets and packs selected bytes
  into `dat[]` using `dat_idx`. `rcvct` tracks original offsets; `crc_tail` is
  used to roll back the storage index at packet completion.
- Select enumeration's all-ones mask using `!connected`. During polling, choose
  device masks using `typ_next`, not `typ`: otherwise the first report gets the
  wrong layout. This was reproduced and fixed during the review.
- UKP can strobe CRC bytes for packets shorter than the requested receive length;
  it suppresses CRC strobes at the requested length limit. Check short packets,
  first reports, and packet boundaries when changing masks or counters.

## 8BitDo Micro mapping

For D-Input VID/PID `2dc8:9020`, mask `16'h0302` selects zero-based report bytes
1, 8, and 9 into `dat[0]`, `dat[1]`, and `dat[2]`, respectively.

- `dat[0][3]` disables directions when set; bits 2..0 encode the circular hat
  (0 = up, proceeding clockwise through 7 = up-left).
- A/B/X/Y use `dat[1]` bits 0/1/3/4, respectively.
- Select/Start use `dat[2]` bits 2/3.
- `game_extra[3:0]` = `{L2, L, R2, R}` =
  `{dat[2][0], dat[1][6], dat[2][1], dat[1][7]}`.
- This decoder was verified identical to the Micro block in `wow.v` after
  remapping original byte indices 1/8/9 to packed indices 0/1/2. This establishes
  equivalence to that implementation, not independent hardware validation.

## Useful verification

From the repository root:

```sh
verilator --lint-only -Wno-fatal --top-module usb_hid_host rtl/usb_hid_host.v
verilator --lint-only -Wno-fatal -GFULL_SPEED=0 --top-module usb_hid_host rtl/usb_hid_host.v
git diff --check
```

Run the existing cocotb bench from `tb/` with `make` after installing its
requirements in an appropriate environment. On the reviewed environment,
Icarus Verilog and Verilator were available, but `cocotb-config` was not on PATH.
Recheck tool availability instead of assuming this remains true.

`VERILATOR` changes UKP frame timing and disables its receive timeout for the
existing bench. Passing simulation under that define does not verify production
timing or timeout behavior. Focused Icarus simulations driving the host's UKP
interface verified first/subsequent mouse and Micro report equivalence; those
temporary harnesses were not added to the repository and did not test the PHY.

## ECP5 LUT optimization findings (2026-10-05)

The user's target is ECP5 and the priority is minimum LUT usage. Timing failures
are not a blocker for area exploration; record timing separately without making
it the selection criterion.

Use `examples/icepi-zero` to measure the actual implementation. The reviewed
example targets ECP5-25K / CABGA256, with full-speed and all three device classes
enabled. Its LED demo leaves debug ports, mouse movement, and some gamepad
outputs unused. Connecting more outputs can change synthesis results.

Run `make build` from that example for synthesis, nextpnr, and ecppack. Bare
`make` defaults to `debug`, which programs the board; `install` writes flash.
Use temporary mirrors for comparisons to preserve working sources and existing
bitstreams. For area experiments, `--timing-allow-fail` can be added to nextpnr.
The Makefile's JSON/config files are intermediates and may be deleted after a
successful build; `.SECONDARY:` in a temporary recipe preserves them.

Measurements used Yosys 0.68 and nextpnr-ecp5 0.10, with the original baseline
at commit `41275e6`. These are nextpnr **packed TRELLIS_COMB sites**, including
carry-chain and constant cells, rather than just Yosys `LUT4` cell counts:

| Configuration | Packed LUT sites |
|---|---:|
| Original RTL and default synthesis | 978 |
| Original RTL, `-nowidelut -noccu2` | 779 |
| Shared PC arithmetic, same flags | 725 |
| Shared PC arithmetic + parallel loads, same flags | 694 |

The best tested combination saved 29% of packed LUT sites, reduced flip-flops
from 335 to 332, and retained one EBR and one PLL. Recommended changes:

1. Use `synth_ecp5 -nowidelut -noccu2 -top top -json ...` for this example.
2. In UKP's combinational state machine, select `pc_step` as 0 for hold, 1 for
   normal advance, or 3 for skipping branch operands. Compute `pc + pc_step`
   once, with `pc_override` for reset, RET, and absolute branch targets. Preserve
   the original state transitions and return-stack handling.
3. Replace the `load_data` if/else chain with a single `case (addra)` covering
   0..7 (descriptor registers), 8..11 (endpoint payloads), 12 (X-Input), and
   13 (polling interval). Invalid addresses must continue holding `load_data`.

Results are sensitive to the top and mapping options: the load rewrite saved
only 10 sites by itself in the board example; its savings are not additive with
other changes. Binary FSM encoding reduced FFs but was worse than the selected
combination for packed LUTs. The ROM already infers one block RAM, so forcing
that mapping saved nothing. Explicit register banks, filter-count rewrites,
direct mask predicates, and `wk + 15` did not show consistent complete-design
savings. Do not narrow counters or specialize registers to the microcode without
checking packet-length/reachability assumptions and equivalence.

Verification of the combined RTL used flattened, memory-mapped gold/gate
designs, followed by `equiv_make`, `equiv_simple`, `equiv_induct -seq 4`, and
`equiv_status -assert`: all 755 matched equivalence points passed for
`FULL_SPEED=1`, including the external ROM interface. The actual example built
through ecppack in temporary copies. Its mapped netlist passed
`hierarchy -check` and `check -assert`. No hardware was programmed or tested.

For a separate mapped-netlist check, read the top module from JSON together with
Yosys's ECP5 primitive libraries. In the reviewed Yosys installation these are
`+/lattice/cells_sim_ecp5.v` and `+/lattice/cells_bb_ecp5.v`. The synthesis JSON
also contains primitive module stubs: filter it to `top` before loading it with
those libraries to avoid duplicate definitions or missing parameter metadata.

Detailed experiment artifacts are in `/tmp/usb_hid_lut_review/`: `REPORT.md`,
`recommended.patch`, `board_summary.json`, synthesis/equivalence scripts and
logs, and `board_loadpc_nocarry/` with the selected build. These files are
temporary; the algorithms and measurements above are the persistent record.
Re-measure after RTL, top-level, or toolchain changes.

## TMK enumeration and microcode review (2026-10-07)

The user's priority remains minimum implementation size/LUT usage. They
deliberately omit receive CRC checking for simplicity. Do not introduce separate
timeout and STALL handling merely for protocol completeness: the user accepted
a combined failure flag when the chosen policy is reset and enumerate again.
Separate flags were discussed but not implemented.

### TMK findings

- `tmk.txt` is the supplied `lsusb -v` dump for `feed:0adb`, the TMK ADB converter.
  `tmk_keyboard/` contains firmware and its LUFA submodule. Both are currently
  untracked user inputs; do not accidentally include them in commits.
- The converter's three interfaces are keyboard 0 / IN endpoint `0x81`, mouse
  1 / `0x82`, and debug console 2 / `0x83`. The user only needs the keyboard.
  Interface 0 matches the host's fixed interface selection and endpoint 1.
- The keyboard sends eight-byte 6KRO reports without a report ID. Its format
  matches the existing decoder. Focused host-interface Icarus tests passed
  first/subsequent keyboard reports and exclusion of strobed CRC bytes; these
  bypassed the PHY and did not establish hardware compatibility.
- The main reproduced enumeration failure was missing OUT status after
  GET_DESCRIPTOR. USB control reads finish with OUT to endpoint 0, zero-payload
  DATA1 (empty-payload CRC16 bytes `00 00`), then the device handshake. Use the
  current device address, not always address 0.
- In TMK's LUFA revision `d6a7df4f78898957fa6d5b63e62015ce763560d4`, the control
  stream waits for OUT status. A new SETUP aborts that stream, after which
  `USB_Device_ProcessControlRequest()` can clear the new SETUP and stall EP0.
  A mock-endpoint reproduction using actual LUFA function code demonstrated
  this request-loss path and avoided it when OUT status was supplied. No USB
  trace or hardware validation was performed.

### Active fixes and refactor

- Descriptor registers are saved before `status_read00`, since receive traffic
  can alter `dat[]`. Device/configuration reads now finish with OUT status and
  retry NAK; their combined STALL/timeout failure restarts enumeration.
- SET_ADDRESS recovery crosses three frame boundaries after the status ACK:
  the first boundary may represent only a partial millisecond. SOF/keep-alive
  traffic continues, and the next address-1 request is delayed at least 2ms.
- `get_hid_report` was initially commented out to free space, then restored in
  the active refactor (`bd0c83f`). It still requests only nine descriptor bytes
  and ignores their contents; this is not HID report-descriptor parsing. A
  successful read calls `status_read10`; its STALL path skips the status stage.
- `read_control00` shares the device/configuration receive loop. `control_in10`
  receives one address-1 control packet, retries NAK, and returns failure flags
  without ACKing STALL. Callers supply the remaining receive count in `wk` and
  decide whether to loop, skip an optional request, or abort. SET_CONFIGURATION
  now checks the returned combined failure flag.
- `setup_frame00` / `setup_frame10` share SETUP scheduling. `frame` uses
  `wait; bjmp sof`. Outgoing request routines tail-jump to `rcvdt` after EOP/HIZ,
  eliminating repeated receive calls at their call sites. `status_zlp` shares
  the DATA1 zero-length packet and tail-jumps to `rcvdt`.
- UKP has only two return-stack entries. Use tail jumps to avoid a third nested
  CALL. Keep outgoing packet bytes contiguous: splitting byte runs or moving
  EOP behind extra CALL/branch instructions can disturb serializer bit timing.
  That was a design concern, not a fully measured timing result for every
  rejected candidate.
- Measured assembler sizes, including alignment: prior working source 1008
  nibbles; naive restored read plus address-1 status 1148; shared refactor 1020;
  refactor plus SET_CONFIGURATION failure check 1024. The active source uses
  the last combination and has no spare ROM nibbles. The assembler does not
  enforce capacity; always check the generated image and branch targets.

### Verification and limitations

- `python3 tb/test_control_read_status.py` assembles a temporary copy, checks
  generated files for consistency/capacity, and runs standalone Icarus tests
  without cocotb. `control_read_status_tb.v` checks ACK, NAK retry, STALL, and
  production receive timeout. It accelerates the frame timer and disables the
  watchdog, so it does not validate production frame/watchdog behavior.
- `address_recovery_tb.v` uses the production frame timer at three initial
  phases for both FULL_SPEED settings. The measured recovery delays were about
  2.004..3.004ms at full speed and 2.012..3.010ms at low speed.
- IMPORTANT: the current runner needs a test-only correction after the ROM
  became full. It sets RETURN to `prgend`, which is now `0x400`; the 10-bit PC
  wraps this sentinel to zero. The current test fails after returning into
  unrelated code (observed `Bad SOF 00000000`). Prototype status tests passed
  using an in-range sentinel `1023`, for OUT status at addresses 0 and 1, at
  both speeds. Do not mistake the runner's sentinel failure for a demonstrated
  protocol regression. The committed runner currently tests only address 0.
- Temporary artifacts: `/tmp/tmk_hid_review/` contains the LUFA reproduction,
  host report test, and focused timing exercises. `/tmp/ukp_rom_refactor/`
  contains measured candidates, `recommended.patch`, `recommended/` with the
  refactored source/listing/ROM, and `check.py` with the prototype checks.
  Temporary files may disappear; the active repository is the source of truth.
- Focused receive-to-ACK timing exercises measured about 4.7 full-speed and
  4.3 low-speed bit times for selected paths in the pre-refactor microcode.
  These were not exhaustive timing tests of the active refactor. No complete
  device enumeration simulation, formal equivalence, or hardware test of the
  refactor was performed.

### Remaining protocol work discussed, not implemented

- UKP still initializes `stall=1` at receive start, making timeout and STALL
  indistinguishable. It recognizes PID low nibbles without checking PID
  complements or explicitly requiring the expected ACK/DATA response type.
- SETUP handshakes remain unchecked. SET_ADDRESS status and interrupt polling
  still lack a failure check before `sendack`; their recovery is less reliable
  than the updated mandatory configuration/descriptor paths.
- Optional SET_IDLE/SET_PROTOCOL requests skip combined STALL/timeout failures.
  This is the current compatibility policy, not proof of request success.
- Short-packet termination and DATA0/DATA1 duplicate suppression remain missing.
  SOF frame number remains constant zero. XInput's vendor control read still
  lacks the final address-1 OUT status stage.
- USB reference sections: 8.4.6.4 (SETUP response), 8.5.3/8.5.3.1 (control
  status), 8.5.3.2 (short packets), 8.6 (toggles), 9.2.6.2/3 (reset/address
  recovery), and 7.1.18.1 (inter-packet delay) in the USB 2.0 specification.
