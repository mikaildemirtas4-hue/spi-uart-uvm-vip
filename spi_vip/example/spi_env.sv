//=============================================================================
// File        : example/spi_env.sv
// Description : Example environment: one MASTER agent + one SLAVE agent on
//               the same physical bus. Useful as a VIP-to-VIP loopback
//               sanity check, and as a template for hooking a real DUT into
//               either side (just delete the agent that plays the DUT's
//               role and wire spi_if directly to the DUT pins instead).
//=============================================================================
class spi_example_env extends uvm_env;

  `uvm_component_utils(spi_example_env)

  spi_agent  m_agent;   // master side
  spi_agent  s_agent;   // slave side

  spi_config m_cfg;
  spi_config s_cfg;

  spi_loopback_checker chk;
  spi_master_record_cb tx_cb;   // records what the master is about to send on MOSI
  spi_slave_record_cb  rx_cb;   // records what the slave is about to send on MISO
  spi_bus_check_cb      bus_cb; // compares both against what the bus monitor decodes

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual spi_if vif;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
      `uvm_fatal("SPI_ENV", "virtual spi_if not found in config_db")

    m_cfg           = spi_config::type_id::create("m_cfg");
    m_cfg.vif       = vif;
    m_cfg.is_master = 1;
    m_cfg.is_active = UVM_ACTIVE;
    m_cfg.mode      = SPI_MODE_0;
    m_cfg.num_cs    = 1;
    uvm_config_db#(spi_config)::set(this, "m_agent*", "cfg", m_cfg);

    s_cfg           = spi_config::type_id::create("s_cfg");
    s_cfg.vif       = vif;
    s_cfg.is_master = 0;
    s_cfg.is_active = UVM_ACTIVE;
    s_cfg.mode      = SPI_MODE_0;   // must match m_cfg.mode - both sides of one physical bus
    s_cfg.num_cs    = 1;
    uvm_config_db#(spi_config)::set(this, "s_agent*", "cfg", s_cfg);

    m_agent = spi_agent::type_id::create("m_agent", this);
    s_agent = spi_agent::type_id::create("s_agent", this);

    chk    = spi_loopback_checker::type_id::create("chk", this);
    tx_cb  = spi_master_record_cb::type_id::create("tx_cb");
    rx_cb  = spi_slave_record_cb::type_id::create("rx_cb");
    bus_cb = spi_bus_check_cb::type_id::create("bus_cb");
    tx_cb.chk  = chk;
    rx_cb.chk  = chk;
    bus_cb.chk = chk;
  endfunction

  function void connect_phase(uvm_phase phase);
    spi_driver_master m_drv;
    spi_driver_slave  s_drv;
    super.connect_phase(phase);

    if (!$cast(m_drv, m_agent.driver))
      `uvm_fatal("SPI_ENV", "m_agent.driver is not a spi_driver_master")
    if (!$cast(s_drv, s_agent.driver))
      `uvm_fatal("SPI_ENV", "s_agent.driver is not a spi_driver_slave")

    uvm_callbacks#(spi_driver_master, spi_callback)::add(m_drv, tx_cb);
    uvm_callbacks#(spi_driver_slave,  spi_callback)::add(s_drv, rx_cb);
    uvm_callbacks#(spi_monitor,       spi_callback)::add(m_agent.monitor, bus_cb);
  endfunction

endclass : spi_example_env
