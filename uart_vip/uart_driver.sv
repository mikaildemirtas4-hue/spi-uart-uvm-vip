//=============================================================================
// File        : uart_driver.sv
// Description : Drives the line as a TRANSMITTER: start bit, data bits
//               (LSB first, per the UART standard), optional parity bit,
//               stop bit(s). Only ever built for a uart_config with
//               role == UART_ROLE_TX (the RX side of a UART link never
//               drives the wire).
//=============================================================================
class uart_driver extends uvm_driver #(uart_transaction);

  `uvm_component_utils(uart_driver)
  `uvm_register_cb(uart_driver, uart_callback)

  uart_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("UART_DRV", "uart_config not found in config_db")
    if (cfg.role != UART_ROLE_TX)
      `uvm_fatal("UART_DRV", "uart_driver requires role == UART_ROLE_TX - the RX side of a UART link never drives the wire")
  endfunction

  // Returns the parity bit value for the given data word, per cfg.parity.
  // NOTE: width is a runtime value, so we cannot write data[width-1:0]
  // (part-select ranges must have a constant width in SystemVerilog) -
  // mask off the unused upper bits instead, then XOR-reduce the whole word.
  function bit parity_bit(bit [UART_MAX_DATA_BITS-1:0] data, int width);
    bit [UART_MAX_DATA_BITS-1:0] masked;
    bit p;
    masked = data & ((1 << width) - 1);
    p = ^masked;
    case (cfg.parity)
      UART_PARITY_ODD:   return ~p;
      UART_PARITY_EVEN:  return  p;
      UART_PARITY_MARK:  return 1'b1;
      UART_PARITY_SPACE: return 1'b0;
      default:           return 1'bx; // UART_PARITY_NONE - never actually driven
    endcase
  endfunction

  task run_phase(uvm_phase phase);
    real bit_ns = cfg.bit_period_ns();
    cfg.vif.line <= 1'b1; // idle = mark

    forever begin
      uart_transaction tr;
      seq_item_port.get_next_item(tr);
      tr.num_data_bits = cfg.num_data_bits;
      tr.parity        = cfg.parity;
      tr.num_stop_bits = cfg.num_stop_bits;
      // tr.data is declared UART_MAX_DATA_BITS wide so the VIP can support
      // any format, but only the configured num_data_bits actually go out
      // on the wire. Mask off the unused upper bits here, BEFORE the
      // pre_drive callback fires, so anything a testbench records as "what
      // was sent" (e.g. a loopback checker) already matches what will
      // really appear on the line - otherwise a fully random tr.data can
      // have "phantom" high bits that were never transmitted.
      tr.data          = tr.data & ((1 << cfg.num_data_bits) - 1);
      `uvm_do_callbacks(uart_driver, uart_callback, pre_drive(this, tr))
      drive_frame(tr, bit_ns);
      seq_item_port.item_done();
    end
  endtask

  task drive_frame(uart_transaction tr, real bit_ns);
    // Start bit
    cfg.vif.line <= 1'b0;
    #(bit_ns * 1ns);

    // Data bits, LSB first
    for (int i = 0; i < cfg.num_data_bits; i++) begin
      cfg.vif.line <= tr.data[i];
      #(bit_ns * 1ns);
    end

    // Parity bit (if configured)
    if (cfg.parity != UART_PARITY_NONE) begin
      cfg.vif.line <= parity_bit(tr.data, cfg.num_data_bits);
      #(bit_ns * 1ns);
    end

    // Stop bit(s) - line returns to / stays at mark
    cfg.vif.line <= 1'b1;
    #(cfg.num_stop_bits * bit_ns * 1ns);
  endtask

  // A BREAK condition isn't a framed transfer (no start bit, no stop bit) -
  // it's simply the line held low for longer than one full frame. Call this
  // directly from a test/virtual sequence between normal seq_item transfers,
  // e.g.: driver.send_break();
  task send_break(real duration_in_frames = 1.5);
    real frame_bits = 1 + cfg.num_data_bits + (cfg.parity != UART_PARITY_NONE) + cfg.num_stop_bits;
    cfg.vif.line <= 1'b0;
    #(duration_in_frames * frame_bits * cfg.bit_period_ns() * 1ns);
    cfg.vif.line <= 1'b1;
  endtask

endclass : uart_driver
