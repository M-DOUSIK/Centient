# Simulation with Icarus Verilog
#   make sim            run every testbench
#   make qsse_v2        run one testbench
#   make clean

IVERILOG ?= iverilog
VVP      ?= vvp
FLAGS    := -g2012 -Wall -I rtl/qstu_v2
BUILD    := build

TESTS := qsse_v1 qsse_v2 qstu_v1 qstu_v2 imu_filter

qsse_v1_SRC    := rtl/qsse_v1/top_nopipe.v       tb/tb_qsse_v1.v
qsse_v2_SRC    := $(wildcard rtl/qsse_v2/*.v)    tb/tb_qsse_v2.v
qstu_v1_SRC    := $(wildcard rtl/qstu_v1/*.sv)   tb/tb_qstu_v1.sv
qstu_v2_SRC    := $(wildcard rtl/qstu_v2/*.v)    tb/tb_qstu_v2.v
imu_filter_SRC := rtl/imu_filter/iir_filter.v    tb/tb_imu_filter.v

.PHONY: sim clean $(TESTS)

sim: $(TESTS)

$(TESTS): %: $(BUILD)/%.vvp
	cd $(BUILD) && $(VVP) -n $*.vvp

define TEST_RULE
$(BUILD)/$(1).vvp: $$($(1)_SRC) | $(BUILD)
	$$(IVERILOG) $$(FLAGS) -o $$@ $$($(1)_SRC)
endef
$(foreach t,$(TESTS),$(eval $(call TEST_RULE,$(t))))

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD)
