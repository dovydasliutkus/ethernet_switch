onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider top_tb
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_abort}
add wave -noupdate -radix unsigned {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/counter}
add wave -noupdate -radix unsigned {/top_tb/dut/u_fcs_control/gen_data_fifo[0]/data_fifo_inst/scfifo_component/usedw}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_data_fifo[0]/data_fifo_inst/full}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_data_fifo[1]/data_fifo_inst/full}
add wave -noupdate {/top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[0]/u_len_fifo/full}
add wave -noupdate {/top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[0]/u_len_fifo/usedw}
add wave -noupdate {/top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[1]/u_len_fifo/full}
add wave -noupdate {/top_tb/dut/u_crossbar_top/gen_sched[0]/u_drr_scheduler/g_len_fifo[1]/u_len_fifo/usedw}
add wave -noupdate -divider {START FOR REPORT}
add wave -noupdate /top_tb/dut/reset
add wave -noupdate /top_tb/dut/tx_data
add wave -noupdate /top_tb/dut/tx_ctrl
add wave -noupdate /top_tb/dut/clk
add wave -noupdate /top_tb/dut/rx_data
add wave -noupdate -radix binary /top_tb/dut/rx_ctrl
add wave -noupdate -divider output_control
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_valid
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/rr_ptr
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/arb_port
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/arb_found
add wave -noupdate -radix binary /top_tb/dut/u_fcs_control/u_output_ctrl/sel_port
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/busy
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/u_output_ctrl/o_src_port
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/dropping
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/o_valid
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/mac_state
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/o_packet_valid
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/o_packet_length
add wave -noupdate -radix binary /top_tb/dut/u_fcs_control/u_output_ctrl/o_dst_port
add wave -noupdate -divider {FIFO REN signals}
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_done
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/u_output_ctrl/o_status_ren
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/u_output_ctrl/o_length_ren
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/u_output_ctrl/o_srcmac_ren
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/u_output_ctrl/o_dstmac_ren
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/u_output_ctrl/o_datafifo_ren
add wave -noupdate -divider {END FOR REPORT}
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/o_src_mac
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/o_dst_mac
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_clk
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_reset
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_src_mac
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_dst_mac
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_packet_length
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_status_empty
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/i_dst_port
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/p
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/remaining
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/dst_port_r
add wave -noupdate /top_tb/dut/u_fcs_control/u_output_ctrl/length_r
add wave -noupdate -divider fcs_control
add wave -noupdate /top_tb/dut/u_fcs_control/i_clk
add wave -noupdate /top_tb/dut/u_fcs_control/i_reset
add wave -noupdate -radix binary /top_tb/dut/u_fcs_control/i_rx_ctrl
add wave -noupdate -radix hexadecimal /top_tb/dut/u_fcs_control/i_rx_data
add wave -noupdate /top_tb/dut/u_fcs_control/o_valid
add wave -noupdate /top_tb/dut/u_fcs_control/i_done
add wave -noupdate /top_tb/dut/u_fcs_control/i_dst_port
add wave -noupdate -radix binary /top_tb/dut/u_fcs_control/o_src_port
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
add wave -noupdate -radix hexadecimal {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/src_mac}
add wave -noupdate -radix hexadecimal {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/dst_mac}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/rem_reg}
add wave -noupdate -radix decimal {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_packet_length}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_valid}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_length_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_status_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_dstmac_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/i_srcmac_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[0]/u_crc_calculator/o_status_empty}
add wave -noupdate -divider {crc_calculator[1]}
add wave -noupdate -radix hexadecimal {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/src_mac}
add wave -noupdate -radix hexadecimal {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/dst_mac}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/rem_reg}
add wave -noupdate -radix decimal {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_packet_length}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_valid}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_length_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_status_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_dstmac_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/i_srcmac_ren}
add wave -noupdate {/top_tb/dut/u_fcs_control/gen_crc[1]/u_crc_calculator/o_status_empty}
add wave -noupdate -divider mac_learner
add wave -noupdate /top_tb/dut/u_mac_learner/clk
add wave -noupdate /top_tb/dut/u_mac_learner/reset
add wave -noupdate /top_tb/dut/u_mac_learner/valid
add wave -noupdate /top_tb/dut/u_mac_learner/src_port
add wave -noupdate -radix hexadecimal /top_tb/dut/u_mac_learner/src_mac
add wave -noupdate -radix hexadecimal /top_tb/dut/u_mac_learner/dst_mac
add wave -noupdate /top_tb/dut/u_mac_learner/dst_port
add wave -noupdate /top_tb/dut/u_mac_learner/done
add wave -noupdate -radix hexadecimal /top_tb/dut/u_mac_learner/src_hash
add wave -noupdate -radix hexadecimal /top_tb/dut/u_mac_learner/dst_hash
add wave -noupdate /top_tb/dut/u_mac_learner/state
add wave -noupdate -divider crossbar
add wave -noupdate -radix hexadecimal /top_tb/dut/u_crossbar_top/i_data
add wave -noupdate /top_tb/dut/u_crossbar_top/i_pkt_valid
add wave -noupdate /top_tb/dut/u_crossbar_top/i_dst_port
add wave -noupdate -radix decimal /top_tb/dut/u_crossbar_top/i_pkt_len
add wave -noupdate -radix hexadecimal /top_tb/dut/u_crossbar_top/o_tx_data
add wave -noupdate /top_tb/dut/u_crossbar_top/o_tx_ctrl
add wave -noupdate /top_tb/dut/u_crossbar_top/full
add wave -noupdate /top_tb/dut/u_crossbar_top/empty
add wave -noupdate /top_tb/dut/u_crossbar_top/occupancy
add wave -noupdate /top_tb/dut/u_crossbar_top/buffer_wr_en
add wave -noupdate /top_tb/dut/u_crossbar_top/buffer_rd_en
add wave -noupdate -divider voq_buffer
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/i_data
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/i_write_enable
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/i_read_enable
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_tx_data
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_tx_ctrl
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_occupancy
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_full
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_empty
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_wdata
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_wen
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_ren
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_rdata
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_empty
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_full
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/fifo_usedw
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_tx_data_r
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_tx_ctrl_r
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_tx_data_next
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/o_tx_ctrl_next
add wave -noupdate /top_tb/dut/u_crossbar_top/u_voq_buffer_cixb2/read_enable_d
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {46503542 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 431
configure wave -valuecolwidth 197
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
WaveRestoreZoom {0 ps} {131990250 ps}
