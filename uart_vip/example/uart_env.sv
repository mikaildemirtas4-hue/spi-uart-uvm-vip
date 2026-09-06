//=============================================================================
// File        : example/uart_env.sv
// Description : Example environment: one TX (active) agent driving the wire,
//               one RX (passive) agent decoding it - a self-loopback used
//               to prove the VIP's framing/parity/baud timing is correct
//               end-to-end, with zero DUT involved. In a real project you'd
//               instead wire the TX agent to the DUT's rx pin and/or the RX
//               agent to the DUT's tx pin.
//=============================================================================
class uart_example_env extends uvm_env;

  `uvm_component_utils(uart_example_env)

  uart_agent tx_agent;
  uart_agent rx_agent;

  uart_config tx_cfg;
  uart_config rx_cfg;

  uart_loopback_checker chk;
  uart_tx_record_cb      tx_cb;
  uart_rx_check_cb       rx_cb;

  // Fed from the same rx_agent.ap as the checker above, but independent of
  // it - used by tests (e.g. the break-condition scenario) that want to
  // inspect a decoded transaction directly instead of going through the
  // byte-matching checker.
  uvm_tlm_analysis_fifo #(uart_transaction) rx_fifo;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual uart_if vif;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
      `uvm_fatal("UART_ENV", "virtual uart_if not found in config_db")

    tx_cfg               = uart_config::type_id::create("tx_cfg");
    tx_cfg.vif            = vif;
    tx_cfg.role            = UART_ROLE_TX;
    tx_cfg.is_active       = UVM_ACTIVE;
    tx_cfg.baud_rate       = 115_200;
    tx_cfg.num_data_bits   = 8;
    tx_cfg.parity          = UART_PARITY_EVEN;
    tx_cfg.num_stop_bits   = 1.0;
    uvm_config_db#(uart_config)::set(this, "tx_agent*", "cfg", tx_cfg);

    rx_cfg               = uart_config::type_id::create("rx_cfg");
    rx_cfg.vif            = vif;                  // same wire - self-loopback
    rx_cfg.role            = UART_ROLE_RX;
    rx_cfg.is_active       = UVM_PASSIVE;           // RX never drives - always passive
    rx_cfg.baud_rate       = tx_cfg.baud_rate;      // must match on both sides
    rx_cfg.num_data_bits   = tx_cfg.num_data_bits;
    rx_cfg.parity          = tx_cfg.parity;
    rx_cfg.num_stop_bits   = tx_cfg.num_stop_bits;
    uvm_config_db#(uart_config)::set(this, "rx_agent*", "cfg", rx_cfg);

    tx_agent = uart_agent::type_id::create("tx_agent", this);
    rx_agent = uart_agent::type_id::create("rx_agent", this);

    chk = uart_loopback_checker::type_id::create("chk", this);
    tx_cb   = uart_tx_record_cb::type_id::create("tx_cb");
    rx_cb   = uart_rx_check_cb::type_id::create("rx_cb");
    tx_cb.chk = chk;
    rx_cb.chk = chk;

    rx_fifo = new("rx_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    uvm_callbacks#(uart_driver,  uart_callback)::add(tx_agent.driver,  tx_cb);
    uvm_callbacks#(uart_monitor, uart_callback)::add(rx_agent.monitor, rx_cb);
    rx_agent.ap.connect(rx_fifo.analysis_export);
  endfunction

endclass : uart_example_env
