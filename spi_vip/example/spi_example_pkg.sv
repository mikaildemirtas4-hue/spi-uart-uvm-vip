//=============================================================================
// File        : example/spi_example_pkg.sv
// Description : Bundles the example env + test. Not part of the VIP proper -
//               this is the "here's how a real project uses it" reference.
//=============================================================================
`ifndef SPI_EXAMPLE_PKG_SV
`define SPI_EXAMPLE_PKG_SV

package spi_example_pkg;

  import uvm_pkg::*;
  import spi_vip_pkg::*;
  `include "uvm_macros.svh"

  `include "spi_loopback_checker.sv"
  `include "spi_env.sv"
  `include "spi_loopback_test.sv"

endpackage : spi_example_pkg

`endif
