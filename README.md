## usb_hid_host

**a compact USB HID host core supporting low-speed and full-speed devices**

- Original work by nand2mario, 8/2023
- Redesign by m1nl, 2/2026

This is based on the USB-HID work in:
- [hi631's NES core for Tang Nano 9K](https://qiita.com/hi631/items/4f263ca676e4be14b9f8)
- [UKP in FPGA pc8001](http://kwhr0.g2.xrea.com/hard/pc8001.html)
- [Original usb_hid_host core](https://github.com/nand2mario/usb_hid_host/)

Huge thanks to the authors.

## Design overview

This core is built to handle USB keyboards, mice and gamepads because I found no suitable options for pure FPGA hardware solution.

The features of the design are:
  * A small and efficient USB host controller core capable of supporting common HID devices such as keyboards, mice and gamepads.
  * No CPU is required. The core handles all layers of the USB protocol relevant to HID devices.
  * No USB interface IC (PHY) needed. The core communciates directly through the D+/D- USB pins.
  * USB low-speed (1.5Mbps) and full-speed (12Mbps) support, utilizing a single 12MHz or 96MHz clock.

To make USB work is actually tricky. USB is designed to be implemented with both hardware and software. So a CPU is normally needed. The UKP and hi631's design uses a tiny microcode processor to be just able to support keyboards and a specific gamepad. This core extended the original design by adding mouse support, automatic detecting all three types of devices, and accomodating various types of gamepads. Then support for full-speed USB has been added - this involved complete redesign of the original code so it could support bigger frames (more than 8 bytes of data), USB full-speed / low-speed negotiation and additional USB transactions (`SET_IDLE`, `GET_DESCRIPTOR / DEVICE` and `GET_DESCRIPTOR / HID`).

## Major differences from original usb_hid_host

This redesigned core differs significantly from the [original implementation](https://github.com/nand2mario/usb_hid_host/):

### General architecture
- **Complete HDL rewrite** with UKP state machine moved into separate combinatorial and sequential processes supporting both low-speed (12MHz) and full-speed (96MHz) operation
- **External ROM interface** replacing embedded ROM, allowing easier microcode updates
- **Module interface changes**: separate input/output signals (`usb_dm_i/o`, `usb_dp_i/o`, `usb_oe`), renamed signals (`report` → `full_report`, `key1-4` → `key_0-3`), added `cs`, `busy`, `dbg_hid_regs`
- **FULL_SPEED parameter** for conditional full-speed support with clock prescaler for low-speed devices

### Microcode and USB protocol
- **Expanded UKP microcode** with additional enumeration steps:
  - `GET_DESCRIPTOR / DEVICE` transaction to capture VID/PID
  - `SET_IDLE` transaction with `STALL` response handling
  - `GET_DESCRIPTOR / HID` transaction
- **Xbox 360-compatible gamepad initialization** with vendor-specific transactions:
  - LED control packet (`XINPUT_LED`) required by 8BitDo controllers
  - Magic initialization packet (`XINPUT_INIT`) required by third-party controllers
  - Conditional enumeration path based on interface protocol detection
- **New microcode instructions**: `OUTR` (output register), `SAVE` (save to register), `LOAD` (load from register), `BSTALL` (branch on STALL), `BNF` (branch if not full-speed), `BZ` (branch if zero), `BJMP` (unconditional branch), enhanced `BE` (speed detection)
- **Device-specific endpoint polling** using captured VID (e.g., 8BitDo uses endpoint 4 vs standard endpoint 1)
- **SOF frame generation** every 1ms for full-speed devices

### Device support
- **VID/PID-based HID report mapping** for improved gamepad compatibility:
  - 8BitDo controllers in X-Input mode: D-pad and button mappings
  - 8BitDo controllers in D-Input mode (VID 0x2dc8): custom HAT switch decoding, shoulder button mapping
  - Speedlink Competition PRO (VID 0x040b, 0x0738): joystick position interpretation
  - Generic fallback for standard gamepad layouts

## Lessons learned and tips for further development

- some devices won't send HID reports unless enumerated same way standard PC does it - so after `SET_CONFIGURATION`, `SET_IDLE` and `GET_DESCRIPTOR / HID` transactions have to follow
- full-speed devices send packets of different lengths so we cannot make assumptions about their size - I noted that Speedlink joystick is able to send entire packet in a single frame, whereas Logitech wireless keyboard splits packets into 8-byte frames (both full-speed)
- we need to support `STALL` response as some low-speed devices do not support `SET_IDLE` request and enumeration fails
- full-speed devices need `SOF` transaction being sent every 1ms; they don't care about the frame number though :)
- some devices use non-standard endpoint numbers - i.e. 8BitDo controllers use endpoint 4 for HID or Xbox 360-compatible endpoint
- Xbox 360-compatible gamepads require vendor-specific initialization sequence (see [linux xpad driver](https://github.com/torvalds/linux/blob/master/drivers/input/joystick/xpad.c) and [Jakob's blog post](https://jakob.space/blog/sorry-guys-i-have-to-troubleshoot-my-usb-drivers-before-i-can-play.html))

## Hardware design

The updated core has been tested with EBAZ4205 board ( https://github.com/XyleMora/EBAZ4205 , https://github.com/m1nl/ebaz4205-hdmi-demo ). The following devices has been validated and they're working properly:
- 8BitDo Ultimate 2C Wireless Pad in D-Input (legacy) and X-Input (Xbox 360-compatible mode)
- Logitech keyboard with Logitech Unifying receiver
- SpeedLink Competition PRO Extra
- old Logitech low-speed USB mouse

![ebaz4205 testing](doc/ebaz4205_test.jpg?raw=true "ebaz4205 testing")

96MHz clock has been generated with PLL.

Sample connection guide has been provided nand2mario with the original version of the core. I didn't validate if it works with Tang Nano, I used direct USB <-> GPIO connection for my Xilinx board and had no issues with short cables. I'm not an expert in electrical engineering, but I think the series resistor values in the original version of the core are not valid. I'd recommend using 22 Ohm series resistor with FPGA GPIO as in [FOMU](https://workshop.fomu.im/en/latest/_static/reference/schematic-pvt.pdf) to match impedance of USB line - FPGA inputs are usually around 50 Ohm, so 22 Ohm resistors with D+ and D- lines should be just fine. I'd also recommend to use 15 kOhm pull-downs and ESD protection diodes.

For reference design I'd recommend to use [icepi-zero](https://github.com/cheyao/icepi-zero) board USB frontend - remember that the board allows you to reconfigure USB either as device or host, so if you're designing host-only USB, connect `USBD_PULL_*` nets to GND and remove 1 kOhm resistors or wire `USBD_PULL_*` nets to FPGA GPIO pins and then pull them down to GND.

![icepi-zero USB frontend design](doc/icepi_usb.png?raw=true "icepi-zero USB frontend design")

## Xilinx-specific design files

In Xilinx directory you can find version of the core utilizing two USB ports and uses XDC_* macros for CDC synchronization; there are also XDC files with timing constraints and example PIN definitions.

## Testbench

You can find a very crude testbench in `tb/` directory. It's purpose is to generate `dump.vcd` file to be viewed with gtkwave in order to check if the USB enumeration succeeds - I used it mainly for UKP microcode development. There are no tests, which validate the core itself. PRs are welcome :)

![vcd file viewed with gtkwave](doc/gtkwave_usb.png?raw=true "vcd file viewed with gtkwave")

## The Microcode Processor (UKP)

* Each instruction has a 4-bit OP code (except for BX instructions have additonal nibble for branch condition) and 0-3 4-bit operands.
* 5 registers
  * PC: program counter
  * W: 8-bit register that counts the number of times of some operation (e.g. number of bits to receive)
  * C flag: A 1-bit register that indicates whether or not the device is connected
  * T / timing counter: 3-bit counter for USB timing (the core does 8x oversampling)
  * Timer: counter making 1ms (used with WAIT instruction)

| OpCode | Instruction | Effect |
|--------|-------------|--------|
| 0      | NOP         | No operation |
| 1      | LDI         | Load 8-bit constant into W |
| 2      | START       | Marks start of USB packet |
| 3      | OUT4        | Output 4 bits |
| 4      | ----        | ---- |
| 5      | HIZ         | Set both D+ and D- to hi-impedance |
| 6      | OUTB        | Output a byte (8 bits) |
| 7      | RET         | Return to the next instruction of last CALL |
| 8      | CALL        | Save PC and jump to address |
| 9      | ----        | Prefix for BX instructions listed below |
| A      | OUTR        | Output a byte from W register (8 bits) |
| B      | DEC         | Decrement W register |
| C      | SAVE        | Save receive buffer byte into register |
| D      | IN          | Wait for input packet and proceed with sampling. Finish if both D+ and D- are 0, proceed to the next instruction. Decrement the W register with every bit received and strobe when payload byte is ready. |
| E      | WAIT	       | Wait for 1ms timing |
| F      | LOAD        | Loads a byte from register into W |
| 9 0    | BE          | Jump to address when D+ and D- are both 0 or 1, or line error condition when connected; set full-speed mode if D+ is high otherwise |
| 9 1    | BC          | Jump to address when connected |
| 9 2    | BNAK        | Jump to address when previous IN transaction returned NAK |
| 9 3    | BSTALL      | Jump to address when previous IN transaction returned STALL |
| 9 4    | BNZ         | Jump to address when W register is not zero |
| 9 5    | BZ          | Jump to address when W register is zero |
| 9 6    | BNF         | Jump to address when device is not full-speed |
| 9 7    | BJMP        | Unconditional branch to address |

```
Output Registers: 0 (VID_L), 1 (VID_H), 2 (PID_L), 3 (PID_H), 4 (INTERFACE_CLASS), 5 (INTERFACE_SUBCLASS), 6 (INTERFACE_PROTOCOL)
Input Registers: 8 (INP0), 9 (INP1) - two bytes of IN endpoint polling transaction (may differ depending on VID / PID).
```

## Interpreting USB HID reports

All HID events are transmitted in messages, *HID reports* in USB terminology. For our `usb_hid_host` module, the `typ` output indicates the device type, and when it is not zero, a pulse in the `full_report` output signifies the arrival of a HID report.

## Keyboard

USB keyboards transmit *scancodes* instead of ASCII codes. Therefore `key_0`, `key_1`, `key_2`, and `key_3` represent scancodes of the currently pressed keys. The `key_modifiers` output indicates the status of modifier keys like shift, ctrl, etc. If you need to convert the scancodes to ASCII, a simple method is demonstrated in the demo project (which supports up to 2 simultaneously pressed keys and lacks auto-repeat functionality).

If you prefer to do the conversion on your own, you can find scancodes in the "keyboard/Keypad Page" sector of the HID Usage Tables. See [scancode](https://gist.github.com/MightyPork/6da26e382a7ad91b5496ee55fdc73db2)

## Mouse

Mouse reports consist of button states and delta movements in the X and Y directions (`mouse_dx` and `mouse_dy`).

## Gamepad

Gamepad reports are more straightforward, as they represent the status of the buttons directly. Currently, only 10 buttons are exposed, but it should be straightforward to add more if they are present in the HID report. Gamepad outputs may differ depending on the pad used, there is a logic block which maps HID report to individual buttons depending on USB VID.

## References

* [Original usb_hid_host core](https://github.com/nand2mario/usb_hid_host/)
* [OSDev Wiki: USB Human Interface Devices](https://wiki.osdev.org/USB_Human_Interface_Devices)
* [USB Made Simple](https://www.usbmadesimple.co.uk/)
* [USB in a Nutshell](https://www.beyondlogic.org/usbnutshell/usb1.shtml)
* [Understanding HID report descriptors](http://who-t.blogspot.com/2018/12/understanding-hid-report-descriptors.html)
