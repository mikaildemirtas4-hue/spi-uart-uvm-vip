//=============================================================================
// File        : spi_if.sv
// Description : SPI physical interface. Carries the four SPI wires between
//               whichever side drives them (agent or DUT) and whichever side
//               observes them (monitor / other agent / DUT).
//
//               NUM_CS lets a single bus support multiple slave-select lines
//               (e.g. one master talking to several slave devices). Each
//               spi_config.num_cs must be <= this parameter.
//
// Compile note: this file must be compiled BEFORE spi_vip_pkg.sv, since the
//               package references `virtual spi_if` inside spi_config.
//=============================================================================
interface spi_if #(
    parameter int NUM_CS = 1
) ();

  logic              sclk;   // Serial clock - driven by whichever side plays MASTER
  logic              mosi;   // Master-Out-Slave-In
  logic              miso;   // Master-In-Slave-Out
  logic [NUM_CS-1:0] cs_n;   // Slave-select lines - polarity resolved by spi_config.cs_polarity

  // Convenience task for testbench top / DUT wrappers that want a known
  // idle state before any agent has driven anything.
  task automatic reset_bus();
    sclk = 1'b0;
    mosi = 1'bz;
    miso = 1'bz;
    cs_n = '1;
  endtask

endinterface : spi_if
