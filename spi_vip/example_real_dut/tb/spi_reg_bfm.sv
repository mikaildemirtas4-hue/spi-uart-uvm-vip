//=============================================================================
// File        : tb/spi_reg_bfm.sv
// Description : Thin helper around spi_reg_if's clocking block. Deliberately
//               NOT a full UVM agent - the kind of small, DUT-specific BFM
//               a real project writes for whatever register/FIFO port
//               their peripheral exposes, used alongside the reusable SPI
//               VIP (which drives the actual sclk/mosi/miso/cs_n pins).
//=============================================================================
class spi_reg_bfm extends uvm_object;

  `uvm_object_utils(spi_reg_bfm)

  virtual spi_reg_if vif;

  function new(string name = "spi_reg_bfm");
    super.new(name);
  endfunction

  // Preloads the byte the DUT will present on MISO during its NEXT
  // transaction (double-buffered in the DUT, so this is safe to call at
  // any time, including while a transaction is in flight).
  task automatic load_tx_byte(bit [7:0] data);
    @(vif.cb);
    vif.cb.tx_data <= data;
    vif.cb.tx_load <= 1'b1;
    @(vif.cb);
    vif.cb.tx_load <= 1'b0;
  endtask

  // Blocks until the DUT's parallel port pulses rx_valid, then returns the
  // byte the DUT captured on MOSI during the transaction that just ended.
  task automatic wait_for_rx_byte(output bit [7:0] data);
    do @(vif.cb); while (!vif.cb.rx_valid);
    data = vif.cb.rx_data;
  endtask

endclass : spi_reg_bfm
