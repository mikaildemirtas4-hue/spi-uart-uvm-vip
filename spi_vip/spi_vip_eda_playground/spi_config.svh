//=============================================================================
// File        : spi_config.sv
// Description : Per-agent configuration object. One of these is created and
//               pushed via config_db for every spi_agent instance in your
//               environment (master and/or slave side).
//=============================================================================
class spi_config extends uvm_object;

  `uvm_object_utils(spi_config)

  // Virtual interface handle - set by the env/test via config_db, then
  // re-published by the agent to its own sub-components.
  virtual spi_if vif;

  // --- Role & activity -------------------------------------------------
  bit                      is_master = 1;         // 1 = agent plays MASTER, 0 = agent plays SLAVE
  uvm_active_passive_enum  is_active = UVM_ACTIVE; // UVM_ACTIVE builds a driver+sequencer, UVM_PASSIVE only a monitor

  // --- Protocol configuration -------------------------------------------
  spi_mode_e        mode             = SPI_MODE_0;      // one of the 4 standard SPI modes
  spi_bit_order_e   bit_order        = SPI_MSB_FIRST;
  spi_cs_polarity_e cs_polarity      = SPI_CS_ACTIVE_LOW;
  int unsigned      default_num_bits = 8;
  int unsigned      num_cs           = 1;               // must be <= vif's NUM_CS parameter

  // --- Timing (master-driver only, ns) -----------------------------------
  real clk_period_ns    = 100;  // full sclk period -> 10 MHz default
  real cs_setup_time_ns = 20;   // CS assert -> first clock edge
  real cs_hold_time_ns  = 20;   // last clock edge -> CS de-assert
  real inter_word_gap_ns = 40;  // gap between back-to-back words

  // --- Feature switches ---------------------------------------------------
  bit enable_coverage = 1;

  function new(string name = "spi_config");
    super.new(name);
  endfunction

endclass : spi_config
