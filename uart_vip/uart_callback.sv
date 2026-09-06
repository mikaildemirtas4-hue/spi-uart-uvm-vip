//=============================================================================
// File        : uart_callback.sv
// Description : Callback base class - register a derived callback on the
//               driver or monitor to hook into VIP events without editing
//               VIP source (used by example/uart_loopback_test.sv to build
//               a tiny send/receive checker).
//=============================================================================
class uart_callback extends uvm_callback;

  function new(string name = "uart_callback");
    super.new(name);
  endfunction

  // Fired by the monitor right after a full frame has been captured.
  virtual task post_transaction(uvm_component originator, uart_transaction tr);
  endtask

  // Fired by the driver just before it starts driving a frame.
  virtual task pre_drive(uvm_component originator, uart_transaction tr);
  endtask

endclass : uart_callback
