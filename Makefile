RTL_SRCS := \
	rtl/i3c_bus_engine.v \
	rtl/i3c_ctrl_daa.v \
	rtl/i3c_ctrl_txn_layer.v \
	rtl/i3c_sdr_controller.v \
	rtl/i3c_target_daa.v \
	rtl/i3c_target_top.v \
	rtl/i3c_target_transport.v

COMMON_TB_SRCS := \
	tb/i3c_target_model.v

SIM_RW_OUT := simv_rw
SIM_NACK_OUT := simv_nack
SIM_TARGET_OUT := simv_target
SIM_DAA_OUT := simv_daa

.PHONY: sim sim-rw sim-nack sim-target sim-daa test clean

sim: test

test: sim-rw sim-nack sim-target sim-daa

sim-rw:
	iverilog -g2012 -Wall -o $(SIM_RW_OUT) $(RTL_SRCS) $(COMMON_TB_SRCS) tb/tb_i3c_sdr_controller.v
	vvp $(SIM_RW_OUT)

sim-nack:
	iverilog -g2012 -Wall -o $(SIM_NACK_OUT) $(RTL_SRCS) $(COMMON_TB_SRCS) tb/tb_i3c_sdr_nack.v
	vvp $(SIM_NACK_OUT)

sim-target:
	iverilog -g2012 -Wall -o $(SIM_TARGET_OUT) $(RTL_SRCS) tb/tb_i3c_target_transport.v
	vvp $(SIM_TARGET_OUT)

sim-daa:
	iverilog -g2012 -Wall -o $(SIM_DAA_OUT) $(RTL_SRCS) tb/tb_i3c_daa_state.v
	vvp $(SIM_DAA_OUT)

clean:
	rm -f $(SIM_RW_OUT) $(SIM_NACK_OUT) $(SIM_TARGET_OUT) $(SIM_DAA_OUT) tb_i3c_sdr_controller.vcd tb_i3c_sdr_nack.vcd tb_i3c_target_transport.vcd
