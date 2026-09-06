//=============================================================================
// File        : example/tb_top.sv
// Description : Minimal top-level module. Instantiates the wire, pushes the
//               virtual interface into config_db, runs the test.
//=============================================================================
module tb_top;

  import uvm_pkg::*;
  import uart_vip_pkg::*;
  import uart_example_pkg::*;

  uart_if wire_line();

  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif", wire_line);
    run_test("uart_loopback_test");
  end

endmodule : tb_top
