//=============================================================================
// File        : tb/uart_dut_env.sv
// Description : Real-DUT environment.
//
//               - tx_agent (ACTIVE, role=TX)  drives line_into_dut -> tested
//                 against dut.rx_serial, i.e. this exercises the DUT's
//                 RECEIVER.
//               - rx_agent (PASSIVE, role=RX) observes line_from_dut, which
//                 dut.tx_serial drives, i.e. this exercises the DUT's
//                 TRANSMITTER.
//               - reg_bfm talks to the DUT's parallel tx_data/rx_data port
//                 directly through uart_reg_if.
//
//               This is the template to copy for YOUR DUT: keep the VIP
//               agents as-is, just repoint the virtual interfaces at your
//               DUT's actual serial pins and adapt/replace uart_reg_bfm for
//               whatever register or FIFO port your peripheral exposes.
//=============================================================================
class uart_dut_env extends uvm_env;

  `uvm_component_utils(uart_dut_env)

  uart_agent  tx_agent;   // -> dut.rx_serial (tests the DUT's receiver)
  uart_agent  rx_agent;   // <- dut.tx_serial (tests the DUT's transmitter)

  uart_config tx_cfg;
  uart_config rx_cfg;

  uart_reg_bfm reg_bfm;

  uvm_tlm_analysis_fifo #(uart_transaction) rx_fifo; // captures dut.tx_serial decode results

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual uart_if     vif_into_dut;
    virtual uart_if     vif_from_dut;
    virtual uart_reg_if vif_reg;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif_into_dut", vif_into_dut))
      `uvm_fatal("UART_DUT_ENV", "virtual uart_if 'vif_into_dut' not found in config_db")
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif_from_dut", vif_from_dut))
      `uvm_fatal("UART_DUT_ENV", "virtual uart_if 'vif_from_dut' not found in config_db")
    if (!uvm_config_db#(virtual uart_reg_if)::get(this, "", "vif_reg", vif_reg))
      `uvm_fatal("UART_DUT_ENV", "virtual uart_reg_if 'vif_reg' not found in config_db")

    tx_cfg               = uart_config::type_id::create("tx_cfg");
    tx_cfg.vif           = vif_into_dut;
    tx_cfg.role          = UART_ROLE_TX;
    tx_cfg.is_active     = UVM_ACTIVE;
    tx_cfg.baud_rate     = 115_200;   // MUST match uart_core's BAUD_RATE parameter
    tx_cfg.num_data_bits = 8;
    tx_cfg.parity        = UART_PARITY_NONE; // uart_core is a fixed 8N1 reference design
    tx_cfg.num_stop_bits = 1.0;
    uvm_config_db#(uart_config)::set(this, "tx_agent*", "cfg", tx_cfg);

    rx_cfg               = uart_config::type_id::create("rx_cfg");
    rx_cfg.vif           = vif_from_dut;
    rx_cfg.role          = UART_ROLE_RX;
    rx_cfg.is_active     = UVM_PASSIVE;
    rx_cfg.baud_rate     = tx_cfg.baud_rate;
    rx_cfg.num_data_bits = tx_cfg.num_data_bits;
    rx_cfg.parity        = tx_cfg.parity;
    rx_cfg.num_stop_bits = tx_cfg.num_stop_bits;
    uvm_config_db#(uart_config)::set(this, "rx_agent*", "cfg", rx_cfg);

    tx_agent = uart_agent::type_id::create("tx_agent", this);
    rx_agent = uart_agent::type_id::create("rx_agent", this);

    reg_bfm     = uart_reg_bfm::type_id::create("reg_bfm");
    reg_bfm.vif = vif_reg;

    rx_fifo = new("rx_fifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    rx_agent.ap.connect(rx_fifo.analysis_export);
  endfunction

endclass : uart_dut_env
