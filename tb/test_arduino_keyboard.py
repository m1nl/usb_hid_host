#!/usr/bin/env python3
"""Verify the Arduino/SparkFun VID profile at the host's UKP byte interface."""
from pathlib import Path
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="usb-arduino-keyboard-") as directory:
        for enabled in (1, 0):
            for forced in (1, 0):
                executable = Path(directory) / f"keyboard-{enabled}-{forced}"
                subprocess.run([
                    "iverilog", "-g2012", "-s", "test",
                    f"-Ptest.KEYBOARD_SUPPORT={enabled}",
                    f"-Ptest.FORCE_ARDUINO_KEYBOARD={forced}",
                    "-o", str(executable),
                    str(root / "rtl/usb_hid_host.v"),
                    str(root / "tb/arduino_keyboard_tb.v"),
                ], check=True)
                subprocess.run(["vvp", str(executable)], check=True)


if __name__ == "__main__":
    main()
