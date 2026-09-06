//=============================================================================
// File        : example/spi_loopback_checker.sv
// Description : Scoreboard-style checker for the master<->slave loopback.
//               Since SPI is full-duplex, a single bus transaction carries
//               BOTH directions at once:
//                 - master's driver records what it's about to send on
//                   MOSI (pre_drive callback) into expected_mosi_q
//                 - slave's driver records what it's about to send on
//                   MISO (pre_drive callback) into expected_miso_q
//                 - the master agent's monitor decodes the completed bus
//                   transaction (post_transaction callback) and checks
//                   both queues against what actually appeared on the wire
//=============================================================================
class spi_loopback_checker extends uvm_component;

  `uvm_component_utils(spi_loopback_checker)

  bit [SPI_MAX_WIDTH-1:0] expected_mosi_q[$];
  bit [SPI_MAX_WIDTH-1:0] expected_miso_q[$];
  int pass_count = 0;
  int fail_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void note_mosi_sent(bit [SPI_MAX_WIDTH-1:0] data);
    expected_mosi_q.push_back(data);
  endfunction

  function void note_miso_sent(bit [SPI_MAX_WIDTH-1:0] data);
    expected_miso_q.push_back(data);
  endfunction

  function void check_transaction(spi_transaction tr);
    bit [SPI_MAX_WIDTH-1:0] exp_mosi;
    bit [SPI_MAX_WIDTH-1:0] exp_miso;
    bit ok = 1;

    if (expected_mosi_q.size() == 0 || expected_miso_q.size() == 0) begin
      `uvm_error("SPI_CHK", "Observed a bus transaction but nothing was expected on one or both wires")
      fail_count++;
      return;
    end

    exp_mosi = expected_mosi_q.pop_front();
    exp_miso = expected_miso_q.pop_front();

    if (exp_mosi !== tr.mosi_data) begin
      `uvm_error("SPI_CHK", $sformatf("MOSI MISMATCH: master sent 0x%0h, bus decoded 0x%0h",
                                       exp_mosi, tr.mosi_data))
      ok = 0;
    end

    if (exp_miso !== tr.miso_data) begin
      `uvm_error("SPI_CHK", $sformatf("MISO MISMATCH: slave sent 0x%0h, bus decoded 0x%0h",
                                       exp_miso, tr.miso_data))
      ok = 0;
    end

    if (ok) begin
      `uvm_info("SPI_CHK", $sformatf("OK: mosi=0x%0h miso=0x%0h", tr.mosi_data, tr.miso_data), UVM_MEDIUM)
      pass_count++;
    end else begin
      fail_count++;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SPI_CHK", $sformatf("Loopback check done: %0d pass / %0d fail",
                                    pass_count, fail_count), UVM_LOW)
  endfunction

endclass : spi_loopback_checker


class spi_master_record_cb extends spi_callback;
  `uvm_object_utils(spi_master_record_cb)
  spi_loopback_checker chk;

  function new(string name = "spi_master_record_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(uvm_component originator, spi_transaction tr);
    chk.note_mosi_sent(tr.mosi_data);
  endtask
endclass : spi_master_record_cb


class spi_slave_record_cb extends spi_callback;
  `uvm_object_utils(spi_slave_record_cb)
  spi_loopback_checker chk;

  function new(string name = "spi_slave_record_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(uvm_component originator, spi_transaction tr);
    chk.note_miso_sent(tr.miso_data);
  endtask
endclass : spi_slave_record_cb


class spi_bus_check_cb extends spi_callback;
  `uvm_object_utils(spi_bus_check_cb)
  spi_loopback_checker chk;

  function new(string name = "spi_bus_check_cb");
    super.new(name);
  endfunction

  virtual task post_transaction(uvm_component originator, spi_transaction tr);
    chk.check_transaction(tr);
  endtask
endclass : spi_bus_check_cb
