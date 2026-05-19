## Generated SDC file "test3.out.sdc"

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {altera_reserved_tck} -period 100.000 -waveform { 0.000 50.000 } [get_ports {altera_reserved_tck}]
create_clock -name {clk_100} -period 10.000 -waveform { 0.000 5.000 } [get_ports {clk_100}]
create_clock -name {clk125} -period 8.000 -waveform { 0.000 4.000 } [get_pins {GEx4|pll|altpll_component|auto_generated|pll1|clk[0]}]

# Define MDIO clocks (2.5 MHz = 400 ns period)
create_clock -name {mdio_clk_0} -period 400.000 [get_keepers {*transceivers:GEx4|phy_setup:setup_phy|mdio:mdio0|mdio_clk*}]
create_clock -name {mdio_clk_1} -period 400.000 [get_keepers {*transceivers:GEx4|phy_setup:setup_phy|mdio:mdio1|mdio_clk*}]
create_clock -name {mdio_clk_2} -period 400.000 [get_keepers {*transceivers:GEx4|phy_setup:setup_phy|mdio:mdio2|mdio_clk*}]
create_clock -name {mdio_clk_3} -period 400.000 [get_keepers {*transceivers:GEx4|phy_setup:setup_phy|mdio:mdio3|mdio_clk*}]

#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {clk125}] -rise_to [get_clocks {clk125}]  0.060 
set_clock_uncertainty -rise_from [get_clocks {clk125}] -fall_to [get_clocks {clk125}]  0.060 
set_clock_uncertainty -fall_from [get_clocks {clk125}] -rise_to [get_clocks {clk125}]  0.060 
set_clock_uncertainty -fall_from [get_clocks {clk125}] -fall_to [get_clocks {clk125}]  0.060 
set_clock_uncertainty -rise_from [get_clocks {altera_reserved_tck}] -rise_to [get_clocks {altera_reserved_tck}]  0.020 
set_clock_uncertainty -rise_from [get_clocks {altera_reserved_tck}] -fall_to [get_clocks {altera_reserved_tck}]  0.020 
set_clock_uncertainty -fall_from [get_clocks {altera_reserved_tck}] -rise_to [get_clocks {altera_reserved_tck}]  0.020 
set_clock_uncertainty -fall_from [get_clocks {altera_reserved_tck}] -fall_to [get_clocks {altera_reserved_tck}]  0.020 
set_clock_uncertainty -rise_from [get_clocks {clk_100}] -rise_to [get_clocks {clk125}]  0.110 
set_clock_uncertainty -rise_from [get_clocks {clk_100}] -fall_to [get_clocks {clk125}]  0.110 
set_clock_uncertainty -rise_from [get_clocks {clk_100}] -rise_to [get_clocks {clk_100}]  0.060 
set_clock_uncertainty -rise_from [get_clocks {clk_100}] -fall_to [get_clocks {clk_100}]  0.060 
set_clock_uncertainty -fall_from [get_clocks {clk_100}] -rise_to [get_clocks {clk125}]  0.110 
set_clock_uncertainty -fall_from [get_clocks {clk_100}] -fall_to [get_clocks {clk125}]  0.110 
set_clock_uncertainty -fall_from [get_clocks {clk_100}] -rise_to [get_clocks {clk_100}]  0.060 
set_clock_uncertainty -fall_from [get_clocks {clk_100}] -fall_to [get_clocks {clk_100}]  0.060 

#**************************************************************
# Set Clock Groups
#**************************************************************

# Separate asynchronous clock domains
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}] -group [get_clocks {mdio_clk_0 mdio_clk_1 mdio_clk_2 mdio_clk_3}]

#**************************************************************
# Set False Path
#**************************************************************

set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]
set_false_path -from [get_keepers {*rdptr_g*}] -to [get_keepers {*ws_dgrp|dffpipe_fd9:dffpipe19|dffe20a*}]
set_false_path -from [get_keepers {*delayed_wrptr_g*}] -to [get_keepers {*rs_dgwp|dffpipe_ed9:dffpipe14|dffe15a*}]

# Ignore timing on asynchronous MDIO management interface to TSE MAC
set_false_path -from [get_registers {*altera_tse_mdio_reg*an_enable*}] -to [get_registers {*gmii_rx_*}]
#**************************************************************
# I/O False Paths (Ignore timing on asynchronous and slow external pins)
#**************************************************************

# JTAG Programming Pins
set_false_path -from [get_ports {altera_reserved_tdi altera_reserved_tms}]
set_false_path -to [get_ports {altera_reserved_tdo}]

# Asynchronous Resets and Slow Fan Control
set_false_path -from [get_ports {reset_n reset_phy_in}]
set_false_path -to [get_ports {rst fan_ctrl}]

# Slow External MDIO/MDC Management Bus Pins
set_false_path -from [get_ports {mdio[*]}]
set_false_path -to [get_ports {mdc[*] mdio[*]}]

# High-Speed Serial Transceiver Pins (ALTGX/SERDES)
# Note: rx[*] and tx[*] are self-synchronous via Clock Data Recovery (CDR).
# Standard I/O delay constraints do not apply to them.
set_false_path -from [get_ports {rx[*]}]
set_false_path -to [get_ports {tx[*]}]
set_false_path -from [get_ports {rx*}]
set_false_path -to [get_ports {tx*}]