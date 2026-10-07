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
- The status runner uses in-range return sentinel `1023` and tests OUT status
  at addresses 0 and 1, at both speeds. Previously it used `prgend=0x400`,
  which wrapped the 10-bit PC to zero and failed in unrelated code with
  `Bad SOF 00000000`; that was a test failure rather than a protocol regression.
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

## UKP receive bit-stuffing regression fix (2026-10-07)

- The user reproduced random `game_u` / `game_d` activation during small
  horizontal analog-stick movements on an 8BitDo Pro 3. Larger deflections
  behaved reliably. After applying the fix below, the user confirmed on
  hardware that bit stuffing was the cause and the symptom was resolved.
- In UKP's sampling block in `rtl/usb_hid_host.v`, a stuffed bit is discarded
  when `nrzrxct == 6`, holding `bitaddr` and the receive shift register. The old
  byte-strobe condition checked only `ukprdy` and `bitaddr[2:0] == 0`. If the
  stuffed bit fell immediately after a byte boundary, it strobed the completed
  byte on both the stuffed bit and the following data bit. This duplicated a
  byte, shifted report offsets, and could corrupt the packed axis mapping.
- The active fix requires `nrzrxct != 6` in the byte-strobe condition as well:
  `if (ukprdy && nrzrxct != 6 && bitaddr[2:0] == 3'b000)`.
  Preserve this guard when changing receive logic. Test stuffing at byte
  boundaries, not just stuffing within a byte. This defect can affect full
  packets; it does not require CRC bytes to enter the report buffer.
- A focused Icarus reproduction showed two strobes for one completed byte
  before the fix and one afterward. A 16-byte stream containing six stuffed
  bits passed byte-for-byte checks with both FULL_SPEED parameter settings;
  the original RTL failed at byte 8, duplicating byte 7 (`fc`) instead of
  receiving byte 8 (`80`). These tests forced internal sample/NRZI signals,
  bypassing the line filters, clock recovery, and production timing.
- Host RTL lint passed for both FULL_SPEED settings, and a temporary copy of
  the IcePi Zero example built through Yosys, nextpnr, and ecppack. Artifacts
  are in `/tmp/usb_stuff_boundary/`; they are temporary, not committed tests.
