//=============================================================================
// File        : tb/uart_reg_if.sv
// Description : Clocked interface over the DUT's parallel (register-style)
//               TX/RX ports. This is NOT part of the reusable UART VIP -
//               it's specific to this DUT's port list, exactly like a real
//               project would write a small clocking-block interface for
//               whatever register/FIFO port their peripheral exposes.
//=============================================================================
interface uart_reg_if (input logic clk, input logic rst_n);

  logic [7:0] tx_data;
  logic       tx_valid;
  logic       tx_ready;
  logic [7:0] rx_data;
  logic       rx_valid;
  logic       rx_frame_err;

  clocking cb @(posedge clk);
    output tx_data, tx_valid;
    input  tx_ready, rx_data, rx_valid, rx_frame_err;
  endclocking

  task automatic reset_regs();
    tx_data  = '0;
    tx_valid = 1'b0;
  endtask

endinterface : uart_reg_if
