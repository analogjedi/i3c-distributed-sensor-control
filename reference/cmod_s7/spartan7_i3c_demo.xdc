## Digilent CMOD S7 (XC7S25-1CSGA225) — I3C Controller Demo
## Pin assignments from Cmod-S7-25-Master.xdc (Digilent)

## 12 MHz System Clock (M9, MRCC-capable)
set_property -dict { PACKAGE_PIN M9  IOSTANDARD LVCMOS33 } [get_ports clk_12mhz]
create_clock -period 83.333 -name sys_clk [get_ports clk_12mhz]

## Active-high reset button (BTN0)
set_property -dict { PACKAGE_PIN D2  IOSTANDARD LVCMOS33 } [get_ports btn_reset]

## Discrete LEDs (active-high) — sample_valid[3:0]
set_property -dict { PACKAGE_PIN E2  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[0]}]
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[1]}]
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[2]}]
set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[3]}]

## RGB LED — sample_valid[4] (blue), boot_done (green), error (red)
set_property -dict { PACKAGE_PIN F1  IOSTANDARD LVCMOS33 } [get_ports led_sv4]
set_property -dict { PACKAGE_PIN D3  IOSTANDARD LVCMOS33 } [get_ports led_boot_done]
set_property -dict { PACKAGE_PIN F2  IOSTANDARD LVCMOS33 } [get_ports led_error]

## I3C Bus — Pmod Header JA pins 1 (SCL) and 2 (SDA)
## External pull-ups to 3.3V recommended (1k–4.7k).
## Internal pull-ups enabled as lab-bring-up fallback.
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports i3c_scl]
set_property -dict { PACKAGE_PIN H2  IOSTANDARD LVCMOS33 } [get_ports i3c_sda]
set_property SLEW FAST  [get_ports {i3c_scl i3c_sda}]
set_property DRIVE 8    [get_ports {i3c_scl i3c_sda}]
set_property PULLUP true [get_ports {i3c_scl i3c_sda}]

## Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
