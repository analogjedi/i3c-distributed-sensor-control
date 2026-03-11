# CMOD S7 JTAG Programming Script
# Usage: vivado -mode batch -source scripts/program_cmod_s7.tcl

set bitstream "build/i3c_demo/i3c_demo.runs/impl_1/spartan7_i3c_controller_demo_top.bit"

if {![file exists $bitstream]} {
    puts "ERROR: Bitstream not found: $bitstream"
    exit 1
}

puts "Opening hardware manager..."
open_hw_manager

puts "Connecting to hardware server..."
connect_hw_server

puts "Opening hardware target..."
open_hw_target

puts "Programming device with: $bitstream"
set_property PROGRAM.FILE $bitstream [current_hw_device]
program_hw_devices [current_hw_device]

puts "Closing connection..."
close_hw_target
disconnect_hw_server
close_hw_manager

puts "============================================"
puts "Programming complete!"
puts "============================================"
