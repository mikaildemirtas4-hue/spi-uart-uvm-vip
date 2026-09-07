//=============================================================================
// testbench.sv - merges the interfaces, both packages and the top module
// into one file, while keeping every class in its own separate .svh file
// (added to the EDA Playground project via "+", but never compiled
// standalone - only reached through `include below).
//
// Files you still need to add separately in EDA Playground ("+"), exact
// names matter:
//   spi_transaction.svh   spi_config.svh        spi_callback.svh
//   spi_coverage.svh      spi_sequencer.svh      spi_driver_master.svh
//   spi_driver_slave.svh  spi_monitor.svh        spi_agent.svh
//   spi_seq_lib.svh       spi_reg_bfm.svh        spi_dut_env.svh
//   spi_dut_test.svh
//
// design.sv = spi_slave_core.sv (the DUT)
//=============================================================================

`include "uvm_macros.svh"

//-----------------------------------------------------------------------------
// Interfaces
//-----------------------------------------------------------------------------
interface spi_if #(parameter int NUM_CS = 1) ();
  logic              sclk;
  logic              mosi;
  logic              miso;
  logic [NUM_CS-1:0] cs_n;
endinterface : spi_if

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

//-----------------------------------------------------------------------------
// SPI VIP package - each class lives in its own .svh, included here
//-----------------------------------------------------------------------------
package spi_vip_pkg;

  import uvm_pkg::*;

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



  `include "spi_transaction.svh"
  `include "spi_config.svh"
  `include "spi_callback.svh"
  `include "spi_coverage.svh"
  `include "spi_sequencer.svh"
  `include "spi_driver_master.svh"
  `include "spi_driver_slave.svh"
  `include "spi_monitor.svh"
  `include "spi_agent.svh"
  `include "spi_seq_lib.svh"

endpackage : spi_vip_pkg

//-----------------------------------------------------------------------------
// DUT glue package (register BFM + env + test)
//-----------------------------------------------------------------------------
package spi_dut_pkg;

  import uvm_pkg::*;
  import spi_vip_pkg::*;

  `include "spi_reg_bfm.svh"
  `include "spi_dut_env.svh"
  `include "spi_dut_test.svh"

endpackage : spi_dut_pkg

//-----------------------------------------------------------------------------
// Top-level module - instantiates the DUT (design.sv) and wires the VIP
//-----------------------------------------------------------------------------
module top;

  import uvm_pkg::*;
  import spi_vip_pkg::*;
  import spi_dut_pkg::*;

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #10 clk = ~clk;   // 20ns period -> 50 MHz

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // ---- VIP-side SPI bus ----
  spi_if #(.NUM_CS(1)) bus ();
  spi_reg_if reg_if (.clk(clk), .rst_n(rst_n));

  // ---- the DUT (defined in design.sv) ----
  spi_slave_core #(
      .DATA_WIDTH (8)
  ) dut (
      .clk      (clk),
      .rst_n    (rst_n),

      .sclk     (bus.sclk),
      .mosi     (bus.mosi),
      .miso     (bus.miso),
      .cs_n     (bus.cs_n[0]),

      .tx_data  (reg_if.tx_data),
      .tx_load  (reg_if.tx_load),
      .rx_data  (reg_if.rx_data),
      .rx_valid (reg_if.rx_valid)
  );

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, top);
  end

  initial begin
    uvm_config_db#(virtual spi_if)::set(null, "*", "vif", bus);
    uvm_config_db#(virtual spi_reg_if)::set(null, "*", "vif_reg", reg_if);
    run_test("spi_dut_test");
  end

endmodule : top
