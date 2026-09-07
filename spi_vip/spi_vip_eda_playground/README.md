# SPI VIP — EDA Playground (Multi-File) Version

Same idea as `uart_vip/eda_playground/`: a version of `spi_vip` set up to
run on EDA Playground with **every class in its own file**, tested against
the `spi_slave_core` DUT.

## Why a separate version exists

In a typical project (`example_real_dut/`), only `spi_vip_pkg.sv` and
`tb_top.sv` get compiled directly; files like `spi_transaction.sv` and
`spi_config.sv` are never compiled on their own - they're only pulled in
via `` `include ``. Since EDA Playground tries to auto-compile every file
you add, adding these sub-files with a `.sv` extension causes a "class
defined twice" error. The fix: add them with a `.svh` extension instead -
identical content, but EDA Playground doesn't try to compile them as a
separate module.

## EDA Playground setup

1. **design.sv** box → `design.sv` from this folder (the DUT, `spi_slave_core`)
2. **testbench.sv** box → `testbench.sv` from this folder
3. Add the following 13 files with "+" (names must match exactly):
   - `spi_transaction.svh`
   - `spi_config.svh`
   - `spi_callback.svh`
   - `spi_coverage.svh`
   - `spi_sequencer.svh`
   - `spi_driver_master.svh`
   - `spi_driver_slave.svh`
   - `spi_monitor.svh`
   - `spi_agent.svh`
   - `spi_seq_lib.svh`
   - `spi_reg_bfm.svh`
   - `spi_dut_env.svh`
   - `spi_dut_test.svh`
4. Under Tools & Simulators, check the **UVM** box (UVM 1.2).
5. Run.

Expected result: `RESULT: 20 pass / 0 fail` (verified on Siemens
QuestaSim 2025.2).
