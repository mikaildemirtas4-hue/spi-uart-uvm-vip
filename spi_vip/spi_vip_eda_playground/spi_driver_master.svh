//=============================================================================
// File        : spi_driver_master.sv
// Description : Drives the bus as MASTER - generates sclk, drives mosi and
//               cs_n, samples miso. Implements all 4 standard SPI modes:
//
//                 Mode | CPOL | CPHA | Idle clk | Sample edge | Shift edge
//                 -----+------+------+----------+-------------+-----------
//                   0  |  0   |  0   |   low    |   rising     |  falling
//                   1  |  0   |  1   |   low    |   falling    |  rising
//                   2  |  1   |  0   |   high   |   falling    |  rising
//                   3  |  1   |  1   |   high   |   rising     |  falling
//=============================================================================
class spi_driver_master extends uvm_driver #(spi_transaction);

  `uvm_component_utils(spi_driver_master)
  `uvm_register_cb(spi_driver_master, spi_callback)

  spi_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(spi_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("SPI_DRV_M", "spi_config not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    // Idle the bus correctly before anything else happens.
    cfg.vif.sclk <= get_cpol();
    cfg.vif.mosi <= 1'b0;
    cfg.vif.cs_n <= idle_cs_level();

    forever begin
      spi_transaction tr;
      seq_item_port.get_next_item(tr);
      tr.mode = cfg.mode;
      `uvm_do_callbacks(spi_driver_master, spi_callback, pre_drive(this, tr))
      drive_transfer(tr);
      seq_item_port.item_done();
    end
  endtask

  //---------------------------------------------------------------------
  function bit get_cpol(); return (cfg.mode == SPI_MODE_2 || cfg.mode == SPI_MODE_3); endfunction
  function bit get_cpha(); return (cfg.mode == SPI_MODE_1 || cfg.mode == SPI_MODE_3); endfunction

  function bit idle_cs_level();   return (cfg.cs_polarity == SPI_CS_ACTIVE_LOW) ? 1'b1 : 1'b0; endfunction
  function bit active_cs_level(); return (cfg.cs_polarity == SPI_CS_ACTIVE_LOW) ? 1'b0 : 1'b1; endfunction

  // Honors bit_order (MSB-first or LSB-first) when picking which bit of a
  // word to drive/capture at a given transfer index.
  function bit get_tx_bit(bit [SPI_MAX_WIDTH-1:0] data, int width, int index);
    return (cfg.bit_order == SPI_MSB_FIRST) ? data[width-1-index] : data[index];
  endfunction

  function void set_rx_bit(ref bit [SPI_MAX_WIDTH-1:0] data, input int width, input int index, input bit val);
    if (cfg.bit_order == SPI_MSB_FIRST) data[width-1-index] = val;
    else                                data[index]         = val;
  endfunction

  //---------------------------------------------------------------------
  task drive_transfer(spi_transaction tr);
    bit  cpol  = get_cpol();
    bit  cpha  = get_cpha();
    int  width = tr.num_bits;
    real half_period = cfg.clk_period_ns / 2.0;
    bit [SPI_MAX_WIDTH-1:0] rx_word = '0;
    int  cs_line = tr.cs_index % cfg.num_cs;

    cfg.vif.cs_n[cs_line] <= active_cs_level();
    #(cfg.cs_setup_time_ns * 1ns);

    // CPHA=0: first bit must be valid BEFORE the first (leading) edge.
    if (!cpha)
      cfg.vif.mosi <= get_tx_bit(tr.mosi_data, width, 0);

    for (int i = 0; i < width; i++) begin
      // ---- Leading edge ----
      cfg.vif.sclk <= !cpol;
      #(half_period * 1ns);
      if (!cpha) set_rx_bit(rx_word, width, i, cfg.vif.miso);
      else       cfg.vif.mosi <= get_tx_bit(tr.mosi_data, width, i);

      // ---- Trailing edge ----
      cfg.vif.sclk <= cpol;
      #(half_period * 1ns);
      if (!cpha) begin
        if (i < width - 1) cfg.vif.mosi <= get_tx_bit(tr.mosi_data, width, i + 1);
      end else begin
        set_rx_bit(rx_word, width, i, cfg.vif.miso);
      end
    end

    #(cfg.cs_hold_time_ns * 1ns);
    cfg.vif.cs_n[cs_line] <= idle_cs_level();
    #(cfg.inter_word_gap_ns * 1ns);

    tr.miso_data = rx_word;
  endtask

endclass : spi_driver_master
