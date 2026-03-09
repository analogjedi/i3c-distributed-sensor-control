RTL_SRCS := \
	rtl/i3c_sdr_controller.v

COMMON_TB_SRCS := \
	tb/i3c_target_model.v

SIM_RW_OUT := simv_rw
SIM_NACK_OUT := simv_nack

.PHONY: sim sim-rw sim-nack test clean

sim: test

test: sim-rw sim-nack

sim-rw:
	iverilog -g2012 -Wall -o $(SIM_RW_OUT) $(RTL_SRCS) $(COMMON_TB_SRCS) tb/tb_i3c_sdr_controller.v
	vvp $(SIM_RW_OUT)

sim-nack:
	iverilog -g2012 -Wall -o $(SIM_NACK_OUT) $(RTL_SRCS) $(COMMON_TB_SRCS) tb/tb_i3c_sdr_nack.v
	vvp $(SIM_NACK_OUT)

clean:
	rm -f $(SIM_RW_OUT) $(SIM_NACK_OUT) tb_i3c_sdr_controller.vcd tb_i3c_sdr_nack.vcd
