//=============================================================================
// File        : spi_monitor.sv
// Description : Passively observes the raw SPI wires and reconstructs
//               completed transactions - works identically whether the local
//               agent is master or slave, and whether it's active or passive.
//
//               Word length is NOT assumed: the monitor counts bits until
//               CS de-asserts, since SPI itself carries no explicit framing.
//
// Limitation  : this simple monitor tracks one CS line at a time - two CS
//               lines toggling simultaneously on the same physical bus is
//               not a normal SPI scenario, so this is not considered a gap.
//=============================================================================
class spi_monitor extends uvm_monitor;

  `uvm_component_utils(spi_monitor)
  `uvm_register_cb(spi_monitor, spi_callback)

  spi_config cfg;
  uvm_analysis_port #(spi_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(spi_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("SPI_MON", "spi_config not found in config_db")
  endfunction

  function bit get_cpol(); return (cfg.mode == SPI_MODE_2 || cfg.mode == SPI_MODE_3); endfunction
  function bit get_cpha(); return (cfg.mode == SPI_MODE_1 || cfg.mode == SPI_MODE_3); endfunction
  function bit active_cs_level(); return (cfg.cs_polarity == SPI_CS_ACTIVE_LOW) ? 1'b0 : 1'b1; endfunction

  function void set_rx_bit(ref bit [SPI_MAX_WIDTH-1:0] data, input int width, input int index, input bit val);
    if (cfg.bit_order == SPI_MSB_FIRST) data[width-1-index] = val;
    else                                data[index]         = val;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      int cs_line;
      wait_for_any_cs_active(cs_line);
      collect_transaction(cs_line);
    end
  endtask

  task wait_for_any_cs_active(output int cs_line);
    forever begin
      @(cfg.vif.cs_n);
      for (int i = 0; i < cfg.num_cs; i++) begin
        if (cfg.vif.cs_n[i] === active_cs_level()) begin
          cs_line = i;
          return;
        end
      end
    end
  endtask

  task collect_transaction(int cs_line);
    spi_transaction tr;
    bit cpol = get_cpol();
    bit cpha = get_cpha();
    bit mosi_bits[$];
    bit miso_bits[$];
    time t_start = $time;

    while (cfg.vif.cs_n[cs_line] === active_cs_level()) begin
      // Leading edge (or early exit if CS drops first)
      fork
        begin : w_lead
          if (!cpol) @(posedge cfg.vif.sclk); else @(negedge cfg.vif.sclk);
        end
        begin : w_cs1
          @(cfg.vif.cs_n);
        end
      join_any
      disable fork;
      if (cfg.vif.cs_n[cs_line] !== active_cs_level()) break;

      if (!cpha) begin
        mosi_bits.push_back(cfg.vif.mosi);
        miso_bits.push_back(cfg.vif.miso);
      end

      // Trailing edge (or early exit if CS drops first)
      fork
        begin : w_trail
          if (!cpol) @(negedge cfg.vif.sclk); else @(posedge cfg.vif.sclk);
        end
        begin : w_cs2
          @(cfg.vif.cs_n);
        end
      join_any
      disable fork;
      if (cfg.vif.cs_n[cs_line] !== active_cs_level()) break;

      if (cpha) begin
        mosi_bits.push_back(cfg.vif.mosi);
        miso_bits.push_back(cfg.vif.miso);
      end
    end

    if (mosi_bits.size() == 0) return; // spurious CS glitch, nothing captured

    tr = spi_transaction::type_id::create("mon_tr");
    tr.mode      = cfg.mode;
    tr.cs_index  = cs_line;
    tr.num_bits  = mosi_bits.size();
    tr.mosi_data = '0;
    tr.miso_data = '0;
    // Riviera-PRO note: a `foreach` loop index is a read-only special
    // variable and some tools refuse to let it appear as an actual
    // argument to any function containing a `ref` parameter (even when
    // bound to a by-value parameter). Use a plain `for` loop instead.
    for (int i = 0; i < mosi_bits.size(); i++) begin
      set_rx_bit(tr.mosi_data, tr.num_bits, i, mosi_bits[i]);
      set_rx_bit(tr.miso_data, tr.num_bits, i, miso_bits[i]);
    end
    tr.start_time = t_start;
    tr.end_time   = $time;

    `uvm_do_callbacks(spi_monitor, spi_callback, post_transaction(this, tr))
    ap.write(tr);
    `uvm_info("SPI_MON", $sformatf("Captured: %s", tr.convert2string()), UVM_HIGH)
  endtask

endclass : spi_monitor
