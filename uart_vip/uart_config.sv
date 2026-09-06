//=============================================================================
// File        : uart_config.sv
// Description : Per-agent configuration. One of these per uart_agent
//               instance (one per direction of a UART link).
//=============================================================================
class uart_config extends uvm_object;

  `uvm_object_utils(uart_config)

  virtual uart_if vif;

  // --- Role & activity ---------------------------------------------------
  uart_role_e              role      = UART_ROLE_TX;   // TX drives the line, RX only ever observes it
  uvm_active_passive_enum  is_active = UVM_ACTIVE;      // meaningful only when role == UART_ROLE_TX

  // --- Frame format --------------------------------------------------------
  real          baud_rate     = 115_200;
  int unsigned  num_data_bits = 8;              // 5..9
  uart_parity_e parity        = UART_PARITY_NONE;
  real          num_stop_bits = 1.0;            // 1.0, 1.5, or 2.0

  // --- Feature switches ------------------------------------------------------
  bit enable_coverage = 1;

  function new(string name = "uart_config");
    super.new(name);
  endfunction

  // Bit period in ns, derived from baud_rate.
  function real bit_period_ns();
    return 1_000_000_000.0 / baud_rate;
  endfunction

endclass : uart_config
