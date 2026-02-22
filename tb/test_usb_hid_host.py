import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer

from usb_line_driver import UsbLineDriver


@cocotb.test()
async def test_usb_hid_host_reset(dut):
    clock = Clock(dut.clk, 10.416, unit="ns")
    usb = UsbLineDriver(dut, "clk", "usb_dp_i", "usb_dm_i", speed=UsbLineDriver.FULL_SPEED)

    cocotb.start_soon(clock.start())

    dut.reset.value = 1
    dut.cs.value = 1
    dut.usb_dp_i.value = 1
    dut.usb_dm_i.value = 0

    await ClockCycles(dut.clk, 10)

    dut.reset.value = 0

    await ClockCycles(dut.clk, 22000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 1200)

    KEYBOARD_DEVICE_DESCRIPTOR_0 = bytes(
        [
            0xC3,  # DATA0
            0x12,  # bLength: 18 bytes
            0x01,  # bDescriptorType: DEVICE
            0x00,
            0x02,  # bcdUSB: USB 2.0
            0x00,  # bDeviceClass: per-interface
            0x00,  # bDeviceSubClass
            0x00,  # bDeviceProtocol
            0x40,  # bMaxPacketSize0: 64 bytes
            0x00,  # CRC16
            0x00,
        ]
    )

    KEYBOARD_DEVICE_DESCRIPTOR_1 = bytes(
        [
            0xC3,  # DATA0
            0xC8,
            0x2A,  # idVendor: 0x2DC8
            0x78,
            0x56,  # idProduct: 0x5678
            0x00,
            0x01,  # bcdDevice: device version 1.00
            0x01,  # iManufacturer: string index 1
            0x02,  # iProduct: string index 2
            0x00,  # CRC16
            0x00,
        ]
    )

    # fmt: off

    KEYBOARD_DEVICE_DESCRIPTOR_2 = bytes(
        [
            0xC3,  # DATA0
            0x03,  # iSerialNumber: string index 3
            0x01,  # bNumConfigurations: 1 configuration
            0x00,  # CRC16
            0x00
        ]
    )

    # fmt: on

    await usb.send_packet(KEYBOARD_DEVICE_DESCRIPTOR_0)

    await ClockCycles(dut.clk, 1200)

    await usb.send_packet(KEYBOARD_DEVICE_DESCRIPTOR_1)

    await ClockCycles(dut.clk, 1200)

    await usb.send_packet(KEYBOARD_DEVICE_DESCRIPTOR_2)

    await ClockCycles(dut.clk, 1720)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 1520)

    KEYBOARD_CONFIG_DESCRIPTOR = bytes(
        [
            0xC3,
            # --- Configuration ---
            0x09,
            0x02,
            0x22,
            0x00,
            0x01,
            0x01,
            0x00,
            0xA0,
            0x32,
            # --- Interface ---
            0x09,
            0x04,
            0x00,
            0x00,
            0x01,
            0x03,
            0x01,
            0x01,
            0x00,
            # --- HID ---
            0x09,
            0x21,
            0x11,
            0x01,
            0x00,
            0x01,
            0x22,
            0x3F,
            0x00,
            # --- Endpoint ---
            0x07,
            0x05,
            0x81,
            0x03,
            0x08,
            0x00,
            0x0A,
        ]
    )

    await usb.send_packet(KEYBOARD_CONFIG_DESCRIPTOR)

    await ClockCycles(dut.clk, 16000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 1000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 2000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 1000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 2000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 1000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 2000)

    await usb.send_packet(bytes([0xA5, 0x5A]))

    await ClockCycles(dut.clk, 1000)

    await usb.send_packet(KEYBOARD_CONFIG_DESCRIPTOR)

    await ClockCycles(dut.clk, 5280)
    await ClockCycles(dut.clk, 5280)
