# wave_scheduler.do
# Optimized for DRR Scheduler Block-Level Verification

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider "System Signals"
add wave -noupdate -format Logic -radix hexadecimal /tb_drr_scheduler/clk
add wave -noupdate -format Logic -radix hexadecimal /tb_drr_scheduler/reset

add wave -noupdate -divider "Ingress Interface (Testbench Driven)"
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/pkt_valid
add wave -noupdate -format Literal -radix hexadecimal /tb_drr_scheduler/dst_port
add wave -noupdate -format Literal -radix unsigned    /tb_drr_scheduler/i_pkt_len

add wave -noupdate -divider "Ingress Internal Control (DUT Internal)"
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/pkt_start
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/accepting
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/len_wr_en

add wave -noupdate -divider "Buffer Tracking"
add wave -noupdate -format Literal -radix unsigned -expand /tb_drr_scheduler/buffer_usedw
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/buffer_usedw[3]
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/buffer_usedw[2]
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/buffer_usedw[1]
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/buffer_usedw[0]
add wave -noupdate -format Literal -radix binary          /tb_drr_scheduler/buffer_full
add wave -noupdate -format Literal -radix binary          /tb_drr_scheduler/buffer_empty
add wave -noupdate -format Literal -radix binary          /tb_drr_scheduler/buffer_wr_en
add wave -noupdate -format Literal -radix binary          /tb_drr_scheduler/buffer_rd_en

add wave -noupdate -divider "DRR Scheduler Engine State"
add wave -noupdate -format Literal -radix ascii       /tb_drr_scheduler/dut/state
add wave -noupdate -format Literal -radix unsigned    /tb_drr_scheduler/dut/rr_ptr
add wave -noupdate -format Literal -radix unsigned    /tb_drr_scheduler/dut/tx_remaining
add wave -noupdate -format Literal -radix binary      -expand /tb_drr_scheduler/dut/len_empty
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/len_empty[3]
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/len_empty[2]
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/len_empty[1]
add wave -noupdate -format Literal -radix binary      /tb_drr_scheduler/dut/len_empty[0]

add wave -noupdate -divider "Deficit Counters"
add wave -noupdate -format Literal -radix unsigned -expand /tb_drr_scheduler/dut/deficit
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/dut/deficit[3]
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/dut/deficit[2]
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/dut/deficit[1]
add wave -noupdate -format Literal -radix unsigned        /tb_drr_scheduler/dut/deficit[0]

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 240
configure wave -valuecolwidth 100
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

run -all