TOPLEVEL_LANG = verilog

SIM ?= verilator

VERILOG_SOURCES += $(PWD)/../rtl/usb_hid_host.v
VERILOG_SOURCES += $(PWD)/../rtl/usb_hid_host_rom.v
VERILOG_SOURCES += $(PWD)/usb_hid_host_tb_top.v

CUSTOM_COMPILE_DEPS += $(PWD)/../rom/usb_hid_host_rom.mem

TOPLEVEL = usb_hid_host_tb_top

MODULE = test_usb_hid_host

EXTRA_ARGS += --trace --trace-structs
EXTRA_ARGS += -Wno-fatal

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf __pycache__
	rm -rf results.xml
	rm -rf sim_build
	rm -f *.vcd
	rm -f *.fst
	rm -f dump.fst
