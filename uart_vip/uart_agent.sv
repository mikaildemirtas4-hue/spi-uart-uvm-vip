//=============================================================================
// File        : uart_agent.sv
// Description : Standard UVM agent. Always builds a monitor (+coverage);
//               only builds a sequencer+driver when is_active == UVM_ACTIVE
//               AND role == UART_ROLE_TX, since a UART receiver never
//               drives the wire.
//=============================================================================
class uart_agent extends uvm_agent;

  `uvm_component_utils(uart_agent)

  uart_config    cfg;
  uart_sequencer sequencer;
  uart_driver    driver;
  uart_monitor   monitor;
  uart_coverage  coverage;

  uvm_analysis_port #(uart_transaction) ap;  // exposes monitor.ap at the agent boundary

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(uart_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("UART_AGT", "uart_config not found in config_db")

    uvm_config_db#(uart_config)::set(this, "*", "cfg", cfg);

    is_active = cfg.is_active;

    monitor = uart_monitor::type_id::create("monitor", this);

    if (cfg.enable_coverage)
      coverage = uart_coverage::type_id::create("coverage", this);

    if (is_active == UVM_ACTIVE && cfg.role == UART_ROLE_TX) begin
      sequencer = uart_sequencer::type_id::create("sequencer", this);
      driver    = uart_driver::type_id::create("driver", this);
    end
    else if (is_active == UVM_ACTIVE && cfg.role == UART_ROLE_RX) begin
      `uvm_warning("UART_AGT", "is_active==UVM_ACTIVE ignored for an RX-role agent - a UART receiver has no driver")
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (driver != null)
      driver.seq_item_port.connect(sequencer.seq_item_export);

    ap = monitor.ap;

    if (cfg.enable_coverage)
      monitor.ap.connect(coverage.analysis_export);
  endfunction

endclass : uart_agent
