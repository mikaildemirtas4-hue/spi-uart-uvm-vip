//=============================================================================
// File        : spi_driver_slave.sv
// Description : Drives the bus as SLAVE - reacts to an externally generated
//               sclk/cs_n (from a real master DUT or a master agent), drives
//               miso with response data, samples mosi. Supports all 4 modes.
//
//               NOTE: fill in tr.miso_data (the response you want to send)
//               before calling finish_item() on this driver's sequencer.
//               After the transfer, tr.mosi_data holds what the master sent.
//=============================================================================
class spi_driver_slave extends uvm_driver #(spi_transaction);

  `uvm_component_utils(spi_driver_slave)
  `uvm_register_cb(spi_driver_slave, spi_callback)

  spi_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(spi_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("SPI_DRV_S", "spi_config not found in config_db")
  endfunction

  function bit get_cpol(); return (cfg.mode == SPI_MODE_2 || cfg.mode == SPI_MODE_3); endfunction
  function bit get_cpha(); return (cfg.mode == SPI_MODE_1 || cfg.mode == SPI_MODE_3); endfunction
  function bit active_cs_level(); return (cfg.cs_polarity == SPI_CS_ACTIVE_LOW) ? 1'b0 : 1'b1; endfunction

  function bit get_tx_bit(bit [SPI_MAX_WIDTH-1:0] data, int width, int index);
    return (cfg.bit_order == SPI_MSB_FIRST) ? data[width-1-index] : data[index];
  endfunction

  function void set_rx_bit(ref bit [SPI_MAX_WIDTH-1:0] data, input int width, input int index, input bit val);
    if (cfg.bit_order == SPI_MSB_FIRST) data[width-1-index] = val;
    else                                data[index]         = val;
  endfunction

  task run_phase(uvm_phase phase);
    cfg.vif.miso <= 1'bz;

    forever begin
      spi_transaction tr;
      bit cpol, cpha;
      int width, cs_line;
      bit [SPI_MAX_WIDTH-1:0] rx_word = '0;

      seq_item_port.get_next_item(tr);
      tr.mode = cfg.mode;
      cpol    = get_cpol();
      cpha    = get_cpha();
      width   = tr.num_bits;
      cs_line = tr.cs_index % cfg.num_cs;

      `uvm_do_callbacks(spi_driver_slave, spi_callback, pre_drive(this, tr))

      // Wait until the external master selects us.
      wait (cfg.vif.cs_n[cs_line] === active_cs_level());

      if (!cpha)
        cfg.vif.miso <= get_tx_bit(tr.miso_data, width, 0);

      for (int i = 0; i < width; i++) begin
        // Leading edge
        if (!cpol) @(posedge cfg.vif.sclk); else @(negedge cfg.vif.sclk);
        if (!cpha) set_rx_bit(rx_word, width, i, cfg.vif.mosi);
        else       cfg.vif.miso <= get_tx_bit(tr.miso_data, width, i);

        // Trailing edge
        if (!cpol) @(negedge cfg.vif.sclk); else @(posedge cfg.vif.sclk);
        if (!cpha) begin
          if (i < width - 1) cfg.vif.miso <= get_tx_bit(tr.miso_data, width, i + 1);
        end else begin
          set_rx_bit(rx_word, width, i, cfg.vif.mosi);
        end
      end

      wait (cfg.vif.cs_n[cs_line] !== active_cs_level());
      cfg.vif.miso <= 1'bz;

      tr.mosi_data = rx_word;
      seq_item_port.item_done();
    end
  endtask

endclass : spi_driver_slave
