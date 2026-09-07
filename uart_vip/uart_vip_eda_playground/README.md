# UART VIP — EDA Playground (Multi-File) Version

This folder is a version of `uart_vip` set up to run on EDA Playground
with **every class in its own file**. It tests the same scenario as
`../example_real_dut/` (against the `uart_core` DUT), just packaged
to work around EDA Playground's "auto-compile every file you add" behavior.

## Why a separate version exists

In a typical project (`example_real_dut/`), only `uart_vip_pkg.sv` and
`tb_top.sv` get compiled directly; files like `uart_transaction.sv` and
`uart_config.sv` are never compiled on their own - they're only pulled in
via `` `include ``. Since EDA Playground tries to auto-compile every file
you add, adding these sub-files with a `.sv` extension causes a "class
defined twice" error. The fix: add them with a `.svh` extension instead -
identical content, but EDA Playground doesn't try to compile them as a
separate module.

## EDA Playground setup

1. **design.sv** box → `design.sv` from this folder (the DUT, `uart_core`)
2. **testbench.sv** box → `testbench.sv` from this folder
3. Add the following 11 files with "+" (names must match exactly):
   - `uart_transaction.svh`
   - `uart_config.svh`
   - `uart_callback.svh`
   - `uart_coverage.svh`
   - `uart_sequencer.svh`
   - `uart_driver.svh`
   - `uart_monitor.svh`
   - `uart_agent.svh`
   - `uart_seq_lib.svh`
   - `uart_reg_bfm.svh`
   - `uart_dut_env.svh`
   - `uart_dut_test.svh`
4. Under Tools & Simulators, check the **UVM** box (UVM 1.2).
5. Run.

Expected result: `RESULT: 40 pass / 0 fail` (verified on Siemens
QuestaSim 2025.2).
