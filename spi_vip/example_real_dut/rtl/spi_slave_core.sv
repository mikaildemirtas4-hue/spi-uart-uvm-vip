//=============================================================================
// File        : rtl/spi_slave_core.sv
// Description : Synthesizable SPI SLAVE peripheral, Mode 0 fixed (CPOL=0,
//               CPHA=0), MSB-first, 8-bit words. This is the "real DUT"
//               verified by the SPI VIP acting as MASTER.
//
//               All SPI pins (sclk, mosi, cs_n) are asynchronous to the
//               system clock and are synchronized in before use - a real
//               design should never use an external pin directly as a
//               clock-enable/edge source without synchronizing it first.
//               `clk` must run several times faster than `sclk` for the
//               synchronizer + edge detector to reliably catch every edge.
//
//               Register-style parallel port (all in the clk domain):
//                 tx_data/tx_load : preload the byte to shift out on MISO
//                                   during the NEXT transaction (double-
//                                   buffered - safe to load mid-transfer).
//                 rx_data/rx_valid: the byte captured on MOSI during the
//                                   transaction that just completed;
//                                   rx_valid pulses for one clk cycle.
//=============================================================================
module spi_slave_core #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // ---- SPI pins (Mode 0: CPOL=0, CPHA=0) ----
    input  logic                  sclk,
    input  logic                  mosi,
    output logic                  miso,
    input  logic                  cs_n,

    // ---- Register-style parallel port ----
    input  logic [DATA_WIDTH-1:0] tx_data,
    input  logic                  tx_load,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  rx_valid
);

  localparam int CNT_W = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

  //---------------------------------------------------------------------
  // Synchronize the asynchronous SPI pins into the clk domain, and derive
  // edge/level signals from the synchronized copies only.
  //---------------------------------------------------------------------
  logic sclk_s0, sclk_s1, sclk_s2;
  logic mosi_s0, mosi_s1;
  logic csn_s0,  csn_s1,  csn_s2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sclk_s0 <= 1'b0; sclk_s1 <= 1'b0; sclk_s2 <= 1'b0;
      mosi_s0 <= 1'b0; mosi_s1 <= 1'b0;
      csn_s0  <= 1'b1; csn_s1  <= 1'b1; csn_s2  <= 1'b1;
    end else begin
      sclk_s0 <= sclk; sclk_s1 <= sclk_s0; sclk_s2 <= sclk_s1;
      mosi_s0 <= mosi; mosi_s1 <= mosi_s0;
      csn_s0  <= cs_n; csn_s1  <= csn_s0;  csn_s2  <= csn_s1;
    end
  end

  wire sclk_rise  = sclk_s1  & ~sclk_s2;
  wire sclk_fall  = ~sclk_s1 & sclk_s2;
  wire cs_active  = ~csn_s1;
  wire cs_fall    = ~csn_s1 & csn_s2;   // CS just asserted  (idle -> active)
  wire cs_rise    =  csn_s1 & ~csn_s2;  // CS just deasserted (active -> idle, transaction complete)

  //---------------------------------------------------------------------
  // Shift register (MOSI capture) + double-buffered TX register (MISO)
  //---------------------------------------------------------------------
  logic [DATA_WIDTH-1:0] shift_reg;
  logic [DATA_WIDTH-1:0] tx_next;    // loaded any time via tx_load
  logic [DATA_WIDTH-1:0] tx_active;  // latched from tx_next at the START of each transaction
  logic [CNT_W-1:0]      bit_cnt;
  logic                  miso_reg;

  assign miso = cs_active ? miso_reg : 1'bz;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg <= '0;
      tx_next   <= '0;
      tx_active <= '0;
      bit_cnt   <= '0;
      miso_reg  <= 1'b0;
      rx_data   <= '0;
      rx_valid  <= 1'b0;
    end else begin
      rx_valid <= 1'b0; // default - pulses for exactly one clk per completed transaction

      if (tx_load) tx_next <= tx_data;

      if (cs_fall) begin
        // Start of a new transaction: latch the preloaded byte and present
        // its MSB immediately (CPHA=0 -> data valid before the first edge).
        tx_active <= tx_next;
        bit_cnt   <= '0;
        miso_reg  <= tx_next[DATA_WIDTH-1];
      end

      if (cs_active) begin
        if (sclk_rise) begin
          shift_reg <= {shift_reg[DATA_WIDTH-2:0], mosi_s1};
        end
        if (sclk_fall) begin
          if (bit_cnt != DATA_WIDTH-1) begin
            miso_reg <= tx_active[DATA_WIDTH-2-bit_cnt];
            bit_cnt  <= bit_cnt + 1'b1;
          end
        end
      end

      if (cs_rise) begin
        rx_data  <= shift_reg;
        rx_valid <= 1'b1;
      end
    end
  end

endmodule : spi_slave_core
