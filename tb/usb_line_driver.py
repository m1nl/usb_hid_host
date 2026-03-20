from cocotb.triggers import ClockCycles


class UsbLineDriver:
    """
    Minimal USB D+/D- line driver for cocotb.
    Drives raw electrical states (J/K/SE0) with NRZI encoding.
    """

    FS_BIT_TIME_NS = 83.333  # 12 Mbps
    LS_BIT_TIME_NS = 666.667  # 1.5 Mbps

    FULL_SPEED = "full"
    LOW_SPEED = "low"

    SE0 = (0, 0)
    SE1 = (1, 1)

    # -----------------------------
    # Initialization
    # -----------------------------
    def __init__(self, dut, clk_name="clk", dp_name="dp", dn_name="dn", speed="full"):
        self.dut = dut
        self.clk = getattr(dut, clk_name)
        self.dp = getattr(dut, dp_name)
        self.dn = getattr(dut, dn_name)

        self.speed = speed
        self.bit_time = self.FS_BIT_TIME_NS if speed == self.FULL_SPEED else self.LS_BIT_TIME_NS

        # Idle bus starts in J state
        self.current_state = self.j_state()

    # -----------------------------
    # USB polarity helpers
    # -----------------------------
    def j_state(self):
        """Return (dp, dn) for J state."""
        if self.speed == self.FULL_SPEED:
            return (1, 0)  # FS: D+ high
        else:
            return (0, 1)  # LS: D- high

    def k_state(self):
        """Return (dp, dn) for K state."""
        if self.speed == self.FULL_SPEED:
            return (0, 1)
        else:
            return (1, 0)

    # -----------------------------
    # Low level drive
    # -----------------------------
    async def _drive(self, state, duration_ns):
        dp, dn = state
        self.dp.value = dp
        self.dn.value = dn
        await ClockCycles(self.clk, 5)

    # -----------------------------
    # Bus control
    # -----------------------------
    async def idle(self, bit_times=1):
        """Drive idle (J) for N bit times."""
        self.current_state = self.j_state()
        await self._drive(self.current_state, self.bit_time * bit_times)

    async def se0(self, bit_times=1):
        """Drive SE0 for N bit times."""
        await self._drive(self.SE0, self.bit_time * bit_times)

    # -----------------------------
    # NRZI encoding
    # -----------------------------
    async def send_bit(self, bit):
        """
        Send one NRZI bit:
        0 -> toggle J/K
        1 -> keep state
        """
        if bit == 0:
            # toggle state
            if self.current_state == self.j_state():
                self.current_state = self.k_state()
            else:
                self.current_state = self.j_state()

        await self._drive(self.current_state, self.bit_time)

    # -----------------------------
    # Byte transmission (LSB first)
    # -----------------------------
    async def send_byte(self, byte):
        for i in range(8):
            bit = (byte >> i) & 1
            await self.send_bit(bit)

    # -----------------------------
    # USB primitives
    # -----------------------------
    async def send_sync(self):
        """
        Send USB SYNC pattern.
        Byte value: 00000001 (LSB first)
        Produces KJKJKJKK waveform.
        """
        await self.send_byte(0x80)

    async def send_eop(self):
        """
        End Of Packet:
        SE0 for 2 bit times, then J for 1 bit time.
        """
        await self.se0(2)
        await self.idle(1)

    # -----------------------------
    # Packet helper
    # -----------------------------
    async def send_packet(self, data: bytes):
        """
        Send a raw USB packet:
        IDLE -> SYNC -> DATA -> EOP -> IDLE
        """
        await self.idle(5)
        await self.send_sync()

        for b in data:
            await self.send_byte(b)

        await self.send_eop()
        await self.idle(5)
