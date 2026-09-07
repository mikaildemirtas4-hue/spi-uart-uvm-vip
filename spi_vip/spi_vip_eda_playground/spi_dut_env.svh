//=============================================================================
// File        : tb/spi_dut_env.sv
// Description : Real-DUT environment. The VIP agent plays MASTER and drives
//               the DUT's sclk/mosi/cs_n pins directly, reading back miso.
//               Since SPI is full-duplex, a single transfer exercises the
//               DUT's receiver (MOSI capture) AND transmitter (MISO output)
//               at the same time - unlike UART's two separate passes.
//
//               This is the template to copy for YOUR DUT: keep the VIP
//               agent as-is, just repoint the virtual interface at your
//               DUT's actual SPI pins and adapt/replace spi_reg_bfm for
//               whatever register or FIFO port your peripheral exposes.
//=============================================================================
class spi_dut_env extends uvm_env;

  `uvm_component_utils(spi_dut_env)

  spi_agent  m_agent;   // MASTER - drives the DUT's SPI pins directly
  spi_config m_cfg;

  spi_reg_bfm reg_bfm;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual spi_if     vif;
    virtual spi_reg_if vif_reg;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
      `uvm_fatal("SPI_DUT_ENV", "virtual spi_if 'vif' not found in config_db")
    if (!uvm_config_db#(virtual spi_reg_if)::get(this, "", "vif_reg", vif_reg))
      `uvm_fatal("SPI_DUT_ENV", "virtual spi_reg_if 'vif_reg' not found in config_db")

    m_cfg               = spi_config::type_id::create("m_cfg");
    m_cfg.vif           = vif;
    m_cfg.is_master     = 1;
    m_cfg.is_active     = UVM_ACTIVE;
    m_cfg.mode          = SPI_MODE_0;   // spi_slave_core is fixed to Mode 0
    m_cfg.num_cs        = 1;
    m_cfg.clk_period_ns     = 200;   // 5 MHz sclk - comfortably under the DUT's 50 MHz clk
    m_cfg.cs_setup_time_ns  = 100;   // >= a few DUT clk periods, so its CS synchronizer settles first
    m_cfg.cs_hold_time_ns   = 100;
    m_cfg.inter_word_gap_ns = 100;
    uvm_config_db#(spi_config)::set(this, "m_agent*", "cfg", m_cfg);

    m_agent = spi_agent::type_id::create("m_agent", this);

    reg_bfm     = spi_reg_bfm::type_id::create("reg_bfm");
    reg_bfm.vif = vif_reg;
  endfunction

endclass : spi_dut_env
