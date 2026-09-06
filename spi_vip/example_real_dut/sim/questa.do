#=============================================================================
# File        : sim/questa.do
# Description : Questa/ModelSim compile + run script for the real-DUT SPI
#               example. Run from the sim/ directory:
#
#                 vsim -do questa.do
#                 vsim -c -do questa.do   (batch, no GUI)
#=============================================================================

if {![info exists ::env(UVM_HOME)]} {
    puts "WARNING: \$UVM_HOME not set - defaulting to Questa's bundled UVM-1.2."
    set UVM_HOME "\$QUESTA_HOME/verilog_src/uvm-1.2"
}

quit -sim -force
if {[file exists work]} { vdel -all }
vlib work
vmap work work

set VIP_DIR ../../spi_vip
set DUT_DIR ..

# 1) UVM base library
vlog -sv +incdir+$::env(UVM_HOME)/src $::env(UVM_HOME)/src/uvm_pkg.sv

# 2) SPI VIP
vlog -sv $VIP_DIR/spi_if.sv
vlog -sv +incdir+$VIP_DIR +incdir+$VIP_DIR/seq_lib $VIP_DIR/spi_vip_pkg.sv

# 3) Real DUT RTL
vlog -sv $DUT_DIR/rtl/spi_slave_core.sv

# 4) Project-specific testbench glue
vlog -sv $DUT_DIR/tb/spi_reg_if.sv
vlog -sv +incdir+$DUT_DIR/tb $DUT_DIR/tb/spi_dut_pkg.sv
vlog -sv $DUT_DIR/tb/tb_top.sv

# 5) Run
vsim -c work.tb_top +UVM_TESTNAME=spi_dut_test -voptargs=+acc
run -all
quit -f
