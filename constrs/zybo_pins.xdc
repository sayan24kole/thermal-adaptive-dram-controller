## 125 MHz System Clock
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { sysclk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sysclk }];

## Physical Switch SW0 (1 = Adaptive Refresh, 0 = Static Refresh)
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw0 }];

## The 4 Onboard LEDs (LD0-LD2 status, LD3 Corruption Alarm)
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { leds[0] }];
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { leds[1] }];
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { leds[2] }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { leds[3] }];

## Pmod JA - Pin 1 (Scope / Pico Probe Output)
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { probe_out }];

## Pmod JA - Pin 2 (AD7 Positive Analog)
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { vauxp7 }];

## Pmod JA - Pin 8 (AD7 Negative Analog Ground)
set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { vauxn7 }];