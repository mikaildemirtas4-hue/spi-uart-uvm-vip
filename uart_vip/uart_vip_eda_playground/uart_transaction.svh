//=============================================================================
// File        : uart_transaction.sv
// Description : One UART frame (start bit + data bits + optional parity +
//               stop bit(s)). Format fields (num_data_bits/parity/
//               num_stop_bits) are informational on completed items - they
//               are resolved from the agent's uart_config at drive/monitor
//               time, since real UART links don't renegotiate format
//               per-byte.
//=============================================================================
class uart_transaction extends uvm_sequence_item;

  rand bit [UART_MAX_DATA_BITS-1:0] data;

  int unsigned  num_data_bits;
  uart_parity_e parity;
  real          num_stop_bits;

  bit parity_error;
  bit framing_error;
  bit break_detected;

  time start_time;
  time end_time;

  `uvm_object_utils_begin(uart_transaction)
    `uvm_field_int(data,           UVM_ALL_ON)
    `uvm_field_int(num_data_bits,  UVM_ALL_ON)
    `uvm_field_enum(uart_parity_e, parity, UVM_ALL_ON)
    `uvm_field_int(parity_error,   UVM_ALL_ON)
    `uvm_field_int(framing_error,  UVM_ALL_ON)
    `uvm_field_int(break_detected, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=0x%0h bits=%0d parity=%s perr=%0b ferr=%0b brk=%0b",
                      data, num_data_bits, parity.name(),
                      parity_error, framing_error, break_detected);
  endfunction

endclass : uart_transaction
