//=============================================================================
// File        : tb/spi_reg_if.sv
// Description : Clocked interface over the DUT's parallel (register-style)
//               TX/RX port. Not part of the reusable SPI VIP - specific to
//               this DUT's port list, exactly like a real project would
//               write for whatever register/FIFO port their peripheral
//               exposes.
//=============================================================================
interface spi_reg_if (input logic clk, input logic rst_n);

  logic [7:0] tx_data;
  logic       tx_load;
  logic [7:0] rx_data;
  logic       rx_valid;

  clocking cb @(posedge clk);
    output tx_data, tx_load;
    input  rx_data, rx_valid;
  endclocking

endinterface : spi_reg_if
