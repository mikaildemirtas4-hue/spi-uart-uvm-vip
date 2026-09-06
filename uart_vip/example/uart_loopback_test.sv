//=============================================================================
// File        : example/uart_loopback_test.sv
// Description : Three scenarios in one run:
//   1) Baseline: a readable ASCII string + a random byte stream at the
//      default 8N1 format, checked byte-for-byte by uart_loopback_checker.
//   2) Format sweep: every parity (none/odd/even/mark/space) x stop-bit
//      (1.0/1.5/2.0) combination, a handful of random bytes each - proves
//      the VIP's framing is correct across the full format space, not
//      just the common 8N1 case.
//   3) Break-condition check: drives a BREAK (line held low past a full
//      frame) and confirms the monitor flags it via break_detected,
//      independent of the byte-matching checker (a break isn't a byte).
//=============================================================================
class uart_loopback_test extends uvm_test;

  `uvm_component_utils(uart_loopback_test)

  uart_example_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_example_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    uart_string_seq         str_seq;
    uart_random_stream_seq  rnd_seq;

    phase.raise_objection(this);

    // --- 1) Baseline: default 8N1 format ---
    str_seq = uart_string_seq::type_id::create("str_seq");
    str_seq.message = "Merhaba UART";
    str_seq.start(env.tx_agent.sequencer);

    rnd_seq = uart_random_stream_seq::type_id::create("rnd_seq");
    assert(rnd_seq.randomize() with { num_bytes == 20; });
    rnd_seq.start(env.tx_agent.sequencer);

    // --- 2) Sweep every parity x stop-bit combination ---
    run_format_sweep();

    // --- 3) Restore a known-good format, then check BREAK detection ---
    set_format(UART_PARITY_NONE, 1.0);
    run_break_check();

    `uvm_info("UART_LOOPBACK_TEST",
              $sformatf("Checker totals: %0d pass / %0d fail",
                        env.chk.pass_count, env.chk.fail_count),
              UVM_LOW)
    if (env.chk.fail_count > 0)
      `uvm_error("UART_LOOPBACK_TEST", "One or more byte checks failed - see log above")

    phase.drop_objection(this);
  endtask

  // Both agents hold their OWN config object (tx_cfg/rx_cfg are separate,
  // not the same handle), so a format change must be applied to both.
  task set_format(uart_parity_e parity, real stop_bits);
    env.tx_cfg.parity        = parity;
    env.tx_cfg.num_stop_bits = stop_bits;
    env.rx_cfg.parity        = parity;
    env.rx_cfg.num_stop_bits = stop_bits;
  endtask

  task run_format_sweep();
    uart_parity_e parities[5]  = '{UART_PARITY_NONE, UART_PARITY_ODD, UART_PARITY_EVEN,
                                    UART_PARITY_MARK, UART_PARITY_SPACE};
    real          stop_opts[3] = '{1.0, 1.5, 2.0};

    foreach (parities[p]) begin
      foreach (stop_opts[s]) begin
        uart_random_stream_seq seq;
        set_format(parities[p], stop_opts[s]);

        `uvm_info("UART_LOOPBACK_TEST",
                  $sformatf("--- sweep: parity=%s stop_bits=%0.1f ---",
                            parities[p].name(), stop_opts[s]),
                  UVM_LOW)

        seq = uart_random_stream_seq::type_id::create("seq");
        assert(seq.randomize() with { num_bytes == 5; });
        seq.start(env.tx_agent.sequencer);
      end
    end
  endtask

  task run_break_check();
    uart_transaction tr;

    `uvm_info("UART_LOOPBACK_TEST", "--- sending BREAK condition ---", UVM_LOW)
    env.tx_agent.driver.send_break();

    env.rx_fifo.get(tr);
    if (!tr.break_detected) begin
      `uvm_error("UART_LOOPBACK_TEST",
                 $sformatf("Expected a BREAK condition, got: %s", tr.convert2string()))
    end else begin
      `uvm_info("UART_LOOPBACK_TEST", "BREAK correctly detected", UVM_LOW)
    end
  endtask

endclass : uart_loopback_test
