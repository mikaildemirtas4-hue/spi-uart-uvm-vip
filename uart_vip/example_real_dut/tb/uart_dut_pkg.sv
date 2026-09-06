//=============================================================================
// File        : tb/uart_dut_pkg.sv
// Description : Bundles the real-DUT env, register BFM and test. Depends on
//               uart_vip_pkg (the reusable VIP) - this package is project-
//               specific glue, not part of the VIP itself.
//=============================================================================
`ifndef UART_DUT_PKG_SV
`define UART_DUT_PKG_SV

package uart_dut_pkg;

  import uvm_pkg::*;
  import uart_vip_pkg::*;
  `include "uvm_macros.svh"

  `include "uart_reg_bfm.sv"
  `include "uart_dut_env.sv"
  `include "uart_dut_test.sv"

endpackage : uart_dut_pkg

`endif
