## Spartan-7 I3C Demo Constraints Template
## Update PACKAGE_PIN values to match your exact board.

## Example port names expected by rtl/spartan7_i3c_top.v:
##   clk_100mhz, btn_rst_n, led_done, led_error, i3c_scl, i3c_sda

## Clock (example only - replace with your board pin)
# set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
# set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
# create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

## Reset button (example only)
# set_property PACKAGE_PIN C12 [get_ports btn_rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports btn_rst_n]
# set_property PULLUP true [get_ports btn_rst_n]

## LEDs (example only)
# set_property PACKAGE_PIN H5 [get_ports led_done]
# set_property PACKAGE_PIN J5 [get_ports led_error]
# set_property IOSTANDARD LVCMOS33 [get_ports {led_done led_error}]

## I3C pins (example only)
# set_property PACKAGE_PIN K17 [get_ports i3c_scl]
# set_property PACKAGE_PIN K18 [get_ports i3c_sda]

set_property IOSTANDARD LVCMOS33 [get_ports {i3c_scl i3c_sda}]
set_property SLEW FAST [get_ports {i3c_scl i3c_sda}]
set_property DRIVE 8 [get_ports {i3c_scl i3c_sda}]

## Keep weak pull-ups available for lab bring-up. For production, prefer board-level pull-ups.
set_property PULLUP true [get_ports {i3c_scl i3c_sda}]

