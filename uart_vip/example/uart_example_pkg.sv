//=============================================================================
// File        : example/uart_example_pkg.sv
// Description : Bundles the example checker + env + test. Not part of the
//               VIP proper - this is the "here's how a real project uses
//               it" reference.
//=============================================================================
`ifndef UART_EXAMPLE_PKG_SV
`define UART_EXAMPLE_PKG_SV

package uart_example_pkg;

  import uvm_pkg::*;
  import uart_vip_pkg::*;
  `include "uvm_macros.svh"

  `include "uart_loopback_checker.sv"
  `include "uart_env.sv"
  `include "uart_loopback_test.sv"

endpackage : uart_example_pkg

`endif
