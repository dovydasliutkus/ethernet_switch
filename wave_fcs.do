onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider tb
add wave -noupdate /fcs_control_tb/i_clk
add wave -noupdate /fcs_control_tb/i_reset
add wave -noupdate /fcs_control_tb/i_rx_ctrl
add wave -noupdate -radix hexadecimal -childformat {{{/fcs_control_tb/i_rx_data[31]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[30]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[29]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[28]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[27]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[26]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[25]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[24]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[23]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[22]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[21]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[20]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[19]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[18]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[17]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[16]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[15]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[14]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[13]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[12]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[11]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[10]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[9]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[8]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[7]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[6]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[5]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[4]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[3]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[2]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[1]} -radix hexadecimal} {{/fcs_control_tb/i_rx_data[0]} -radix hexadecimal}} -subitemconfig {{/fcs_control_tb/i_rx_data[31]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[30]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[29]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[28]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[27]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[26]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[25]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[24]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[23]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[22]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[21]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[20]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[19]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[18]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[17]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[16]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[15]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[14]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[13]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[12]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[11]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[10]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[9]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[8]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[7]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[6]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[5]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[4]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[3]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[2]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[1]} {-height 15 -radix hexadecimal} {/fcs_control_tb/i_rx_data[0]} {-height 15 -radix hexadecimal}} /fcs_control_tb/i_rx_data
add wave -noupdate -divider {fcs_control - Crossbar}
add wave -noupdate /fcs_control_tb/dut/o_packet_valid
add wave -noupdate /fcs_control_tb/dut/o_dst_port
add wave -noupdate -radix hexadecimal /fcs_control_tb/dut/o_data
add wave -noupdate -radix decimal /fcs_control_tb/dut/o_packet_length
add wave -noupdate -divider {fcs_control - Mac Learner}
add wave -noupdate /fcs_control_tb/dut/i_dst_port
add wave -noupdate /fcs_control_tb/dut/i_done
add wave -noupdate /fcs_control_tb/dut/o_valid
add wave -noupdate -radix hexadecimal /fcs_control_tb/dut/o_dst_mac
add wave -noupdate -radix hexadecimal /fcs_control_tb/dut/o_src_mac
add wave -noupdate -divider output_control
add wave -noupdate /fcs_control_tb/dut/u_output_ctrl/busy
add wave -noupdate /fcs_control_tb/dut/u_output_ctrl/arb_found
add wave -noupdate /fcs_control_tb/dut/u_output_ctrl/i_valid
add wave -noupdate -divider {crc_calculator[0]}
add wave -noupdate -radix hexadecimal {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/src_mac}
add wave -noupdate -radix hexadecimal {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/dst_mac}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/o_packet_length}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/o_valid}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/i_length_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/i_status_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/i_dstmac_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/i_srcmac_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[0]/u_crc_calculator/o_status_empty}
add wave -noupdate -divider {crc_calculator[1]}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/src_mac}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/dst_mac}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/o_packet_length}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/o_valid}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/i_length_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/i_status_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/i_dstmac_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/i_srcmac_ren}
add wave -noupdate {/fcs_control_tb/dut/gen_crc[1]/u_crc_calculator/o_status_empty}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {705396 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 369
configure wave -valuecolwidth 211
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {1601250 ps}
