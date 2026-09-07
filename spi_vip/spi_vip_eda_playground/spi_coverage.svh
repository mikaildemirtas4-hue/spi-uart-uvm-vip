//=============================================================================
// File        : spi_coverage.sv
// Description : Functional coverage collector. Subscribes to the monitor's
//               analysis port, so it sees every completed transaction
//               regardless of whether the local agent is active or passive.
//=============================================================================
class spi_coverage extends uvm_subscriber #(spi_transaction);

  `uvm_component_utils(spi_coverage)

  spi_config      cfg;
  spi_transaction tr;

  covergroup cg_spi;
    option.per_instance = 1;

    cp_mode: coverpoint tr.mode {
      bins mode0 = {SPI_MODE_0};
      bins mode1 = {SPI_MODE_1};
      bins mode2 = {SPI_MODE_2};
      bins mode3 = {SPI_MODE_3};
    }

    cp_width: coverpoint tr.num_bits {
      bins w4    = {4};
      bins w8    = {8};
      bins w16   = {16};
      bins w32   = {32};
      bins other = default;
    }

    cp_cs: coverpoint tr.cs_index {
      bins cs[] = {[0:15]};
    }

    cp_mosi_zero: coverpoint (tr.mosi_data == '0) { bins yes = {1}; bins no = {0}; }
    cp_mosi_ones: coverpoint (&tr.mosi_data)      { bins yes = {1}; bins no = {0}; }

    cx_mode_width: cross cp_mode, cp_width;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_spi = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(spi_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("SPI_COV", "spi_config not found in config_db")
  endfunction

  function void write(spi_transaction t);
    tr = t;
    if (cfg.enable_coverage) cg_spi.sample();
  endfunction

endclass : spi_coverage
