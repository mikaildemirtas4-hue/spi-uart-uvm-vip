//=============================================================================
// File        : spi_transaction.sv
// Description : One SPI word transfer, full-duplex by nature.
//
//               Field naming is BUS-ABSOLUTE, not role-relative:
//                 mosi_data -> whatever appears on the MOSI wire
//                 miso_data -> whatever appears on the MISO wire
//
//               - Driving a MASTER agent: fill in mosi_data (what you send).
//                 After the transfer, miso_data holds the captured reply.
//               - Driving a SLAVE agent : fill in miso_data (your response).
//                 After the transfer, mosi_data holds what the master sent.
//               - Monitor-generated transactions always report both fields
//                 exactly as seen on the bus.
//=============================================================================
class spi_transaction extends uvm_sequence_item;

  rand bit [SPI_MAX_WIDTH-1:0] mosi_data;   // data on MOSI wire (drive or capture, see above)
  rand bit [SPI_MAX_WIDTH-1:0] miso_data;   // data on MISO wire (drive or capture, see above)
  rand int unsigned            num_bits;   // word width for this transfer, 1..SPI_MAX_WIDTH
  rand int unsigned            cs_index;   // which CS line this transfer targets

  spi_mode_e mode;        // resolved from agent config at drive time (informational on completed items)
  time       start_time;
  time       end_time;

  `uvm_object_utils_begin(spi_transaction)
    `uvm_field_int(mosi_data, UVM_ALL_ON)
    `uvm_field_int(miso_data, UVM_ALL_ON)
    `uvm_field_int(num_bits,  UVM_ALL_ON)
    `uvm_field_int(cs_index,  UVM_ALL_ON)
    `uvm_field_enum(spi_mode_e, mode, UVM_ALL_ON)
  `uvm_object_utils_end

  constraint c_num_bits_range { num_bits inside {[1:SPI_MAX_WIDTH]}; }
  constraint c_default_width  { soft num_bits == 8; }
  constraint c_default_cs     { soft cs_index == 0; }

  function new(string name = "spi_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("mosi=0x%0h miso=0x%0h bits=%0d cs=%0d mode=%s",
                      mosi_data, miso_data, num_bits, cs_index,
                      mode.name());
  endfunction

endclass : spi_transaction
