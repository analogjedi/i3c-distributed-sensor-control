## Digilent CMOD S7 (XC7S25-1CSGA225) — I3C Controller Demo
## Pin assignments from Cmod-S7-25-Master.xdc (Digilent)

## 12 MHz System Clock (M9, MRCC-capable)
set_property -dict { PACKAGE_PIN M9  IOSTANDARD LVCMOS33 } [get_ports clk_12mhz]
create_clock -period 83.333 -name sys_clk [get_ports clk_12mhz]

## Active-high reset button (BTN0)
set_property -dict { PACKAGE_PIN D2  IOSTANDARD LVCMOS33 } [get_ports btn_reset]

## Discrete LEDs (active-high) — top-level-defined meaning
## Dual-target lab: LED0/1 = target outputs, LED2/3 = sample-valid A/B
## Unified five-target reference: sample-valid[3:0]
set_property -dict { PACKAGE_PIN E2  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[0]}]
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[1]}]
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[2]}]
set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports {led_sample_valid[3]}]

## RGB LED — top-level-defined meaning
## Dual-target lab: recovery_active (blue), boot_done (green), error (red)
## Unified five-target reference: sample_valid[4] (blue), boot_done (green), error (red)
set_property -dict { PACKAGE_PIN F1  IOSTANDARD LVCMOS33 } [get_ports led_sv4]
set_property -dict { PACKAGE_PIN D3  IOSTANDARD LVCMOS33 } [get_ports led_boot_done]
set_property -dict { PACKAGE_PIN F2  IOSTANDARD LVCMOS33 } [get_ports led_error]

## I3C Bus — internal only in unified demo (no external pins needed)

## UART (FT2232H USB-UART bridge)
set_property -dict { PACKAGE_PIN L12 IOSTANDARD LVCMOS33 } [get_ports uart_txd]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports uart_rxd]

## Configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
