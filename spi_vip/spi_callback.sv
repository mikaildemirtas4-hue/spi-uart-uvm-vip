//=============================================================================
// File        : spi_callback.sv
// Description : Callback base class. Register a derived callback on the
//               driver or monitor instance (uvm_callbacks#(...)::add(...))
//               to hook into VIP events from your testbench WITHOUT ever
//               editing VIP source - the standard "professional VIP"
//               extension mechanism.
//=============================================================================
class spi_callback extends uvm_callback;

  function new(string name = "spi_callback");
    super.new(name);
  endfunction

  // Fired by the monitor right after a full transaction has been captured.
  virtual task post_transaction(uvm_component originator, spi_transaction tr);
  endtask

  // Fired by a driver just before it starts driving a transaction. Modify
  // 'tr' in place for last-minute injection (error injection, protocol
  // violations, etc.).
  virtual task pre_drive(uvm_component originator, spi_transaction tr);
  endtask

endclass : spi_callback
