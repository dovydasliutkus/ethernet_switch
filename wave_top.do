onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider top_tb
add wave -noupdate /top_tb/rx_data
add wave -noupdate /top_tb/rx_ctrl
add wave -noupdate -divider fcs_control
add wave -noupdate /top_tb/dut/u_fcs_control/i_clk
add wave -noupdate /top_tb/dut/u_fcs_control/i_reset
add wave -noupdate /top_tb/dut/u_fcs_control/i_rx_ctrl
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/i_rx_data
add wave -noupdate /top_tb/dut/u_fcs_control/i_dst_port
add wave -noupdate /top_tb/dut/u_fcs_control/i_done
add wave -noupdate /top_tb/dut/u_fcs_control/o_valid
add wave -noupdate /top_tb/dut/u_fcs_control/o_src_port
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/o_dst_mac
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/o_src_mac
add wave -noupdate /top_tb/dut/u_fcs_control/o_packet_valid
add wave -noupdate /top_tb/dut/u_fcs_control/o_dst_port
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/o_data
add wave -noupdate -radix decimal /top_tb/dut/u_fcs_control/o_packet_length
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/w_src_mac
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/w_dst_mac
add wave -noupdate /top_tb/dut/u_fcs_control/w_valid
add wave -noupdate /top_tb/dut/u_fcs_control/w_status_empty
add wave -noupdate /top_tb/dut/u_fcs_control/w_status_ren
add wave -noupdate /top_tb/dut/u_fcs_control/w_length_ren
add wave -noupdate /top_tb/dut/u_fcs_control/w_srcmac_ren
add wave -noupdate /top_tb/dut/u_fcs_control/w_dstmac_ren
add wave -noupdate /top_tb/dut/u_fcs_control/w_datafifo_ren
add wave -noupdate /top_tb/dut/u_fcs_control/w_datafifo_full
add wave -noupdate -divider {crc_calculator[0]}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/state}
add wave -noupdate -radix hexadecimal {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/rem_reg}
add wave -noupdate -divider {crc_calculator[1]}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/state}
add wave -noupdate -radix hexadecimal {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/rem_reg}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_valid}
add wave -noupdate -divider mac_learner
add wave -noupdate /top_tb/dut/u_mac_learner/clk
add wave -noupdate /top_tb/dut/u_mac_learner/reset
add wave -noupdate /top_tb/dut/u_mac_learner/valid
add wave -noupdate /top_tb/dut/u_mac_learner/src_port
add wave -noupdate /top_tb/dut/u_mac_learner/src_mac
add wave -noupdate /top_tb/dut/u_mac_learner/dst_mac
add wave -noupdate /top_tb/dut/u_mac_learner/dst_port
add wave -noupdate /top_tb/dut/u_mac_learner/done
add wave -noupdate /top_tb/dut/u_mac_learner/src_hash
add wave -noupdate /top_tb/dut/u_mac_learner/dst_hash
add wave -noupdate /top_tb/dut/u_mac_learner/valid1_ram
add wave -noupdate /top_tb/dut/u_mac_learner/mac1_ram
add wave -noupdate /top_tb/dut/u_mac_learner/port1_ram
add wave -noupdate /top_tb/dut/u_mac_learner/valid2_ram
add wave -noupdate /top_tb/dut/u_mac_learner/mac2_ram
add wave -noupdate /top_tb/dut/u_mac_learner/port2_ram
add wave -noupdate /top_tb/dut/u_mac_learner/lru_ram
add wave -noupdate /top_tb/dut/u_mac_learner/state
add wave -noupdate /top_tb/dut/u_mac_learner/src_v1
add wave -noupdate /top_tb/dut/u_mac_learner/src_v2
add wave -noupdate /top_tb/dut/u_mac_learner/dst_v1
add wave -noupdate /top_tb/dut/u_mac_learner/dst_v2
add wave -noupdate /top_tb/dut/u_mac_learner/src_m1
add wave -noupdate /top_tb/dut/u_mac_learner/src_m2
add wave -noupdate /top_tb/dut/u_mac_learner/dst_m1
add wave -noupdate /top_tb/dut/u_mac_learner/dst_m2
add wave -noupdate /top_tb/dut/u_mac_learner/src_p1
add wave -noupdate /top_tb/dut/u_mac_learner/src_p2
add wave -noupdate /top_tb/dut/u_mac_learner/dst_p1
add wave -noupdate /top_tb/dut/u_mac_learner/dst_p2
add wave -noupdate /top_tb/dut/u_mac_learner/src_lru
add wave -noupdate /top_tb/dut/u_mac_learner/src_hash_reg
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {325000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 361
configure wave -valuecolwidth 320
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
WaveRestoreZoom {0 ps} {2752809 ps}
