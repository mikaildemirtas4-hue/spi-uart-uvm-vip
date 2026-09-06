//=============================================================================
// File        : tb/spi_dut_pkg.sv
// Description : Bundles the real-DUT register BFM, env and test. Depends on
//               spi_vip_pkg (the reusable VIP) - this package is project-
//               specific glue, not part of the VIP itself.
//=============================================================================
`ifndef SPI_DUT_PKG_SV
`define SPI_DUT_PKG_SV

package spi_dut_pkg;

  import uvm_pkg::*;
  import spi_vip_pkg::*;
  `include "uvm_macros.svh"

  `include "spi_reg_bfm.sv"
  `include "spi_dut_env.sv"
  `include "spi_dut_test.sv"

endpackage : spi_dut_pkg

`endif
