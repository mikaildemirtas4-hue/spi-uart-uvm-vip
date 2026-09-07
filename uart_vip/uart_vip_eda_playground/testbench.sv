//=============================================================================
// testbench.sv - merges the interfaces, both packages and the top module
// into one file, while keeping every class in its own separate .svh file
// (added to the EDA Playground project via "+", but never compiled
// standalone - only reached through `include below).
//
// Files you still need to add separately in EDA Playground ("+"), exact
// names matter:
//   uart_transaction.svh   uart_config.svh      uart_callback.svh
//   uart_coverage.svh      uart_sequencer.svh   uart_driver.svh
//   uart_monitor.svh       uart_agent.svh       uart_seq_lib.svh
//   uart_reg_bfm.svh       uart_dut_env.svh     uart_dut_test.svh
//
// design.sv = uart_core.sv (the real DUT)
//=============================================================================

`include "uvm_macros.svh"

//-----------------------------------------------------------------------------
// Interfaces
//-----------------------------------------------------------------------------
interface uart_if ();
  logic line;   // idle = 1 (mark), start bit = 0 (space)
endinterface : uart_if

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
endinterface : uart_reg_if

//-----------------------------------------------------------------------------
// UART VIP package - each class lives in its own .svh, included here
//-----------------------------------------------------------------------------
package uart_vip_pkg;

  import uvm_pkg::*;

  parameter int UART_MAX_DATA_BITS = 9;

  typedef enum bit [2:0] {
    UART_PARITY_NONE,
    UART_PARITY_ODD,
    UART_PARITY_EVEN,
    UART_PARITY_MARK,
    UART_PARITY_SPACE
  } uart_parity_e;

  typedef enum bit { UART_ROLE_TX, UART_ROLE_RX } uart_role_e;

  `include "uart_transaction.svh"
  `include "uart_config.svh"
  `include "uart_callback.svh"
  `include "uart_coverage.svh"
  `include "uart_sequencer.svh"
  `include "uart_driver.svh"
  `include "uart_monitor.svh"
  `include "uart_agent.svh"
  `include "uart_seq_lib.svh"

endpackage : uart_vip_pkg

//-----------------------------------------------------------------------------
// Real-DUT glue package (register BFM + env + test)
//-----------------------------------------------------------------------------
package uart_dut_pkg;

  import uvm_pkg::*;
  import uart_vip_pkg::*;

  `include "uart_reg_bfm.svh"
  `include "uart_dut_env.svh"
  `include "uart_dut_test.svh"

endpackage : uart_dut_pkg

//-----------------------------------------------------------------------------
// Top-level module - instantiates the REAL DUT (design.sv) and wires the VIP
//-----------------------------------------------------------------------------
module top;

  import uvm_pkg::*;
  import uart_vip_pkg::*;
  import uart_dut_pkg::*;

  localparam int CLK_FREQ_HZ = 50_000_000;
  localparam int BAUD_RATE   = 115_200;

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #10 clk = ~clk;   // 20ns period -> 50 MHz

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // ---- VIP-side wires ----
  uart_if     line_into_dut ();          // VIP TX agent  -> dut.rx_serial
  uart_if     line_from_dut ();          // dut.tx_serial -> VIP RX agent
  uart_reg_if reg_if (.clk(clk), .rst_n(rst_n));

  // ---- the real DUT (defined in design.sv) ----
  uart_core #(
      .CLK_FREQ_HZ (CLK_FREQ_HZ),
      .BAUD_RATE   (BAUD_RATE)
  ) dut (
      .clk          (clk),
      .rst_n        (rst_n),

      .tx_data      (reg_if.tx_data),
      .tx_valid     (reg_if.tx_valid),
      .tx_ready     (reg_if.tx_ready),
      .tx_serial    (line_from_dut.line),

      .rx_serial    (line_into_dut.line),
      .rx_data      (reg_if.rx_data),
      .rx_valid     (reg_if.rx_valid),
      .rx_frame_err (reg_if.rx_frame_err)
  );

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, top);
  end

  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif_into_dut", line_into_dut);
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif_from_dut", line_from_dut);
    uvm_config_db#(virtual uart_reg_if)::set(null, "*", "vif_reg", reg_if);
    run_test("uart_dut_test");
  end

endmodule : top
