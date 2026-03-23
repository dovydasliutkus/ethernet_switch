VLIB = vlib
VLOG = vlog
VSIM = vsim

VLOG_OPT = -timescale=1ns/1ps

WORK = work
ALTERA_LIB = C:/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v

RTL = rtl
TB = tb

SV_FILES = \
	$(RTL)/crossbar/voq_buffer_cixb2.sv \
	$(RTL)/crossbar/fifo.v 

TB_FILES = \
	

TOP = voq_buffer_cixb2

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


clean:
	@if exist work rmdir /s /q work
	@if exist transcript del /q transcript
	@if exist vsim.wlf del /q vsim.wlf
	@if exist vsim_stacktrace.vstf del /q vsim_stacktrace.vstf
	@if exist wlf* del /q wlf*
	@if exist modelsim.ini del /q modelsim.ini
