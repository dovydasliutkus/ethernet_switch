VLIB = vlib
VLOG = vlog
VSIM = vsim

VLOG_OPT = -timescale=1ns/1ps

WORK = work

# Altera library path for newest version of Quartus
# ALTERA_LIB = C:/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v

# Altera library path for older version of Quartus
ALTERA_LIB = E:\Tools\intelFPGA_lite\20.1\quartus\eda\sim_lib/altera_mf.v


RTL = rtl
TB = tb
################################ CROSSBAR ################################
CROSSBAR_SV_FILES = \
	$(RTL)/crossbar/buffer/voq_buffer_cixb2.sv \
	$(RTL)/crossbar/buffer/fifo.v \
	$(RTL)/crossbar/FIFOs/pkt_len_fifo.v \
	$(RTL)/crossbar/scheduler/drr_scheduler.sv \
	$(RTL)/crossbar/crossbar_top.sv \

CROSSBAR_TB_FILES = \
	$(TB)/crossbar/buffer/voq_buffer_if.sv \
	$(TB)/crossbar/buffer/voq_buffer_pkg.sv \
	$(TB)/crossbar/buffer/voq_buffer_cixb2_tb.sv \
	$(TB)/crossbar/crossbar_pkg.sv \
	$(TB)/crossbar/crossbar_if.sv\
	$(TB)/crossbar/crossbar_top_tb.sv 

# INCLUDE_FILES = \
# 	$(TB)/schedueler/test_sequences.svh \
# 	$(TB)/schedueler/helper_tasks.svh \



# tmp top, should be crossbar_tb.sv when crossbar is done
CROSSBAR_TOP = crossbar_top_tb

################################ SCHEDULER ################################
SCHEDULER_SV_FILES = \
	$(RTL)/crossbar/scheduler/drr_scheduler.sv \
	$(RTL)/crossbar/FIFOs/pkt_len_fifo.v

SCHEDULER_TB_FILES = \
	$(TB)/scheduler/tb_drr_scheduler.sv \

SCHEDULER_TOP = tb_drr_scheduler

############################# FCS CONTROL ################################
# Test for crc_calculator
CRC_SV_FILES = \
	$(RTL)/fcs_control/FIFOs/packet_length/packet_length_fifo.v \
	$(RTL)/fcs_control/FIFOs/packet_status/packet_status_fifo.v \
	$(RTL)/fcs_control/FIFOs/dst_mac/dst_mac_fifo.v \
	$(RTL)/fcs_control/FIFOs/src_mac/src_mac_fifo.v \
	$(RTL)/fcs_control/crc_calculator.sv

CRC_TB_FILES = \
	$(TB)/fcs_control/crc_calculator_tb.sv

CRC_TOP = crc_calculator_tb

# Test for full fcs_control module
FCS_SV_FILES = \
	$(RTL)/fcs_control/FIFOs/packet_length/packet_length_fifo.v \
	$(RTL)/fcs_control/FIFOs/packet_status/packet_status_fifo.v \
	$(RTL)/fcs_control/FIFOs/data/data_fifo.v \
	$(RTL)/fcs_control/FIFOs/dst_mac/dst_mac_fifo.v \
	$(RTL)/fcs_control/FIFOs/src_mac/src_mac_fifo.v \
	$(RTL)/fcs_control/crc_calculator.sv \
	$(RTL)/fcs_control/output_control.sv \
	$(RTL)/fcs_control/fcs_control.sv \


FCS_TB_FILES = \
	$(TB)/fcs_control/fcs_control_tb.sv

FCS_TOP = fcs_control_tb

############################# TOP ################################

TOP_SV_FILES = \
	$(FCS_SV_FILES) \
	$(SCHEDULER_SV_FILES) \
	$(CROSSBAR_SV_FILES) \
	$(RTL)/mac_learner/mac_learner.sv \
	$(RTL)/switchcore.sv \

TOP_TB_FILES = \
	$(TB)/top_tb.sv

TOP = top_tb

############################# TARGETS ################################

# Test for TOP
all: compile

compile:
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(TOP_SV_FILES) $(TOP_TB_FILES)

sim: compile
	$(VSIM) $(TOP) -do "do wave_top.do; run -all"

batch: compile
	$(VSIM) -c $(TOP) -do "run -all; quit"


# Test for crc_calculator
crc_compile:
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(CRC_SV_FILES) $(CRC_TB_FILES)

crc_sim: crc_compile
	$(VSIM) $(CRC_TOP)

crc_batch: crc_compile
	$(VSIM) -c $(CRC_TOP) -do "run -all; quit"

# Test for full fcs_control module
fcs_compile:
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(FCS_SV_FILES) $(FCS_TB_FILES)

fcs_sim: fcs_compile
	$(VSIM) $(FCS_TOP)

fcs_batch: fcs_compile
	$(VSIM) -c $(FCS_TOP) -do "run -all; quit"


crossbar_compile: clean
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(CROSSBAR_SV_FILES) $(CROSSBAR_TB_FILES) 

crossbar_sim: crossbar_compile
	$(VSIM) -onfinish stop work.$(CROSSBAR_TOP) $(CROSSBAR_TOP)

crossbar_batch: crossbar_compile
	$(VSIM) -c $(CROSSBAR_TOP) -do "run -all; quit" -l $(CROSSBAR_TOP).log

crossbar_wave: crossbar_compile
	$(VSIM) -onfinish stop work.$(CROSSBAR_TOP)  -do "add wave -r *; run -all"

# ---

scheduler_compile:
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(SCHEDULER_SV_FILES) $(SCHEDULER_TB_FILES)

scheduler_sim: scheduler_compile
	$(VSIM) $(SCHEDULER_TOP)

scheduler_batch: scheduler_compile
	$(VSIM) -c $(SCHEDULER_TOP) -do "run -all; quit"

scheduler_wave: scheduler_compile
	$(VSIM) -onfinish stop work.$(SCHEDULER_TOP)  -do "add wave -r *; run -all"

clean:
	@if exist work rmdir /s /q work
	@if exist transcript del /q transcript
	@if exist vsim.wlf del /q vsim.wlf
	@if exist vsim_stacktrace.vstf del /q vsim_stacktrace.vstf
	@if exist wlf* del /q wlf*
	@if exist modelsim.ini del /q modelsim.ini
