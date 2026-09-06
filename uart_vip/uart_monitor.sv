//=============================================================================
// File        : uart_monitor.sv
// Description : Passively decodes frames off the line. Works regardless of
//               whether the local agent's role is TX or RX - it only reads
//               the wire. Flags parity errors, framing errors, and a
//               heuristic break-condition detection.
//=============================================================================
class uart_monitor extends uvm_monitor;

  `uvm_component_utils(uart_monitor)
  `uvm_register_cb(uart_monitor, uart_callback)

  uart_config cfg;
  uvm_analysis_port #(uart_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("UART_MON", "uart_config not found in config_db")
  endfunction

  // NOTE: width is a runtime value, so we cannot write data[width-1:0]
  // (part-select ranges must have a constant width in SystemVerilog) -
  // mask off the unused upper bits instead, then XOR-reduce the whole word.
  function bit expected_parity(bit [UART_MAX_DATA_BITS-1:0] data, int width);
    bit [UART_MAX_DATA_BITS-1:0] masked;
    bit p;
    masked = data & ((1 << width) - 1);
    p = ^masked;
    case (cfg.parity)
      UART_PARITY_ODD:   return ~p;
      UART_PARITY_EVEN:  return  p;
      UART_PARITY_MARK:  return 1'b1;
      UART_PARITY_SPACE: return 1'b0;
      default:           return 1'bx;
    endcase
  endfunction

  task run_phase(uvm_phase phase);
    real bit_ns = cfg.bit_period_ns();
    forever collect_frame(bit_ns);
  endtask

  task collect_frame(real bit_ns);
    uart_transaction tr;
    bit [UART_MAX_DATA_BITS-1:0] data = '0;
    bit rx_parity;
    bit stop_ok;
    time t_start;

    // Wait for the falling edge that marks a start bit.
    @(negedge cfg.vif.line);
    t_start = $time;

    // Confirm it's a real start bit by sampling at its center.
    #(bit_ns / 2.0 * 1ns);
    if (cfg.vif.line !== 1'b0) return; // glitch, not a real start bit

    for (int i = 0; i < cfg.num_data_bits; i++) begin
      #(bit_ns * 1ns);
      data[i] = cfg.vif.line;
    end

    tr = uart_transaction::type_id::create("mon_tr");
    tr.num_data_bits = cfg.num_data_bits;
    tr.parity        = cfg.parity;
    tr.num_stop_bits = cfg.num_stop_bits;

    if (cfg.parity != UART_PARITY_NONE) begin
      #(bit_ns * 1ns);
      rx_parity = cfg.vif.line;
      tr.parity_error = (rx_parity !== expected_parity(data, cfg.num_data_bits));
    end else begin
      tr.parity_error = 1'b0;
    end

    // Stop bit check - line must be high (mark) for the stop duration.
    #(bit_ns * 1ns);
    stop_ok = (cfg.vif.line === 1'b1);
    tr.framing_error = !stop_ok;

    if (cfg.num_stop_bits > 1.0)
      #((cfg.num_stop_bits - 1.0) * bit_ns * 1ns);

    // Heuristic break detection: an all-zero data word AND a failed stop
    // bit (line held low straight through) looks like a genuine BREAK
    // condition rather than an ordinary framing error on real data.
    tr.break_detected = (tr.framing_error && data == '0 &&
                         (cfg.parity == UART_PARITY_NONE || rx_parity === 1'b0));

    tr.data       = data;
    tr.start_time = t_start;
    tr.end_time   = $time;

    `uvm_do_callbacks(uart_monitor, uart_callback, post_transaction(this, tr))
    ap.write(tr);
    `uvm_info("UART_MON", $sformatf("Captured: %s", tr.convert2string()), UVM_HIGH)
  endtask

endclass : uart_monitor
