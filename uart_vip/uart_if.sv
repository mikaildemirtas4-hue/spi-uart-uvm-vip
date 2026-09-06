//=============================================================================
// File        : uart_if.sv
// Description : A single asynchronous serial line. UART is point-to-point
//               and unidirectional per wire, so instantiate this interface
//               ONCE PER DIRECTION in your testbench:
//                 - one instance wired to the DUT's RX pin (a TX agent drives it)
//                 - one instance wired to the DUT's TX pin (an RX agent observes it)
//
// Compile note: this file must be compiled BEFORE uart_vip_pkg.sv, since the
//               package references `virtual uart_if` inside uart_config.
//=============================================================================
interface uart_if ();

  logic line;   // idle = 1 (mark), start bit = 0 (space)

  task automatic reset_line();
    line = 1'b1;
  endtask

endinterface : uart_if
