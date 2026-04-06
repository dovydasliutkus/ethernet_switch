VLIB = vlib
VLOG = vlog
VSIM = vsim

VLOG_OPT = -timescale=1ns/1ps

WORK = work
# ALTERA_LIB = C:/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v
ALTERA_LIB = E:\Tools\intelFPGA_lite\20.1\quartus\eda\sim_lib/altera_mf.v
RTL = rtl
TB = tb

BUFFER_SV_FILES = \
	$(RTL)/crossbar/voq_buffer_cixb2.sv \
	$(RTL)/crossbar/fifo.v 

BUFFER_TB_FILES = \
	

BUFFER_TOP = voq_buffer_cixb2_tb

FCS_SV_FILES = \
	$(RTL)/fcs_control/FIFOs/packet_length/packet_length_fifo.v \
	$(RTL)/fcs_control/FIFOs/packet_status/packet_status_fifo.v \
	$(RTL)/fcs_control/crc_calculator.sv

FCS_TB_FILES = \
	$(TB)/crc_calculator_tb.sv

FCS_TOP = crc_calculator_tb

all: compile

compile:
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(SV_FILES)

sim: compile
	$(VSIM) $(TOP)

wave: compile
	$(VSIM) -do "add wave -r *; run -all" $(TOP)

batch: compile
	$(VSIM) -c $(TOP) -do "run -all; quit"


fcs_compile:
	$(VLIB) $(WORK)
	$(VLOG) $(VLOG_OPT) $(ALTERA_LIB)
	$(VLOG) $(VLOG_OPT) $(FCS_SV_FILES) $(FCS_TB_FILES)

fcs_sim: fcs_compile
	$(VSIM) $(FCS_TOP)

fcs_batch: fcs_compile
	$(VSIM) -c $(FCS_TOP) -do "run -all; quit"

clean:
	@if exist work rmdir /s /q work
	@if exist transcript del /q transcript
	@if exist vsim.wlf del /q vsim.wlf
	@if exist vsim_stacktrace.vstf del /q vsim_stacktrace.vstf
	@if exist wlf* del /q wlf*
	@if exist modelsim.ini del /q modelsim.ini
