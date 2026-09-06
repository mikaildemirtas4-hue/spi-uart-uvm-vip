//=============================================================================
// File        : spi_agent.sv
// Description : Standard UVM agent. Reads a spi_config from config_db and
//               builds exactly what's needed:
//                 - always: a monitor (+ coverage, if enabled)
//                 - if UVM_ACTIVE: a sequencer + a driver
//                     - driver is spi_driver_master if cfg.is_master
//                     - driver is spi_driver_slave  otherwise
//=============================================================================
class spi_agent extends uvm_agent;

  `uvm_component_utils(spi_agent)

  spi_config                    cfg;
  spi_sequencer                 sequencer;
  uvm_driver #(spi_transaction) driver;    // holds either a master or a slave driver instance
  spi_monitor                   monitor;
  spi_coverage                  coverage;

  uvm_analysis_port #(spi_transaction) ap;  // exposes monitor.ap at the agent boundary

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(spi_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("SPI_AGT", "spi_config not found in config_db")

    // Re-publish so sub-components can also uvm_config_db#(spi_config)::get() directly.
    uvm_config_db#(spi_config)::set(this, "*", "cfg", cfg);

    is_active = cfg.is_active;   // uvm_agent's built-in field

    monitor = spi_monitor::type_id::create("monitor", this);

    if (cfg.enable_coverage)
      coverage = spi_coverage::type_id::create("coverage", this);

    if (is_active == UVM_ACTIVE) begin
      sequencer = spi_sequencer::type_id::create("sequencer", this);
      if (cfg.is_master) driver = spi_driver_master::type_id::create("driver", this);
      else               driver = spi_driver_slave::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);

    ap = monitor.ap;

    if (cfg.enable_coverage)
      monitor.ap.connect(coverage.analysis_export);
  endfunction

endclass : spi_agent
