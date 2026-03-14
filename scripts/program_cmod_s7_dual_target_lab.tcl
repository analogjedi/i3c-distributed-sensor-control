open_hw_manager
connect_hw_server
open_hw_target

set bitstream "build/i3c_dual_target_lab/i3c_dual_target_lab.runs/impl_1/spartan7_i3c_dual_target_lab_top.bit"
current_hw_device [lindex [get_hw_devices xc7s25_*] 0]
refresh_hw_device [current_hw_device]
set_property PROGRAM.FILE $bitstream [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device [current_hw_device]
