//=============================================================================
// File        : example/uart_loopback_checker.sv
// Description : Tiny scoreboard-style checker used by the loopback example.
//               Two callbacks feed it: one on the TX driver (records what
//               was sent) and one on the RX monitor (compares what arrived).
//=============================================================================
class uart_loopback_checker extends uvm_component;

  `uvm_component_utils(uart_loopback_checker)

  bit [UART_MAX_DATA_BITS-1:0] expected_q[$];
  int pass_count = 0;
  int fail_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void note_sent(bit [UART_MAX_DATA_BITS-1:0] data);
    expected_q.push_back(data);
  endfunction

  function void check_received(uart_transaction tr);
    bit [UART_MAX_DATA_BITS-1:0] exp;

    if (tr.break_detected) begin
      // A BREAK is not a byte transfer - don't touch expected_q or
      // fail_count, the break test checks this transaction directly.
      `uvm_info("UART_CHK", "BREAK condition observed (not counted as pass/fail)", UVM_LOW)
      return;
    end

    if (tr.framing_error || tr.parity_error) begin
      `uvm_error("UART_CHK", $sformatf("Frame error on received byte: %s", tr.convert2string()))
      fail_count++;
      return;
    end

    if (expected_q.size() == 0) begin
      `uvm_error("UART_CHK", "Received a byte but nothing was expected")
      fail_count++;
      return;
    end

    exp = expected_q.pop_front();
    if (exp !== tr.data) begin
      `uvm_error("UART_CHK", $sformatf("MISMATCH: sent 0x%0h, received 0x%0h", exp, tr.data))
      fail_count++;
    end else begin
      `uvm_info("UART_CHK", $sformatf("OK: 0x%0h", tr.data), UVM_LOW)
      pass_count++;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("UART_CHK", $sformatf("Loopback check done: %0d pass / %0d fail",
                                     pass_count, fail_count), UVM_LOW)
  endfunction

endclass : uart_loopback_checker


class uart_tx_record_cb extends uart_callback;
  `uvm_object_utils(uart_tx_record_cb)
  uart_loopback_checker chk;

  function new(string name = "uart_tx_record_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(uvm_component originator, uart_transaction tr);
    chk.note_sent(tr.data);
  endtask
endclass : uart_tx_record_cb


class uart_rx_check_cb extends uart_callback;
  `uvm_object_utils(uart_rx_check_cb)
  uart_loopback_checker chk;

  function new(string name = "uart_rx_check_cb");
    super.new(name);
  endfunction

  virtual task post_transaction(uvm_component originator, uart_transaction tr);
    chk.check_received(tr);
  endtask
endclass : uart_rx_check_cb
