//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.01 
//Created Time: 2026-03-02 19:18:21
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_clock -name LCD_CLK -period 74.074 -waveform {0 37.037} [get_ports {LCD_CLK}]
create_clock -name SD_CLK -period 4000 -waveform {0 2000} [get_ports {SD_CLK}] -add
