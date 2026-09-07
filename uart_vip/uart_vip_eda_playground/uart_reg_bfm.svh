//=============================================================================
// File        : tb/uart_reg_bfm.sv
// Description : Thin helper around uart_reg_if's clocking block. This is
//               deliberately NOT a full UVM agent - it's the kind of small,
//               DUT-specific BFM a real project writes for whatever
//               register/FIFO port their peripheral happens to expose,
//               used alongside (not instead of) the reusable UART VIP.
//=============================================================================
class uart_reg_bfm extends uvm_object;

  `uvm_object_utils(uart_reg_bfm)

  virtual uart_reg_if vif;

  function new(string name = "uart_reg_bfm");
    super.new(name);
  endfunction

  // Pushes one byte into the DUT's TX port, waiting for tx_ready first.
  task automatic send_tx_byte(bit [7:0] data);
    do @(vif.cb); while (!vif.cb.tx_ready);
    vif.cb.tx_data  <= data;
    vif.cb.tx_valid <= 1'b1;
    @(vif.cb);
    vif.cb.tx_valid <= 1'b0;
  endtask

  // Blocks until the DUT's RX port pulses rx_valid, then returns the byte.
  task automatic wait_for_rx_byte(output bit [7:0] data, output bit frame_err);
    do @(vif.cb); while (!vif.cb.rx_valid);
    data      = vif.cb.rx_data;
    frame_err = vif.cb.rx_frame_err;
  endtask

endclass : uart_reg_bfm
