# XDC for XC7S25 SRAM Module

set_property BITSTREAM.GENERAL.COMPRESS False [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 16 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR NO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

# Clock signal
set_property PACKAGE_PIN H4 [get_ports SYSCLK50]							
set_property IOSTANDARD LVCMOS33 [get_ports SYSCLK50]
create_clock -add -name clk_50_pin -period 20.00 -waveform {0 5} [get_ports SYSCLK50]

# onboard LED
set_property PACKAGE_PIN A10 [get_ports LED]					
set_property IOSTANDARD LVCMOS33 [get_ports LED]

# AVR Interface, HX3 style
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets F_SCK_IBUF]; # max. 8 MHZ, unkritisch
#create_clock -period 100.000 -name F_SCK_1 -waveform {0.000 50.000} [get_ports {F_SCK}]
set_property -dict { PACKAGE_PIN H11 IOSTANDARD LVCMOS33 } [get_ports F_SCK  ]; # auch Modul, SPI Clk
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports F_MISO ]; # auch Modul
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports F_MOSI ];
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports F_RS   ];
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports F_DS   ];
#set_property -dict { PACKAGE_PIN B14 IOSTANDARD LVCMOS33 } [get_ports F_INT  ]; # MIDI FIFO an AVR
#set_property -dict { PACKAGE_PIN B13 IOSTANDARD LVCMOS33 } [get_ports F_AUX  ]; # nicht bei Modul


#FPC PL8
set_property PACKAGE_PIN P5 [get_ports COIN]					
set_property IOSTANDARD LVCMOS33 [get_ports COIN]
set_property PULLUP true [get_ports COIN]

#set_property PACKAGE_PIN L3 [get_ports LAMP_C]					
#set_property IOSTANDARD LVCMOS33 [get_ports LAMP_C]

#set_property PACKAGE_PIN B1 [get_ports START_1]					
#set_property IOSTANDARD LVCMOS33 [get_ports START_1]
#set_property PULLUP true [get_ports START_1]

#set_property PACKAGE_PIN M3 [get_ports LAMP_1]					
#set_property IOSTANDARD LVCMOS33 [get_ports LAMP_1]
	
#set_property PACKAGE_PIN B2 [get_ports START_2]					
#set_property IOSTANDARD LVCMOS33 [get_ports START_2]
#set_property PULLUP true [get_ports START_2]

#set_property PACKAGE_PIN N1 [get_ports LAMP_2]					
#set_property IOSTANDARD LVCMOS33 [get_ports LAMP_2]

#set_property PACKAGE_PIN A2 [get_ports DOWN]					
#set_property IOSTANDARD LVCMOS33 [get_ports DOWN]
#set_property PULLUP true [get_ports DOWN]

#set_property PACKAGE_PIN M4 [get_ports UP]					
#set_property IOSTANDARD LVCMOS33 [get_ports UP]
#set_property PULLUP true [get_ports UP]

#set_property PACKAGE_PIN P4 [get_ports LEFT]					
#set_property IOSTANDARD LVCMOS33 [get_ports LEFT]
#set_property PULLUP true [get_ports LEFT]

#set_property PACKAGE_PIN N4 [get_ports RIGHT]					
#set_property IOSTANDARD LVCMOS33 [get_ports RIGHT]
#set_property PULLUP true [get_ports RIGHT]

#set_property PACKAGE_PIN P3 [get_ports FIRE]					
#set_property IOSTANDARD LVCMOS33 [get_ports FIRE]
#set_property PULLUP true [get_ports FIRE]

#set_property PACKAGE_PIN P2 [get_ports BOMB]					
#set_property IOSTANDARD LVCMOS33 [get_ports BOMB]
#set_property PULLUP true [get_ports BOMB]

#set_property PACKAGE_PIN xxx [get_ports HYPERSP]					
#set_property IOSTANDARD LVCMOS33 [get_ports HYPERSP]
#set_property PULLUP true [get_ports HYPERSP]


#VGA Connector

set_property PACKAGE_PIN J1 [get_ports {RED[0]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {RED[0]}]

set_property PACKAGE_PIN L1 [get_ports {RED[1]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {RED[1]}]

set_property PACKAGE_PIN L2 [get_ports {RED[2]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {RED[2]}]

set_property PACKAGE_PIN M1 [get_ports {RED[3]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {RED[3]}]

set_property PACKAGE_PIN C1 [get_ports {BLUE[0]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {BLUE[0]}]

set_property PACKAGE_PIN G1 [get_ports {GREEN[0]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {GREEN[0]}]

set_property PACKAGE_PIN H2 [get_ports {GREEN[1]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {GREEN[1]}]

set_property PACKAGE_PIN H1 [get_ports {GREEN[2]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {GREEN[2]}]

set_property PACKAGE_PIN J2 [get_ports {GREEN[3]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {GREEN[3]}]

set_property PACKAGE_PIN D1 [get_ports {BLUE[1]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {BLUE[1]}]

set_property PACKAGE_PIN E2 [get_ports {BLUE[2]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {BLUE[2]}]

set_property PACKAGE_PIN F1 [get_ports {BLUE[3]}]				
set_property IOSTANDARD LVCMOS33 [get_ports {BLUE[3]}]

set_property PACKAGE_PIN M2 [get_ports HSYNC]						
set_property IOSTANDARD LVCMOS33 [get_ports HSYNC]

set_property PACKAGE_PIN F2 [get_ports VSYNC]						
set_property IOSTANDARD LVCMOS33 [get_ports VSYNC]

set_property PACKAGE_PIN G14 [get_ports AUDIO_PWM]						
set_property IOSTANDARD LVCMOS33 [get_ports AUDIO_PWM]

# 10ns SRAM Interface

set_property -dict { PACKAGE_PIN M5  IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[0]} ];
set_property -dict { PACKAGE_PIN L5  IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[1]} ];
set_property -dict { PACKAGE_PIN H13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[2]} ];
set_property -dict { PACKAGE_PIN N10 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[3]} ];
set_property -dict { PACKAGE_PIN N11 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[4]} ];
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[5]} ];
set_property -dict { PACKAGE_PIN F11 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[6]} ];
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[7]} ];
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[8]} ];
set_property -dict { PACKAGE_PIN A13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[9]} ];
set_property -dict { PACKAGE_PIN C14 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[10]} ];
set_property -dict { PACKAGE_PIN D13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[11]} ];
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[12]} ];
set_property -dict { PACKAGE_PIN E12 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[13]} ];
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[14]} ];
set_property -dict { PACKAGE_PIN P12 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[15]} ];
set_property -dict { PACKAGE_PIN P11 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[16]} ];
set_property -dict { PACKAGE_PIN P10 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[17]} ];
set_property -dict { PACKAGE_PIN M10 IOSTANDARD LVCMOS33 } [get_ports { SRAM_ADDR[18]} ];

set_property -dict { PACKAGE_PIN L12 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[0]} ];
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[1]} ];
set_property -dict { PACKAGE_PIN J12 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[2]} ];
set_property -dict { PACKAGE_PIN M11 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[3]} ];
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[4]} ];
set_property -dict { PACKAGE_PIN K12 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[5]} ];
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[6]} ];
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { SRAM_DATA[7]} ];

set_property PACKAGE_PIN L13 [get_ports SRAM_WR]						
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_WR]

set_property PACKAGE_PIN P13 [get_ports SRAM_OE]						
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_OE]

set_property PACKAGE_PIN M12[get_ports SRAM_CE]						
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_CE]

