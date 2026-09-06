//=============================================================================
// File        : seq_lib/spi_seq_lib.sv
// Description : Reusable sequence library shipped with the VIP. Extend
//               spi_base_sequence for anything project-specific.
//=============================================================================

// Base class - all project sequences should extend this.
class spi_base_sequence extends uvm_sequence #(spi_transaction);
  `uvm_object_utils(spi_base_sequence)
  function new(string name = "spi_base_sequence");
    super.new(name);
  endfunction
endclass : spi_base_sequence


// MASTER-role helper: drives one fully specified word out on MOSI.
// After start() returns, `rsp` holds the completed transaction, so a test
// or virtual sequence can inspect the captured miso_data (the response
// the bus produced during this transfer).
class spi_single_transfer_seq extends spi_base_sequence;

  `uvm_object_utils(spi_single_transfer_seq)

  rand bit [SPI_MAX_WIDTH-1:0] data;
  rand int unsigned            num_bits = 8;
  rand int unsigned            cs_index = 0;

  constraint c_num_bits_range { num_bits inside {[1:SPI_MAX_WIDTH]}; }

  spi_transaction rsp;

  function new(string name = "spi_single_transfer_seq");
    super.new(name);
  endfunction

  task body();
    spi_transaction tr = spi_transaction::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize() with {
          mosi_data == data;
          num_bits  == local::num_bits;
          cs_index  == local::cs_index;
        })
      `uvm_error(get_type_name(), "Randomization failed")
    finish_item(tr);
    rsp = tr;
  endtask

endclass : spi_single_transfer_seq


// SLAVE-role helper: supplies one response word to drive out on MISO the
// next time this agent's CS line is asserted by an external master.
class spi_slave_response_seq extends spi_base_sequence;

  `uvm_object_utils(spi_slave_response_seq)

  rand bit [SPI_MAX_WIDTH-1:0] response_data;
  rand int unsigned            num_bits = 8;

  constraint c_num_bits_range { num_bits inside {[1:SPI_MAX_WIDTH]}; }

  function new(string name = "spi_slave_response_seq");
    super.new(name);
  endfunction

  task body();
    spi_transaction tr = spi_transaction::type_id::create("tr");
    start_item(tr);
    if (!tr.randomize() with {
          miso_data == response_data;
          num_bits  == local::num_bits;
        })
      `uvm_error(get_type_name(), "Randomization failed")
    finish_item(tr);
  endtask

endclass : spi_slave_response_seq


// MASTER-role helper: sends N fully random words back-to-back.
class spi_random_burst_seq extends spi_base_sequence;

  `uvm_object_utils(spi_random_burst_seq)

  rand int unsigned num_transfers  = 10;
  rand int unsigned fixed_num_bits = 0; // 0 = let each transfer randomize its own width

  constraint c_reasonable {
    num_transfers  inside {[1:1000]};
    fixed_num_bits inside {0, [1:SPI_MAX_WIDTH]};
  }

  function new(string name = "spi_random_burst_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_transfers) begin
      spi_transaction tr = spi_transaction::type_id::create("tr");
      start_item(tr);
      if (fixed_num_bits != 0) assert(tr.randomize() with { num_bits == local::fixed_num_bits; });
      else                     assert(tr.randomize());
      finish_item(tr);
    end
  endtask

endclass : spi_random_burst_seq


// MASTER-role helper: smoke-test pattern useful right after bring-up -
// cycles a few recognizable data patterns through the currently configured
// mode (change cfg.mode between runs to sweep all 4 modes).
class spi_all_modes_smoke_seq extends spi_base_sequence;

  `uvm_object_utils(spi_all_modes_smoke_seq)

  function new(string name = "spi_all_modes_smoke_seq");
    super.new(name);
  endfunction

  task body();
    bit [7:0] pattern[4] = '{8'hA5, 8'h5A, 8'hFF, 8'h00};
    foreach (pattern[i]) begin
      spi_transaction tr = spi_transaction::type_id::create("tr");
      start_item(tr);
      assert(tr.randomize() with { mosi_data == pattern[i]; num_bits == 8; });
      finish_item(tr);
    end
  endtask

endclass : spi_all_modes_smoke_seq
