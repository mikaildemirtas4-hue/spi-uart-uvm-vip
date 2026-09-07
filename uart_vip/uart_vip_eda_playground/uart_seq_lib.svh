//=============================================================================
// File        : seq_lib/uart_seq_lib.sv
// Description : Reusable sequence library shipped with the VIP. Extend
//               uart_base_sequence for anything project-specific.
//=============================================================================

class uart_base_sequence extends uvm_sequence #(uart_transaction);
  `uvm_object_utils(uart_base_sequence)
  function new(string name = "uart_base_sequence");
    super.new(name);
  endfunction
endclass : uart_base_sequence


// Sends a single, fully specified byte/word.
class uart_send_byte_seq extends uart_base_sequence;

  `uvm_object_utils(uart_send_byte_seq)

  rand bit [UART_MAX_DATA_BITS-1:0] value;

  function new(string name = "uart_send_byte_seq");
    super.new(name);
  endfunction

  task body();
    uart_transaction tr = uart_transaction::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize() with { data == value; })
      `uvm_error(get_type_name(), "Randomization failed")
    finish_item(tr);
  endtask

endclass : uart_send_byte_seq


// Sends N fully random words back-to-back.
class uart_random_stream_seq extends uart_base_sequence;

  `uvm_object_utils(uart_random_stream_seq)

  rand int unsigned num_bytes = 10;

  function new(string name = "uart_random_stream_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_bytes) begin
      uart_transaction tr = uart_transaction::type_id::create("tr");
      start_item(tr);
      assert(tr.randomize());
      finish_item(tr);
    end
  endtask

endclass : uart_random_stream_seq


// Sends a fixed ASCII string - handy for readable waveform debug.
class uart_string_seq extends uart_base_sequence;

  `uvm_object_utils(uart_string_seq)

  string message = "Hello UART";

  function new(string name = "uart_string_seq");
    super.new(name);
  endfunction

  task body();
    foreach (message[i]) begin
      uart_transaction tr = uart_transaction::type_id::create("tr");
      start_item(tr);
      assert(tr.randomize() with { data == message[i]; });
      finish_item(tr);
    end
  endtask

endclass : uart_string_seq
