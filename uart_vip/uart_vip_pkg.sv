//=============================================================================
// File        : uart_vip_pkg.sv
// Description : Top-level package for the generic, reusable UART VIP.
//               Import this single file into any project's testbench.
//               The interface (uart_if.sv) is NOT inside the package -
//               instantiate it separately, once per link direction.
//
// Compile order required by most simulators:
//   1) uart_if.sv
//   2) uart_vip_pkg.sv   (+incdir+<path to this package's source files>)
//=============================================================================
`ifndef UART_VIP_PKG_SV
`define UART_VIP_PKG_SV

package uart_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Maximum data-bit width supported (standard UART is 5..9 data bits).
  parameter int UART_MAX_DATA_BITS = 9;

  typedef enum bit [2:0] {
    UART_PARITY_NONE,
    UART_PARITY_ODD,
    UART_PARITY_EVEN,
    UART_PARITY_MARK,
    UART_PARITY_SPACE
  } uart_parity_e;

  typedef enum bit { UART_ROLE_TX, UART_ROLE_RX } uart_role_e;

  `include "uart_transaction.sv"
  `include "uart_config.sv"
  `include "uart_callback.sv"
  `include "uart_coverage.sv"
  `include "uart_sequencer.sv"
  `include "uart_driver.sv"
  `include "uart_monitor.sv"
  `include "uart_agent.sv"
  `include "seq_lib/uart_seq_lib.sv"

endpackage : uart_vip_pkg

`endif
