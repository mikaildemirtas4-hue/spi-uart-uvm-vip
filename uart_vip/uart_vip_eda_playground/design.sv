//=============================================================================
// File        : rtl/uart_core.sv
// Description : Synthesizable, 16x-oversampled 8N1 UART core. This is the
//               "real DUT" that the example testbench verifies with the
//               UART VIP. Not silicon-proven - it's a clean reference
//               design meant to show exactly how VIP pins map onto real
//               RTL ports.
//
//               TX side looks like a simple register/FIFO push port
//               (tx_data/tx_valid/tx_ready) - the kind of interface a real
//               SoC peripheral typically exposes to its bus wrapper.
//               RX side pulses rx_valid for one clk when a byte completes.
//=============================================================================
module uart_core #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 115_200
) (
    input  logic       clk,
    input  logic       rst_n,

    // ---- TX register-style port ----
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_ready,
    output logic       tx_serial,

    // ---- RX register-style port ----
    input  logic       rx_serial,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_frame_err
);

  localparam int OVERSAMPLE = 16;
  localparam int TICK_DIV   = CLK_FREQ_HZ / (BAUD_RATE * OVERSAMPLE);

  //---------------------------------------------------------------------
  // 16x baud tick generator
  //---------------------------------------------------------------------
  logic [$clog2(TICK_DIV)-1:0] tick_cnt;
  logic                        baud_tick16;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tick_cnt    <= '0;
      baud_tick16 <= 1'b0;
    end else if (tick_cnt == TICK_DIV - 1) begin
      tick_cnt    <= '0;
      baud_tick16 <= 1'b1;
    end else begin
      tick_cnt    <= tick_cnt + 1'b1;
      baud_tick16 <= 1'b0;
    end
  end

  //---------------------------------------------------------------------
  // TX FSM
  //---------------------------------------------------------------------
  typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_e;
  tx_state_e  tx_state;
  logic [2:0] tx_bit_idx;
  logic [3:0] tx_sub_cnt;
  logic [7:0] tx_shift;

  assign tx_ready = (tx_state == TX_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state   <= TX_IDLE;
      tx_serial  <= 1'b1;
      tx_bit_idx <= '0;
      tx_sub_cnt <= '0;
      tx_shift   <= '0;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          tx_serial <= 1'b1;
          if (tx_valid) begin
            tx_shift   <= tx_data;
            tx_sub_cnt <= '0;
            tx_state   <= TX_START;
          end
        end

        TX_START: begin
          tx_serial <= 1'b0;
          if (baud_tick16) begin
            if (tx_sub_cnt == OVERSAMPLE - 1) begin
              tx_sub_cnt <= '0;
              tx_bit_idx <= '0;
              tx_state   <= TX_DATA;
            end else tx_sub_cnt <= tx_sub_cnt + 1'b1;
          end
        end

        TX_DATA: begin
          tx_serial <= tx_shift[tx_bit_idx];
          if (baud_tick16) begin
            if (tx_sub_cnt == OVERSAMPLE - 1) begin
              tx_sub_cnt <= '0;
              if (tx_bit_idx == 3'd7) tx_state <= TX_STOP;
              else tx_bit_idx <= tx_bit_idx + 1'b1;
            end else tx_sub_cnt <= tx_sub_cnt + 1'b1;
          end
        end

        TX_STOP: begin
          tx_serial <= 1'b1;
          if (baud_tick16) begin
            if (tx_sub_cnt == OVERSAMPLE - 1) begin
              tx_sub_cnt <= '0;
              tx_state   <= TX_IDLE;
            end else tx_sub_cnt <= tx_sub_cnt + 1'b1;
          end
        end
      endcase
    end
  end

  //---------------------------------------------------------------------
  // RX FSM (2-FF synchronizer + 16x oversample, mid-bit sampling)
  //---------------------------------------------------------------------
  typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_e;
  rx_state_e  rx_state;
  logic [2:0] rx_bit_idx;
  logic [3:0] rx_sub_cnt;
  logic [7:0] rx_shift;
  logic       rx_sync0, rx_sync1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync0 <= 1'b1;
      rx_sync1 <= 1'b1;
    end else begin
      rx_sync0 <= rx_serial;
      rx_sync1 <= rx_sync0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state     <= RX_IDLE;
      rx_bit_idx   <= '0;
      rx_sub_cnt   <= '0;
      rx_shift     <= '0;
      rx_valid     <= 1'b0;
      rx_frame_err <= 1'b0;
      rx_data      <= '0;
    end else begin
      rx_valid <= 1'b0; // default - pulses for exactly one clk per completed byte

      case (rx_state)
        RX_IDLE: begin
          if (!rx_sync1) begin // falling edge -> candidate start bit
            rx_sub_cnt <= '0;
            rx_state   <= RX_START;
          end
        end

        // Spans a FULL bit period (like the physical start bit does): we
        // verify the line is still low at the bit's CENTER (glitch
        // rejection), but only transition to RX_DATA once the entire
        // 16-tick start-bit duration has elapsed. Transitioning early
        // (right at the center check) would make bit0's sampling window
        // begin half a bit period too soon, shifting every subsequently
        // sampled bit by one position and dropping the last data bit.
        RX_START: begin
          if (baud_tick16) begin
            if (rx_sub_cnt == (OVERSAMPLE / 2 - 1) && rx_sync1) begin
              rx_state <= RX_IDLE; // glitch, not a real start bit
            end else if (rx_sub_cnt == OVERSAMPLE - 1) begin
              rx_sub_cnt <= '0;
              rx_bit_idx <= '0;
              rx_state   <= RX_DATA;
            end else begin
              rx_sub_cnt <= rx_sub_cnt + 1'b1;
            end
          end
        end

        RX_DATA: begin
          if (baud_tick16) begin
            if (rx_sub_cnt == (OVERSAMPLE / 2 - 1))
              rx_shift[rx_bit_idx] <= rx_sync1; // sample near bit center
            if (rx_sub_cnt == OVERSAMPLE - 1) begin
              rx_sub_cnt <= '0;
              if (rx_bit_idx == 3'd7) rx_state <= RX_STOP;
              else rx_bit_idx <= rx_bit_idx + 1'b1;
            end else rx_sub_cnt <= rx_sub_cnt + 1'b1;
          end
        end

        RX_STOP: begin
          if (baud_tick16) begin
            if (rx_sub_cnt == (OVERSAMPLE / 2 - 1)) begin
              rx_frame_err <= !rx_sync1;
              rx_data      <= rx_shift;
              rx_valid     <= 1'b1;
            end
            if (rx_sub_cnt == OVERSAMPLE - 1) begin
              rx_sub_cnt <= '0;
              rx_state   <= RX_IDLE;
            end else rx_sub_cnt <= rx_sub_cnt + 1'b1;
          end
        end
      endcase
    end
  end

endmodule : uart_core
