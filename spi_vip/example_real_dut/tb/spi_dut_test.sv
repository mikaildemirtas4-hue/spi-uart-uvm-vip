//=============================================================================
// File        : tb/spi_dut_test.sv
// Description : Each iteration: preload a random byte into the DUT's TX
//               register, then drive one random byte in via the VIP master.
//               Because SPI is full-duplex, this single transfer checks:
//
//   - DUT'S TRANSMITTER: the VIP master's captured miso_data must equal
//     the byte we preloaded via reg_bfm.
//   - DUT'S RECEIVER: the byte the DUT reports on its parallel rx_data
//     port (via reg_bfm) must equal the byte the VIP master sent as
//     mosi_data.
//=============================================================================
class spi_dut_test extends uvm_test;

  `uvm_component_utils(spi_dut_test)

  spi_dut_env env;

  int unsigned num_transfers = 20;
  int pass_count = 0;
  int fail_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = spi_dut_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    // Wait for the DUT to actually come out of reset before touching it -
    // waiting a fixed number of clocks from t=0 isn't enough if reset
    // takes longer than that to deassert, and racing the tail end of
    // reset against the first tx_load can wipe out the very first preload.
    @(posedge env.reg_bfm.vif.rst_n);
    repeat (3) @(env.reg_bfm.vif.cb); // extra settle margin

    for (int i = 0; i < num_transfers; i++) begin
      spi_single_transfer_seq seq;
      bit [7:0] dut_tx_byte = $urandom_range(0, 255);
      bit [7:0] vip_mosi_byte = $urandom_range(0, 255);
      bit [7:0] dut_rx_byte;

      env.reg_bfm.load_tx_byte(dut_tx_byte);

      seq = spi_single_transfer_seq::type_id::create("seq");
      seq.data     = vip_mosi_byte;
      seq.num_bits = 8;
      seq.cs_index = 0;

      fork
        seq.start(env.m_agent.sequencer);
        env.reg_bfm.wait_for_rx_byte(dut_rx_byte);
      join

      check_transfer(dut_tx_byte, vip_mosi_byte, dut_rx_byte, seq.rsp.miso_data);
    end

    `uvm_info("SPI_DUT_TEST", $sformatf("RESULT: %0d pass / %0d fail", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SPI_DUT_TEST", "One or more checks failed - see log above")

    phase.drop_objection(this);
  endtask

  task check_transfer(bit [7:0] dut_tx_byte, bit [7:0] vip_mosi_byte,
                      bit [7:0] dut_rx_byte, bit [7:0] vip_miso_byte);
    bit ok = 1;

    if (dut_rx_byte !== vip_mosi_byte) begin
      `uvm_error("SPI_DUT_TEST",
                 $sformatf("DUT receiver MISMATCH: VIP sent 0x%0h on MOSI, DUT rx_data = 0x%0h",
                           vip_mosi_byte, dut_rx_byte))
      ok = 0;
    end

    if (vip_miso_byte !== dut_tx_byte) begin
      `uvm_error("SPI_DUT_TEST",
                 $sformatf("DUT transmitter MISMATCH: DUT preloaded 0x%0h, VIP captured miso=0x%0h",
                           dut_tx_byte, vip_miso_byte))
      ok = 0;
    end

    if (ok) begin
      `uvm_info("SPI_DUT_TEST",
                 $sformatf("OK: mosi=0x%0h (DUT rx matched), miso=0x%0h (DUT tx matched)",
                           vip_mosi_byte, vip_miso_byte),
                 UVM_MEDIUM)
      pass_count++;
    end else begin
      fail_count++;
    end
  endtask

endclass : spi_dut_test
