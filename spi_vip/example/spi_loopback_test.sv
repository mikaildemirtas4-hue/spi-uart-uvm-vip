//=============================================================================
// File        : example/spi_loopback_test.sv
// Description : Master sends a random burst while the slave continuously
//               supplies response words - proves the VIP's mode-0..3 timing
//               is correct end-to-end, with zero DUT involved. Change
//               env.m_cfg.mode / env.s_cfg.mode to sweep all 4 modes.
//=============================================================================
class spi_loopback_test extends uvm_test;

  `uvm_component_utils(spi_loopback_test)

  spi_example_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = spi_example_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    spi_random_burst_seq   m_seq;
    spi_slave_response_seq s_seq;

    phase.raise_objection(this);

    fork
      begin : slave_side
        // Keep supplying response words for as long as the master is active.
        forever begin
          s_seq = spi_slave_response_seq::type_id::create("s_seq");
          assert(s_seq.randomize());
          s_seq.start(env.s_agent.sequencer);
        end
      end
      begin : master_side
        m_seq = spi_random_burst_seq::type_id::create("m_seq");
        assert(m_seq.randomize() with { num_transfers == 20; fixed_num_bits == 8; });
        m_seq.start(env.m_agent.sequencer);
      end
    join_any
    disable fork;

    #(env.m_cfg.clk_period_ns * 4 * 1ns); // let the last transaction's monitor decode settle

    `uvm_info("SPI_LOOPBACK_TEST",
              $sformatf("Checker totals: %0d pass / %0d fail", env.chk.pass_count, env.chk.fail_count),
              UVM_LOW)
    if (env.chk.fail_count > 0)
      `uvm_error("SPI_LOOPBACK_TEST", "One or more MOSI/MISO checks failed - see log above")

    phase.drop_objection(this);
  endtask

endclass : spi_loopback_test
