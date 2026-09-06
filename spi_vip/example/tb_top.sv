//=============================================================================
// File        : example/tb_top.sv
// Description : Minimal top-level module. Instantiates the bus, pushes the
//               virtual interface into config_db, runs the test.
//=============================================================================
module tb_top;

  import uvm_pkg::*;
  import spi_vip_pkg::*;
  import spi_example_pkg::*;

  spi_if #(.NUM_CS(1)) bus();

  initial begin
    uvm_config_db#(virtual spi_if)::set(null, "*", "vif", bus);
    run_test("spi_loopback_test");
  end

endmodule : tb_top
