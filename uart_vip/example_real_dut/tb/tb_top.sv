//=============================================================================
// File        : tb/tb_top.sv
// Description : THE key file for connecting the VIP to a real DUT.
//
//               Two independent uart_if wires are instantiated (one per
//               direction, see uart_vip/README.md), plus one uart_reg_if
//               for the DUT's parallel port. All three are bound directly
//               to uart_core's ports in the instantiation below - that
//               port-map IS the integration step. Everything else (clocks,
//               reset, config_db, run_test) is boilerplate you'll reuse
//               for any DUT.
//=============================================================================
module tb_top;

  import uvm_pkg::*;
  import uart_vip_pkg::*;
  import uart_dut_pkg::*;

  localparam int CLK_FREQ_HZ = 50_000_000;
  localparam int BAUD_RATE   = 115_200;

  logic clk;
  logic rst_n;

  // ---- clock / reset ----
  initial clk = 1'b0;
  always #10 clk = ~clk;   // 20ns period -> 50 MHz

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // ---- VIP-side wires ----
  uart_if     line_into_dut ();          // VIP TX agent  -> dut.rx_serial
  uart_if     line_from_dut ();          // dut.tx_serial -> VIP RX agent
  uart_reg_if reg_if (.clk(clk), .rst_n(rst_n));

  // ---- the real DUT ----
  uart_core #(
      .CLK_FREQ_HZ (CLK_FREQ_HZ),
      .BAUD_RATE   (BAUD_RATE)
  ) dut (
      .clk          (clk),
      .rst_n        (rst_n),

      .tx_data      (reg_if.tx_data),
      .tx_valid     (reg_if.tx_valid),
      .tx_ready     (reg_if.tx_ready),
      .tx_serial    (line_from_dut.line),   // <-- DUT drives this VIP wire

      .rx_serial    (line_into_dut.line),   // <-- VIP drives this DUT input
      .rx_data      (reg_if.rx_data),
      .rx_valid     (reg_if.rx_valid),
      .rx_frame_err (reg_if.rx_frame_err)
  );

  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif_into_dut", line_into_dut);
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif_from_dut", line_from_dut);
    uvm_config_db#(virtual uart_reg_if)::set(null, "*", "vif_reg", reg_if);

    run_test("uart_dut_test");
  end

endmodule : tb_top
