#!/usr/bin/env python3
"""Run control-read status and address recovery regressions without cocotb."""

from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    rom = root / "rom"
    with tempfile.TemporaryDirectory(prefix="usb-control-read-") as directory:
        work = Path(directory)
        for name in ("asukp.py", "ukp.s"):
            shutil.copyfile(rom / name, work / name)
        subprocess.run(
            [sys.executable, "asukp.py"], cwd=work, check=True,
            stdout=subprocess.DEVNULL,
        )
        for name in ("ukp.lst", "usb_hid_host_rom.mem"):
            if (work / name).read_bytes() != (rom / name).read_bytes():
                raise RuntimeError(f"rom/{name} needs regeneration")
        image = (work / "usb_hid_host_rom.mem").read_text().splitlines()
        if len(image) > 1024:
            raise RuntimeError(f"ROM overflow: {len(image)} nibbles")
        print(f"ROM: {len(image)}/1024 nibbles", flush=True)
        labels = {
            label: int(address, 16)
            for address, label in re.findall(
                r"^([0-9a-f]{4})\s+([a-zA-Z_][a-zA-Z_0-9]*):",
                (work / "ukp.lst").read_text(), re.MULTILINE,
            )
        }
        # Fill unused addresses only in the temporary simulation image, avoiding
        # readmemh warnings from the fixed-size ROM wrapper.
        with (work / "usb_hid_host_rom.mem").open("a") as output:
            output.write("0\n" * (1024 - len(image)))
        for speed in (1, 0):
            for address in (0, 1):
                executable = work / f"status-{speed}-{address}"
                subprocess.run([
                    "iverilog", "-g2012", "-s", "test",
                    f"-Ptest.FULL_SPEED={speed}",
                    f"-Ptest.ENTRY={labels[f'status_read{address}0']}",
                    f"-Ptest.DEVICE_ADDRESS={address}",
                    f"-Ptest.ERROR={labels['connerr']}",
                    # Observe this PC before its opcode executes. prgend can be
                    # 1024, which wraps to zero in the production 10-bit PC.
                    "-Ptest.RETURN=1023",
                    "-o", str(executable),
                    str(root / "rtl/usb_hid_host.v"),
                    str(root / "rtl/usb_hid_host_rom.v"),
                    str(root / "tb/control_read_status_tb.v"),
                ], check=True)
                subprocess.run(["vvp", str(executable)], cwd=work, check=True)
            executable = work / f"address-recovery-{speed}"
            subprocess.run([
                "iverilog", "-g2012", "-s", "test",
                f"-Ptest.FULL_SPEED={speed}",
                f"-Ptest.ENTRY={labels['address_recovery']}",
                "-o", str(executable),
                str(root / "rtl/usb_hid_host.v"),
                str(root / "rtl/usb_hid_host_rom.v"),
                str(root / "tb/address_recovery_tb.v"),
            ], check=True)
            subprocess.run(["vvp", str(executable)], cwd=work, check=True)


if __name__ == "__main__":
    main()
