//=============================================================================
// File        : uart_coverage.sv
// Description : Functional coverage - subscribes to the monitor's analysis
//               port, so it sees every completed frame.
//=============================================================================
class uart_coverage extends uvm_subscriber #(uart_transaction);

  `uvm_component_utils(uart_coverage)

  uart_config     cfg;
  uart_transaction tr;

  covergroup cg_uart;
    option.per_instance = 1;

    cp_data_bits: coverpoint tr.num_data_bits { bins b[] = {5, 6, 7, 8, 9}; }

    cp_parity: coverpoint tr.parity {
      bins none  = {UART_PARITY_NONE};
      bins odd   = {UART_PARITY_ODD};
      bins even  = {UART_PARITY_EVEN};
      bins mark  = {UART_PARITY_MARK};
      bins space = {UART_PARITY_SPACE};
    }

    cp_stop: coverpoint tr.num_stop_bits {
      bins one      = {1.0};
      bins one_half = {1.5};
      bins two      = {2.0};
    }

    cp_data_zero: coverpoint (tr.data == '0) { bins yes = {1}; bins no = {0}; }
    cp_data_ones: coverpoint (&tr.data)      { bins yes = {1}; bins no = {0}; }

    cp_ferr:  coverpoint tr.framing_error  { bins yes = {1}; bins no = {0}; }
    cp_perr:  coverpoint tr.parity_error   { bins yes = {1}; bins no = {0}; }
    cp_break: coverpoint tr.break_detected { bins yes = {1}; bins no = {0}; }

    cx_bits_parity: cross cp_data_bits, cp_parity;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_uart = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("UART_COV", "uart_config not found in config_db")
  endfunction

  function void write(uart_transaction t);
    tr = t;
    if (cfg.enable_coverage) cg_uart.sample();
  endfunction

endclass : uart_coverage
