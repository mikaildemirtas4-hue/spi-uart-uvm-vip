# SPI VIP — DUT Integration Example

Same idea as `example_real_dut/` in the UART VIP: an end-to-end example
wiring `spi_vip` to a synthesizable DUT (an SPI slave core).

## Directory structure

```
example_real_dut/
├── rtl/
│   └── spi_slave_core.sv   # The DUT - fixed Mode 0, synthesizable SPI slave
├── tb/
│   ├── spi_reg_if.sv        # Clocking interface for the DUT's parallel tx_data/rx_data port
│   ├── spi_reg_bfm.sv       # A small BFM using that interface (NOT part of the VIP)
│   ├── spi_dut_env.sv       # Environment wiring the VIP (master role) to the DUT's pins
│   ├── spi_dut_test.sv      # Test verifying both DUT TX and RX in a single full-duplex transfer
│   ├── spi_dut_pkg.sv
│   └── tb_top.sv            # <-- THE integration point, DUT instantiation happens here
└── sim/
    └── questa.do
```

## Why SPI is different from UART here: two-way verification in one pass

Since UART needs two separate wires, the DUT's receiver and transmitter
were tested separately. SPI, by nature, is **full-duplex** - MOSI and MISO
flow at the same time, on the same clock. So `spi_dut_test.sv` does this
on every transfer:

1. `reg_bfm.load_tx_byte(...)` preloads the byte the DUT will drive on
   MISO for the next transfer.
2. The VIP master sends a random byte on MOSI via `spi_single_transfer_seq`.
3. At the same time, `reg_bfm.wait_for_rx_byte(...)` reads back what the
   DUT decoded from MOSI.
4. A single transfer checks both "is the DUT's receiver correct" and "is
   the DUT's transmitter correct".

## Running it

```bash
cd example_real_dut/sim
vsim -c -do questa.do
```

## About the DUT

`spi_slave_core` is a fixed Mode 0 (CPOL=0, CPHA=0), 8-bit, MSB-first SPI
slave. All SPI pins (`sclk`, `mosi`, `cs_n`) are treated as asynchronous
and synchronized into the system clock (`clk`) - the standard approach for
not using an external signal directly as a clock/edge source in a real
design. `clk` needs to run at least ~5-10x faster than `sclk` (50 MHz clk
/ 5 MHz sclk = 10x in the example).

The parallel port is double-buffered: `tx_load` can safely be triggered
even mid-transfer, since the DUT only makes the new value "active" at the
start of the next transfer (when `cs_n` falls) - no mid-transfer
corruption.

## Adapting this to your own DUT

Same checklist as `uart_vip/example_real_dut/README.md`: replace the DUT
instantiation in `tb_top.sv` with your own module - the only thing that
matters is wiring four pins (`sclk`/`mosi`/`miso`/`cs_n`) to the VIP's
`spi_if` signals. If your DUT's mode isn't Mode 0, update `m_cfg.mode` in
`spi_dut_env.sv`.