- The board example's added direction latch was repaired by declaring
  `game_l_r`, `game_r_r`, `game_u_r`, and `game_d_r` (rather than redeclaring
  the host output wires), resetting them, and sampling on `full_report`.
  The temporary `|dat[6]` LED checks were replaced by the original signed
  Y-axis threshold expressions. The user's XInput report mask `16'h02bd`
  packs original offsets 0/2/3/4/5/7/9 into `dat[0]` through `dat[6]`, so
  `dat[5]` / `dat[6]` hold left-stick X/Y high bytes.
- A strobe count alone does not always establish payload length: 16 strobes
  can represent 16 payload bytes with CRC strobes suppressed at the receive
  limit, or 14 payload bytes plus two strobed CRC bytes. Consult receive-limit
  state or capture USB traffic to distinguish these cases. Reaching the
  host's 16-byte limit also does not prove the device's entire report is only
  16 bytes long.

## Arduino / SparkFun keyboard profile (2026-10-07)

- The user explicitly requested VID-only recognition for `2341` and `1b4f`,
  regardless of PID, assuming standard AVR CDC+Keyboard firmware. The shared
  registered `arduino_keyboard` predicate is gated by `KEYBOARD_SUPPORT` and the
  default-on `FORCE_ARDUINO_KEYBOARD` parameter and overrides
  `typ_next=1`, selects IN endpoint 4 (`01 ba`), and chooses mask `01fe`.
  Enumeration must retain its all-ones mask until connected.
  It also requires captured configuration bytes `02/00/00` to exclude the
  standard Caterina bootloader's `02/02/01` layout. This tests the expected
  CDC association layout; it does not independently establish HID presence.
- Arduino Keyboard 1.0.7 sends ID 2 plus the ordinary eight-byte key payload.
  Standard AVR HID advertises `03/00/00`; SET_PROTOCOL only stores a variable
  and does not strip the report ID. CDC precedes HID, so the fixed 18-byte
  configuration read captures `02/00/00` from the IAD. The VID override bypasses
  that classification failure without a configuration scanner or ROM changes.
- Standard HID is interface 2 / IN endpoint 4 with CDC enabled and no earlier
  pluggable modules. Current optional HID requests still address interface 0;
  their STALLs are skipped under the existing policy. Keyboard reports do not
  require those optional requests to succeed.
- This assumes Keyboard is the only HID report producer. It is not generic
  detection for all firmware sharing those VIDs, does not filter report IDs,
  and does not cover CDC-disabled or rearranged composite layouts.
- `python3 tb/test_arduino_keyboard.py` checks both VIDs with multiple PIDs,
  support disabled, descriptor capture/acceptance, endpoint/masks, first and
  subsequent reports, six keys/modifiers/releases and CRC exclusion, plus a
  nonmatching boot keyboard control. It bypasses UKP/PHY. Status/recovery tests
  and lint at both speeds pass; hardware compatibility remains untested.
  The runner also tests all combinations of keyboard support and force flag,
  including ordinary boot reports on an Arduino VID with forcing disabled.
- Current IcePi Zero Makefile (`-abc9`) builds in temporary copies measured
  packed TRELLIS_COMB sites 812 -> 831 and FFs 347 -> 348; one EBR/PLL retained.
  Both completed ecppack, final timing estimates 64.71 -> 64.96 MHz at 60 MHz.
  Artifacts: `/tmp/promicro_vid_profile/`; details: `doc/promicro-keyboard-review.md`.
- Packing the profile into existing `casez` blocks was measured with the same
  top/flags: direct VID entries cost 884 packed sites, and a shared predicate
  added to case selectors cost 866, versus 831 for the selected separate
  override/conditional-mask arrangement. All used 348 FFs. Keep the selected
  arrangement for LUT area under this mapping. Both alternatives passed
  focused keyboard tests; the shared-predicate case form passed all 764 Yosys
  equivalence points at FULL_SPEED=1.
- Registering IN/OUT payloads after the Arduino profile still increased area
  under the current `-abc9` recipe (Yosys 0.69 / nextpnr 0.11.1): combinational
  831 sites/348 FFs; IN registered 882/350; OUT registered 850/350; both 895/352.
  All built through ecppack and passed focused keyboard tests. Combined variant
  lint passed at both speeds. Keep payloads combinational for the measured area
  target. Artifacts: `/tmp/usb_payload_register_review/`; no formal or hardware
  equivalence claim for these one-cycle-latency experiments.
- After adding `FORCE_ARDUINO_KEYBOARD`, a fresh current-source area comparison
  measured VID-only profile 857 packed sites/348 FFs versus 861/348 when also
  requiring captured config bytes `02/00/00` (+4 sites). This can reject the
  standard Caterina CDC interface tuple `02/02/01`, but does not prove HID is
  present. That initial guard was experimental; the registered version below
  is now applied. Both builds completed
  ecppack; artifacts: `/tmp/arduino_descriptor_guard/`.
- Registering the guarded `arduino_keyboard` predicate saves area: guarded
  combinational 861 sites/348 FFs versus registered 823/349. Both completed
  ecppack; final timing 64.35/64.28 MHz. Selected registered version is applied,
  with no separate reset (it follows cleared descriptor registers next clock).
  Payloads remain combinational and ROM is unchanged. Focused tests now cover
  Caterina prefix rejection followed by application prefix/report acceptance
  on both VIDs; this bypasses PHY and does not validate physical reconnect.
  Artifacts: `/tmp/arduino_keyboard_register/`.
- User supplied NicoHood HID-Project 2.8.4 in untracked `hid/` and confirmed
  using its `Keyboard` API (not BootKeyboard). Its multi-report Keyboard has
  default ID 2 plus the same eight-byte key payload, using the AVR core HID
  transport. Current profile matches when CDC is enabled and Keyboard is the
  only HID producer, with no earlier pluggable modules. No extra RTL change
  was needed. HID-Project BootKeyboard has no report ID and fails the `01fe`
  mask; NKRO APIs use bitmaps and are unsupported. See the persistent review.
