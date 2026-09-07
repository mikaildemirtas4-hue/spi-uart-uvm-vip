# UART VIP — DUT Integration Example

This folder shows, end to end, how to wire `uart_vip` to a
**synthesizable RTL DUT** (a simple UART core). Unlike the loopback demo in
`example/`, the other side here is a real Verilog module, not VIP-to-VIP.

## Directory structure

```
example_real_dut/
├── rtl/
│   └── uart_core.sv        # The DUT - a synthesizable, 16x-oversampled 8N1 UART core
├── tb/
│   ├── uart_reg_if.sv       # Clocking interface for the DUT's parallel tx_data/rx_data port
│   ├── uart_reg_bfm.sv      # A small BFM using that interface (NOT part of the VIP itself)
│   ├── uart_dut_env.sv      # Environment wiring the VIP agents to the DUT's pins
│   ├── uart_dut_test.sv     # Test exercising both the DUT's receiver and transmitter
│   ├── uart_dut_pkg.sv
│   └── tb_top.sv            # <-- THE integration point, DUT instantiation happens here
└── sim/
    └── questa.do            # Questa/ModelSim compile + run script
```

## Running it

```bash
cd example_real_dut/sim
vsim -c -do questa.do
```

To see it in the GUI, run `vsim -do questa.do` (drop the batch flag).

## The heart of the integration: `tb_top.sv`

The most confusing part is usually just **seeing the port map**:

```systemverilog
uart_core dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .tx_data      (reg_if.tx_data),
    .tx_valid     (reg_if.tx_valid),
    .tx_ready     (reg_if.tx_ready),
    .tx_serial    (line_from_dut.line),   // the DUT DRIVES this VIP wire
    .rx_serial    (line_into_dut.line),   // the VIP DRIVES this DUT input
    .rx_data      (reg_if.rx_data),
    .rx_valid     (reg_if.rx_valid),
    .rx_frame_err (reg_if.rx_frame_err)
);
```

In other words: **the VIP's `uart_if.line` signal connects to the DUT's
physical pin through exactly one port-map line.** Nothing else is needed -
the VIP itself has no idea the DUT even exists; it just drives/listens to
whatever wire it's connected to.

## Adapting this to your own DUT

1. Replace `rtl/uart_core.sv` with your own DUT module (or add your
   existing DUT under `rtl/`).
2. Update the `uart_core dut (...)` instantiation in `tb_top.sv` with your
   module's port names. Only two connections actually matter:
   - the DUT's serial RX input → `line_into_dut.line`
   - the DUT's serial TX output → `line_from_dut.line`
3. If your DUT's parallel/register side is different (e.g. sitting behind
   AXI/APB), rewrite the `uart_reg_if.sv` + `uart_reg_bfm.sv` pair for that
   interface - the pattern is the same: a small clocking-block interface
   plus a BFM class with a handful of tasks using it.
4. Match `tx_cfg.baud_rate` / `num_data_bits` / `parity` / `num_stop_bits`
   in `uart_dut_env.sv` to your DUT's actual configuration.
5. Update the file paths in `sim/questa.do` (the `$VIP_DIR`, `$DUT_DIR`
   variables) to match your project layout.

## Why two separate `uart_if` instances?

Since UART is a unidirectional, point-to-point line (not a shared bus like
SPI), the agent driving one direction and the agent listening to the other
can't physically be on the same wire - you need two independent wires, one
going into the DUT and one coming out of it. See `uart_vip/README.md` for
more detail on this distinction.

## What this example proves

- `test_dut_receiver()`: the VIP's TX agent sends random bytes to the
  DUT's `rx_serial` pin; the DUT's own decoded `rx_data`/`rx_valid`
  register output is read back and compared → verifies **the DUT's
  receiver**.
- `test_dut_transmitter()`: `reg_bfm` pushes a byte into the DUT's
  `tx_data` register port; the VIP's RX agent decodes what comes out on
  the DUT's `tx_serial` pin and delivers it to the test via a
  `uvm_tlm_analysis_fifo` → verifies **the DUT's transmitter**.

So the VIP isn't just talking to itself anymore - it independently tests
both directions of the RTL.
