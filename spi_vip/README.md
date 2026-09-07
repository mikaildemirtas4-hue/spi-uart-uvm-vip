# SPI UVM VIP (Verification IP)

![Simulator](https://img.shields.io/badge/Simulator-QuestaSim%202025.2-1f4e79)
![Tests](https://img.shields.io/badge/DUT%20tests-20%2F20%20passing-c55a11)
![License](https://img.shields.io/badge/License-Apache%202.0-1f4e79)

A generic, configurable SPI UVC (Universal Verification Component) meant to
be dropped into any project. Supports both master and slave roles, can be
configured active or passive, and drives/decodes all four standard SPI
modes (CPOL/CPHA combinations) with correct timing.

## Directory structure

```
spi_vip/
├── spi_if.sv                 # Physical SPI interface (sclk, mosi, miso, cs_n[])
├── spi_vip_pkg.sv            # Single import point - the whole VIP is pulled in here
├── spi_transaction.sv        # Sequence item (one full-duplex word transfer)
├── spi_config.sv             # Agent configuration (mode, role, timing, etc.)
├── spi_callback.sv           # Callback base class (hook in without touching VIP source)
├── spi_coverage.sv           # Functional coverage (mode x width cross included)
├── spi_sequencer.sv
├── spi_driver_master.sv      # Master role - drives sclk/mosi/cs_n, reads miso
├── spi_driver_slave.sv       # Slave role - watches sclk/cs_n, drives miso
├── spi_monitor.sv            # Passive observer - works for either role
├── spi_agent.sv               # Builds driver/sequencer/coverage from config
├── seq_lib/
│   └── spi_seq_lib.sv        # Ready-made sequence library
└── example/                  # Usage example (real-project template)
    ├── spi_env.sv
    ├── spi_loopback_test.sv
    ├── spi_example_pkg.sv
    └── tb_top.sv
```

> **How do I hook this up to a DUT?** See `example_real_dut/` -
> it contains a synthesizable SPI slave core, a full testbench wiring the
> VIP to it, and a Questa `.do` script. `example/` is VIP-to-VIP loopback
> only; read `example_real_dut/README.md` for the real integration.

## Compile order

Files pulled in via `` `include `` aren't compiled separately - just point
the simulator at them with `+incdir+`. Order matters:

```bash
# Example: Questa/VCS-style command line
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv \
     spi_vip/spi_if.sv \
     +incdir+spi_vip spi_vip/spi_vip_pkg.sv \
     +incdir+spi_vip/example spi_vip/example/spi_example_pkg.sv \
     spi_vip/example/tb_top.sv

vsim -c tb_top +UVM_TESTNAME=spi_loopback_test -do "run -all"
```

## Integrating into your own project

1. Copy the `spi_vip/` folder into your project as-is (skip `example/` -
   it's a reference, not part of the VIP itself).
2. In your own env:
   ```systemverilog
   spi_config cfg = spi_config::type_id::create("cfg");
   cfg.vif       = <your virtual interface handle>;
   cfg.is_master = 1;              // or 0, depending on whether the DUT is slave or master
   cfg.is_active = UVM_ACTIVE;     // or UVM_PASSIVE if you only want to observe
   cfg.mode      = SPI_MODE_0;     // whichever mode your DUT expects
   cfg.num_cs    = 2;              // if you have more than one slave-select line
   uvm_config_db#(spi_config)::set(this, "my_agent*", "cfg", cfg);

   my_agent = spi_agent::type_id::create("my_agent", this);
   ```
3. If the DUT is a SLAVE -> set `cfg.is_master = 1` and use the VIP as
   master. If the DUT is a MASTER -> set `cfg.is_master = 0`, use the VIP
   as slave, and feed response data via `spi_slave_response_seq`.
4. If you only want to observe (e.g., the DUT already has its own
   master/slave VIP and you just want coverage), set
   `cfg.is_active = UVM_PASSIVE` - the agent builds only a monitor +
   coverage, no driver/sequencer.

## Extending via callbacks (without touching VIP source)

```systemverilog
class my_spi_cb extends spi_callback;
  `uvm_object_utils(my_spi_cb)
  function new(string name = "my_spi_cb"); super.new(name); endfunction

  virtual task post_transaction(uvm_component originator, spi_transaction tr);
    `uvm_info("MY_CB", $sformatf("saw: %s", tr.convert2string()), UVM_LOW)
  endtask
endclass

// in your test/env:
my_spi_cb cb = my_spi_cb::type_id::create("cb");
uvm_callbacks#(spi_monitor, spi_callback)::add(my_agent.monitor, cb);
```

## Verification status

Run against two scenarios in Siemens QuestaSim 2025.2 (UVM-1.2):

| Scenario | What it checks | Result |
|---|---|---|
| VIP-to-VIP loopback | Master agent ↔ slave agent, `spi_loopback_checker` scoreboard compares MOSI and MISO data | Passed |
| Real RTL DUT | `spi_slave_core` (synthesizable, Mode 0, double-buffered TX) - both receive and transmit directions checked in the same transfer | **20/20 pass, 0 fail** |

While bringing up the DUT test I found and fixed an actual timing bug
in the DUT's RX logic and a reset-race issue in the testbench - the kind
of thing this VIP is meant to catch.

## Design decisions & limitations

- `spi_transaction` field names are **bus-absolute**: `mosi_data` always
  reflects whatever is on the MOSI wire, `miso_data` always reflects the
  MISO wire. Master sequences fill in `mosi_data`; slave sequences fill in
  `miso_data` - the one approach that doesn't get confusing once you're
  looking at the physical wire.
- The monitor doesn't assume a word width; it counts bits until CS
  deasserts (real SPI has no protocol-level framing).
- All timing fields on the master driver (`clk_period_ns`,
  `cs_setup_time_ns`, ...) are adjustable per project via `spi_config`.
- `SPI_MAX_WIDTH` (in `spi_vip_pkg.sv`, default 32) is the maximum word
  width the VIP supports; any transfer can use a width up to that
  (`spi_transaction.num_bits`).
- What this VIP does **not** include: SVA-based protocol-violation
  assertions, a built-in negative-test/error-injection library, UVM RAL
  register-model integration, or qualification on simulators other than
  Questa. The reference DUT (`spi_slave_core`) is a teaching example, not
  a silicon-proven design.
