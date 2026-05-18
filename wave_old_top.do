# wave_top.do
# System-Level Switch Core Verification Waveform Profile

onerror {resume}
quietly WaveActivateNextPane {} 0

# NOTE: If your instance name inside switch_top_tb is NOT "dut", 
# replace "dut" below with your actual instance name (e.g., "uut" or "u_switchcore").

add wave -noupdate -divider "System Infrastructure"
add wave -noupdate -format Logic -radix hexadecimal /switch_top_tb/dut/clk
add wave -noupdate -format Logic -radix hexadecimal /switch_top_tb/dut/reset

add wave -noupdate -divider "Top-Level Switchcore"
add wave -noupdate -format Literal -radix hexadecimal -expand /switch_top_tb/dut/rx_data
add wave -noupdate -format Literal -radix binary      -expand /switch_top_tb/dut/rx_ctrl
add wave -noupdate -format Literal -radix hexadecimal -expand /switch_top_tb/dut/tx_data
add wave -noupdate -format Literal -radix binary      -expand /switch_top_tb/dut/tx_ctrl

add wave -noupdate -divider "MAC Learning"
add wave -noupdate -format Logic                      /switch_top_tb/dut/u_mac_learner/valid
add wave -noupdate -format Literal -radix unsigned    /switch_top_tb/dut/u_mac_learner/src_port
add wave -noupdate -format Literal -radix hexadecimal /switch_top_tb/dut/u_mac_learner/src_mac
add wave -noupdate -format Literal -radix hexadecimal /switch_top_tb/dut/u_mac_learner/dst_mac
add wave -noupdate -format Literal -radix unsigned    /switch_top_tb/dut/u_mac_learner/dst_port
add wave -noupdate -format Logic                      /switch_top_tb/dut/u_mac_learner/done

add wave -noupdate -divider "Crossbar Fabric"
add wave -noupdate -format Literal -radix binary      /switch_top_tb/dut/u_crossbar_top/i_pkt_valid
add wave -noupdate -format Literal -radix hexadecimal /switch_top_tb/dut/u_crossbar_top/i_data
add wave -noupdate -format Literal -radix binary      /switch_top_tb/dut/u_crossbar_top/o_tx_ctrl
add wave -noupdate -format Literal -radix binary      /switch_top_tb/dut/u_crossbar_top/buffer_wr_en


TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 260
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update

# Auto-zoom to see the whole simulation length
WaveRestoreZoom {0 ps} {65000000 ps}