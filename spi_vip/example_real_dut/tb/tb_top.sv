//=============================================================================
// File        : tb/tb_top.sv
// Description : Instantiates the real spi_slave_core DUT and wires the SPI
//               VIP (master role) directly to its sclk/mosi/miso/cs_n pins,
//               plus a small BFM on its parallel register port.
//=============================================================================
module tb_top;

  import uvm_pkg::*;
  import spi_vip_pkg::*;
  import spi_dut_pkg::*;

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #10 clk = ~clk;   // 20ns period -> 50 MHz (DUT system clock)

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // ---- VIP-side SPI bus ----
  spi_if #(.NUM_CS(1)) bus ();
  spi_reg_if reg_if (.clk(clk), .rst_n(rst_n));

  // ---- the real DUT (defined in design.sv) ----
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
    $dumpvars(0, tb_top);
  end

  initial begin
    uvm_config_db#(virtual spi_if)::set(null, "*", "vif", bus);
    uvm_config_db#(virtual spi_reg_if)::set(null, "*", "vif_reg", reg_if);
    run_test("spi_dut_test");
  end

endmodule : tb_top
