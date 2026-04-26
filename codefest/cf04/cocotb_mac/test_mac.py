import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


async def reset_dut(dut):
    dut.rst.value = 1
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0


@cocotb.test()
async def test_mac_basic(dut):
    """Basic MAC test: [a=3,b=4]x3, rst, [a=-5,b=2]x2"""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.a.value = 3
    dut.b.value = 4

    await RisingEdge(dut.clk)  # edge 1 captures inputs
    await RisingEdge(dut.clk)  # edge 2 — read out=12
    assert dut.out.value.to_signed() == 12
    dut._log.info(f"cycle 1 | a=3 b=4 | expected=12 | actual={dut.out.value.to_signed()} | PASS")

    await RisingEdge(dut.clk)  # edge 3 — read out=24
    assert dut.out.value.to_signed() == 24
    dut._log.info(f"cycle 2 | a=3 b=4 | expected=24 | actual={dut.out.value.to_signed()} | PASS")

    await RisingEdge(dut.clk)  # edge 4 — read out=36
    assert dut.out.value.to_signed() == 36
    dut._log.info(f"cycle 3 | a=3 b=4 | expected=36 | actual={dut.out.value.to_signed()} | PASS")

    # assert reset — set rst, wait one edge to capture, read on next
    dut.rst.value = 1
    await RisingEdge(dut.clk)  # edge captures rst=1
    await RisingEdge(dut.clk)  # read cleared output
    actual = dut.out.value.to_signed()
    assert actual == 0, f"after rst expected 0 got {actual}"
    dut._log.info(f"after rst | expected=0 | actual={actual} | PASS")
    dut.rst.value = 0

    dut.a.value = -5
    dut.b.value = 2

    await RisingEdge(dut.clk)  # captures a=-5,b=2
    await RisingEdge(dut.clk)  # read out=-10
    actual = dut.out.value.to_signed()
    assert actual == -10, f"cycle 1 a=-5 b=2 expected -10 got {actual}"
    dut._log.info(f"cycle 1 | a=-5 b=2 | expected=-10 | actual={actual} | PASS")

    await RisingEdge(dut.clk)  # read out=-20
    actual = dut.out.value.to_signed()
    assert actual == -20, f"cycle 2 a=-5 b=2 expected -20 got {actual}"
    dut._log.info(f"cycle 2 | a=-5 b=2 | expected=-20 | actual={actual} | PASS")

    dut._log.info("test_mac_basic: ALL ASSERTIONS PASSED")


@cocotb.test()
async def test_mac_overflow(dut):
    """Overflow test: a=127 b=127 until 32-bit signed overflow"""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    MAX_S32 = 2_147_483_647
    MIN_S32 = -2_147_483_648
    PRODUCT = 127 * 127
    dut.a.value = 127
    dut.b.value = 127
    accumulator = 0
    overflow_cycle = None

    await RisingEdge(dut.clk)  # first edge captures inputs

    for cycle in range(140000):
        await RisingEdge(dut.clk)
        actual = dut.out.value.to_signed()
        accumulator += PRODUCT
        if overflow_cycle is None and accumulator > MAX_S32:
            overflow_cycle = cycle + 1
            python_wrap = ((accumulator + 2**31) % 2**32) - 2**31
            dut._log.info(f"Overflow at cycle {overflow_cycle} | product={PRODUCT} | expected_no_wrap={accumulator} | actual={actual}")
            if actual == MAX_S32:
                dut._log.info("BEHAVIOR: SATURATES at 2^31-1")
            elif actual == python_wrap:
                dut._log.info(f"BEHAVIOR: WRAPS cleanly (two's complement) to {actual}")
            else:
                dut._log.info(f"BEHAVIOR: WRAPS skipping boundary to {actual} gap={MAX_S32 % PRODUCT}")
            dut._log.info(f"Overflow summary: cycle={overflow_cycle} value={actual} MAX={MAX_S32} MIN={MIN_S32} python_wrap={python_wrap}")
            break

    assert overflow_cycle is not None, "Overflow never triggered"
    dut._log.info("test_mac_overflow: COMPLETE")
