onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {tb signals}
add wave -noupdate /crc_calculator_tb/clk
add wave -noupdate /crc_calculator_tb/reset
add wave -noupdate /crc_calculator_tb/i_rx_ctrl
add wave -noupdate -radix hexadecimal /crc_calculator_tb/i_data
add wave -noupdate -radix hexadecimal /crc_calculator_tb/dst_mac
add wave -noupdate -radix hexadecimal /crc_calculator_tb/src_mac
add wave -noupdate -radix decimal /crc_calculator_tb/o_packet_length
add wave -noupdate /crc_calculator_tb/o_valid
add wave -noupdate /crc_calculator_tb/num_packets
add wave -noupdate /crc_calculator_tb/captured_valid
add wave -noupdate -divider {fcs internals}
add wave -noupdate -radix hexadecimal /crc_calculator_tb/dut/rem_reg
add wave -noupdate /crc_calculator_tb/dut/state
add wave -noupdate -radix decimal /crc_calculator_tb/dut/counter
add wave -noupdate /crc_calculator_tb/dut/crc_valid
add wave -noupdate -divider FIFOs
add wave -noupdate /crc_calculator_tb/dut/i_length_ren
add wave -noupdate /crc_calculator_tb/dut/i_status_ren
add wave -noupdate /crc_calculator_tb/dut/o_length_empty
add wave -noupdate /crc_calculator_tb/dut/o_status_empty
add wave -noupdate /crc_calculator_tb/dut/length_wen
add wave -noupdate /crc_calculator_tb/dut/status_wen
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {397577 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 261
configure wave -valuecolwidth 109
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {0 ps} {1506750 ps}
