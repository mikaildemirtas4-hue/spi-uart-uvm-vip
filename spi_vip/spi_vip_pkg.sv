//=============================================================================
// File        : spi_vip_pkg.sv
// Description : Top-level package for the generic, reusable SPI VIP.
//               Import this single file into any project's testbench to get
//               the entire VIP. The interface (spi_if.sv) is NOT inside the
//               package - instantiate it separately in your tb top module.
//
// Compile order required by most simulators:
//   1) spi_if.sv
//   2) spi_vip_pkg.sv   (+incdir+<path to this package's source files>)
//=============================================================================
`ifndef SPI_VIP_PKG_SV
`define SPI_VIP_PKG_SV

package spi_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Maximum word width supported by the VIP. Individual transfers may use
  // any width from 1 up to this value via spi_transaction.num_bits.
  parameter int SPI_MAX_WIDTH = 32;

  typedef enum bit [1:0] {
    SPI_MODE_0,   // CPOL=0, CPHA=0
    SPI_MODE_1,   // CPOL=0, CPHA=1
    SPI_MODE_2,   // CPOL=1, CPHA=0
    SPI_MODE_3    // CPOL=1, CPHA=1
  } spi_mode_e;

  typedef enum bit { SPI_MSB_FIRST, SPI_LSB_FIRST }     spi_bit_order_e;
  typedef enum bit { SPI_CS_ACTIVE_LOW, SPI_CS_ACTIVE_HIGH } spi_cs_polarity_e;

  `include "spi_transaction.sv"
  `include "spi_config.sv"
  `include "spi_callback.sv"
  `include "spi_coverage.sv"
  `include "spi_sequencer.sv"
  `include "spi_driver_master.sv"
  `include "spi_driver_slave.sv"
  `include "spi_monitor.sv"
  `include "spi_agent.sv"
  `include "seq_lib/spi_seq_lib.sv"

endpackage : spi_vip_pkg

`endif
