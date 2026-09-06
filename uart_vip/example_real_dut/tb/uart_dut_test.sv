//=============================================================================
// File        : tb/uart_dut_test.sv
// Description : Exercises the real uart_core DUT from both directions:
//
//   1) DUT'S RECEIVER: VIP tx_agent sends random bytes onto dut.rx_serial;
//      reg_bfm reads back what the DUT decoded on its parallel rx_data
//      port and compares.
//
//   2) DUT'S TRANSMITTER: reg_bfm pushes random bytes into the DUT's
//      parallel tx_data port; the VIP rx_agent (passive) decodes what
//      comes out on dut.tx_serial and we compare via the env's rx_fifo.
//=============================================================================
class uart_dut_test extends uvm_test;

  `uvm_component_utils(uart_dut_test)

  uart_dut_env env;

  int unsigned num_bytes = 20;
  int pass_count = 0;
  int fail_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_dut_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    // Let the DUT come out of reset before driving anything at it.
    @(posedge env.reg_bfm.vif.rst_n);
    repeat (3) @(env.reg_bfm.vif.cb);

    test_dut_receiver();
    test_dut_transmitter();

    `uvm_info("UART_DUT_TEST",
              $sformatf("RESULT: %0d pass / %0d fail", pass_count, fail_count),
              UVM_LOW)
    if (fail_count > 0)
      `uvm_error("UART_DUT_TEST", "One or more checks failed - see log above")

    phase.drop_objection(this);
  endtask

  //---------------------------------------------------------------------
  // Scenario 1: VIP -> DUT.rx_serial, check DUT's decoded rx_data port
  //---------------------------------------------------------------------
  task test_dut_receiver();
    `uvm_info("UART_DUT_TEST", "=== Testing DUT receiver (VIP TX -> dut.rx_serial) ===", UVM_LOW)

    for (int i = 0; i < num_bytes; i++) begin
      uart_send_byte_seq seq;
      bit [7:0] sent = $urandom_range(0, 255);
      bit [7:0] got;
      bit       ferr;

      seq = uart_send_byte_seq::type_id::create("seq");
      seq.value = sent;

      fork
        seq.start(env.tx_agent.sequencer);
        env.reg_bfm.wait_for_rx_byte(got, ferr);
      join

      if (ferr) begin
        `uvm_error("UART_DUT_TEST", $sformatf("DUT reported frame error for sent byte 0x%0h", sent))
        fail_count++;
      end else if (got !== sent) begin
        `uvm_error("UART_DUT_TEST", $sformatf("MISMATCH: sent 0x%0h, DUT decoded 0x%0h", sent, got))
        fail_count++;
      end else begin
        `uvm_info("UART_DUT_TEST", $sformatf("OK (rx): 0x%0h", sent), UVM_MEDIUM)
        pass_count++;
      end
    end
  endtask

  //---------------------------------------------------------------------
  // Scenario 2: reg_bfm -> DUT.tx_data, check VIP-decoded dut.tx_serial
  //---------------------------------------------------------------------
  task test_dut_transmitter();
    `uvm_info("UART_DUT_TEST", "=== Testing DUT transmitter (dut.tx_data -> VIP RX) ===", UVM_LOW)

    for (int i = 0; i < num_bytes; i++) begin
      uart_transaction tr;
      bit [7:0] sent = $urandom_range(0, 255);

      env.reg_bfm.send_tx_byte(sent);
      env.rx_fifo.get(tr);

      if (tr.framing_error || tr.parity_error) begin
        `uvm_error("UART_DUT_TEST", $sformatf("Frame/parity error decoding DUT output: %s", tr.convert2string()))
        fail_count++;
      end else if (tr.data !== sent) begin
        `uvm_error("UART_DUT_TEST", $sformatf("MISMATCH: DUT sent 0x%0h, VIP decoded 0x%0h", sent, tr.data))
        fail_count++;
      end else begin
        `uvm_info("UART_DUT_TEST", $sformatf("OK (tx): 0x%0h", sent), UVM_MEDIUM)
        pass_count++;
      end
    end
  endtask

endclass : uart_dut_test
