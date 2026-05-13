onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider switch_top_tb
add wave -noupdate /switch_top_tb/dut/u_fcs_control/i_clk
add wave -noupdate /switch_top_tb/vif/rx_data
add wave -noupdate -radix binary /switch_top_tb/vif/rx_ctrl
add wave -noupdate /switch_top_tb/vif/tx_data
add wave -noupdate -radix binary /switch_top_tb/vif/tx_ctrl
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_data_fifo[0]/data_fifo_inst/full}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_data_fifo[1]/data_fifo_inst/full}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[0]/u_len_fifo/full}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[0]/u_len_fifo/usedw}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[1]/u_len_fifo/full}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[1]/u_len_fifo/usedw}
add wave -noupdate -divider voq_buffer
add wave -noupdate -radix binary {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/i_buffer_empty}
add wave -noupdate -radix binary {/switch_top_tb/dut/u_crossbar_top/gen_sched[1]/u_drr_scheduler/i_buffer_empty}
add wave -noupdate -radix binary {/switch_top_tb/dut/u_crossbar_top/gen_sched[2]/u_drr_scheduler/i_buffer_empty}
add wave -noupdate -radix binary {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/i_buffer_empty}
add wave -noupdate -radix unsigned /switch_top_tb/dut/u_crossbar_top/i_pkt_len
add wave -noupdate -radix binary /switch_top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_full
add wave -noupdate -radix unsigned /switch_top_tb/dut/u_crossbar_top/usedw_col
add wave -noupdate -radix unsigned /switch_top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_usedw
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_occupancy
add wave -noupdate -radix unsigned {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/space_left}
add wave -noupdate -radix unsigned {/switch_top_tb/dut/u_crossbar_top/gen_sched[1]/u_drr_scheduler/space_left}
add wave -noupdate -radix unsigned {/switch_top_tb/dut/u_crossbar_top/gen_sched[2]/u_drr_scheduler/space_left}
add wave -noupdate -radix unsigned {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/space_left}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/pkt_start}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/accepting}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/will_accept}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/i_pkt_valid}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[3]/u_drr_scheduler/o_buffer_wr_en}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[1]/u_drr_scheduler/o_buffer_wr_en}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[2]/u_drr_scheduler/o_buffer_wr_en}
add wave -noupdate -divider {sched 0}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/will_accept}
add wave -noupdate {/switch_top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/o_buffer_wr_en}
add wave -noupdate -divider fcs_control
add wave -noupdate /switch_top_tb/dut/u_fcs_control/i_reset
add wave -noupdate /switch_top_tb/dut/u_fcs_control/i_rx_ctrl
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_fcs_control/i_rx_data
add wave -noupdate /switch_top_tb/dut/u_fcs_control/i_dst_port
add wave -noupdate /switch_top_tb/dut/u_fcs_control/i_done
add wave -noupdate /switch_top_tb/dut/u_fcs_control/o_valid
add wave -noupdate /switch_top_tb/dut/u_fcs_control/o_src_port
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_fcs_control/o_dst_mac
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_fcs_control/o_src_mac
add wave -noupdate /switch_top_tb/dut/u_fcs_control/o_packet_valid
add wave -noupdate /switch_top_tb/dut/u_fcs_control/o_dst_port
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_fcs_control/o_data
add wave -noupdate -radix unsigned /switch_top_tb/dut/u_fcs_control/o_packet_length
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_fcs_control/w_src_mac
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_fcs_control/w_dst_mac
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_valid
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_status_empty
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_status_ren
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_length_ren
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_srcmac_ren
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_dstmac_ren
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_datafifo_ren
add wave -noupdate /switch_top_tb/dut/u_fcs_control/w_datafifo_full
add wave -noupdate -divider {crc_calculator[0]}
add wave -noupdate -radix hexadecimal {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/src_mac}
add wave -noupdate -radix hexadecimal {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/dst_mac}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/rem_reg}
add wave -noupdate -radix decimal {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_packet_length}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_valid}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_length_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_status_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_dstmac_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_srcmac_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_status_empty}
add wave -noupdate -divider {crc_calculator[1]}
add wave -noupdate -radix hexadecimal {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/src_mac}
add wave -noupdate -radix hexadecimal {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/dst_mac}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/rem_reg}
add wave -noupdate -radix decimal {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_packet_length}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_valid}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_length_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_status_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_dstmac_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_srcmac_ren}
add wave -noupdate {/switch_top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_status_empty}
add wave -noupdate -divider mac_learner
add wave -noupdate /switch_top_tb/dut/u_mac_learner/clk
add wave -noupdate /switch_top_tb/dut/u_mac_learner/reset
add wave -noupdate /switch_top_tb/dut/u_mac_learner/valid
add wave -noupdate /switch_top_tb/dut/u_mac_learner/src_port
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_mac_learner/src_mac
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_mac_learner/dst_mac
add wave -noupdate /switch_top_tb/dut/u_mac_learner/dst_port
add wave -noupdate /switch_top_tb/dut/u_mac_learner/done
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_mac_learner/src_hash
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_mac_learner/dst_hash
add wave -noupdate /switch_top_tb/dut/u_mac_learner/state
add wave -noupdate -divider crossbar
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_crossbar_top/i_data
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/i_pkt_valid
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/i_dst_port
add wave -noupdate -radix decimal /switch_top_tb/dut/u_crossbar_top/i_pkt_len
add wave -noupdate -radix hexadecimal /switch_top_tb/dut/u_crossbar_top/o_tx_data
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/o_tx_ctrl
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/write_enable
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/read_enable
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/full
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/empty
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/occupancy
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/buffer_wr_en
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/buffer_rd_en
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/usedw_col
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/full_col
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/empty_col
add wave -noupdate /switch_top_tb/dut/u_crossbar_top/dst_col
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {387523734 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 524
configure wave -valuecolwidth 588
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
WaveRestoreZoom {0 ps} {22780004 ps}
