RTL_SRCS := \
	rtl/i3c_bus_engine.v \
	rtl/i3c_ctrl_ccc.v \
	rtl/i3c_ctrl_daa.v \
	rtl/i3c_ctrl_direct_ccc.v \
	rtl/i3c_ctrl_entdaa.v \
	rtl/i3c_ctrl_inventory.v \
	rtl/i3c_ctrl_policy.v \
	rtl/i3c_ctrl_scheduler.v \
	rtl/i3c_ctrl_top.v \
	rtl/i3c_ctrl_txn_layer.v \
	rtl/i3c_sdr_controller.v \
	rtl/i3c_target_ccc.v \
	rtl/i3c_target_daa.v \
	rtl/i3c_target_top.v \
	rtl/i3c_target_transport.v

COMMON_TB_SRCS := \
	tb/i3c_target_model.v \
	tb/i3c_direct_ccc_responder.v

SIM_RW_OUT := simv_rw
SIM_NACK_OUT := simv_nack
SIM_TARGET_OUT := simv_target
SIM_DAA_OUT := simv_daa
SIM_CCC_OUT := simv_ccc
SIM_DIRECT_CCC_WRITE_OUT := simv_direct_ccc_write
SIM_DIRECT_CCC_READ_OUT := simv_direct_ccc_read
SIM_SETDASA_OUT := simv_setdasa
SIM_GETPID_OUT := simv_getpid
SIM_GETBCRDCR_OUT := simv_getbcrdcr
SIM_GETSTATUS_OUT := simv_getstatus
SIM_ENTDAA_OUT := simv_entdaa
SIM_ENTDAA_MULTI_OUT := simv_entdaa_multi
SIM_ENTDAA_STRESS_OUT := simv_entdaa_stress
SIM_SCHEDULER_OUT := simv_scheduler
SIM_CTRL_TOP_SERVICE_OUT := simv_ctrl_top_service
SIM_EVENT_POLICY_CCC_OUT := simv_event_policy_ccc
SIM_RESET_STATUS_POLICY_OUT := simv_reset_status_policy

.PHONY: sim sim-rw sim-nack sim-target sim-daa sim-ccc sim-direct-ccc-write sim-direct-ccc-read sim-setdasa sim-getpid sim-getbcrdcr sim-getstatus sim-entdaa sim-entdaa-multi sim-entdaa-stress sim-scheduler sim-ctrl-top-service sim-event-policy-ccc sim-reset-status-policy test clean

sim: test

test: sim-rw sim-nack sim-target sim-daa sim-ccc sim-direct-ccc-write sim-direct-ccc-read sim-setdasa sim-getpid sim-getbcrdcr sim-getstatus sim-entdaa sim-entdaa-multi sim-entdaa-stress sim-scheduler sim-ctrl-top-service sim-event-policy-ccc sim-reset-status-policy

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

sim-ccc:
	iverilog -g2012 -Wall -o $(SIM_CCC_OUT) $(RTL_SRCS) tb/tb_i3c_broadcast_ccc.v
	vvp $(SIM_CCC_OUT)

sim-direct-ccc-write:
	iverilog -g2012 -Wall -o $(SIM_DIRECT_CCC_WRITE_OUT) $(RTL_SRCS) tb/i3c_direct_ccc_responder.v tb/tb_i3c_direct_ccc_write.v
	vvp $(SIM_DIRECT_CCC_WRITE_OUT)

sim-direct-ccc-read:
	iverilog -g2012 -Wall -o $(SIM_DIRECT_CCC_READ_OUT) $(RTL_SRCS) tb/i3c_direct_ccc_responder.v tb/tb_i3c_direct_ccc_read.v
	vvp $(SIM_DIRECT_CCC_READ_OUT)

sim-setdasa:
	iverilog -g2012 -Wall -o $(SIM_SETDASA_OUT) $(RTL_SRCS) tb/tb_i3c_setdasa.v
	vvp $(SIM_SETDASA_OUT)

sim-getpid:
	iverilog -g2012 -Wall -o $(SIM_GETPID_OUT) $(RTL_SRCS) tb/tb_i3c_getpid.v
	vvp $(SIM_GETPID_OUT)

sim-getbcrdcr:
	iverilog -g2012 -Wall -o $(SIM_GETBCRDCR_OUT) $(RTL_SRCS) tb/tb_i3c_getbcrdcr.v
	vvp $(SIM_GETBCRDCR_OUT)

sim-getstatus:
	iverilog -g2012 -Wall -o $(SIM_GETSTATUS_OUT) $(RTL_SRCS) tb/tb_i3c_getstatus.v
	vvp $(SIM_GETSTATUS_OUT)

sim-entdaa:
	iverilog -g2012 -Wall -o $(SIM_ENTDAA_OUT) $(RTL_SRCS) tb/tb_i3c_entdaa.v
	vvp $(SIM_ENTDAA_OUT)

sim-entdaa-multi:
	iverilog -g2012 -Wall -o $(SIM_ENTDAA_MULTI_OUT) $(RTL_SRCS) tb/tb_i3c_entdaa_multi.v
	vvp $(SIM_ENTDAA_MULTI_OUT)

sim-entdaa-stress:
	iverilog -g2012 -Wall -o $(SIM_ENTDAA_STRESS_OUT) $(RTL_SRCS) tb/tb_i3c_entdaa_stress.v
	vvp $(SIM_ENTDAA_STRESS_OUT)

sim-scheduler:
	iverilog -g2012 -Wall -o $(SIM_SCHEDULER_OUT) $(RTL_SRCS) tb/tb_i3c_scheduler.v
	vvp $(SIM_SCHEDULER_OUT)

sim-ctrl-top-service:
	iverilog -g2012 -Wall -o $(SIM_CTRL_TOP_SERVICE_OUT) $(RTL_SRCS) tb/tb_i3c_ctrl_top_service.v
	vvp $(SIM_CTRL_TOP_SERVICE_OUT)

sim-event-policy-ccc:
	iverilog -g2012 -Wall -o $(SIM_EVENT_POLICY_CCC_OUT) $(RTL_SRCS) tb/tb_i3c_event_policy_ccc.v
	vvp $(SIM_EVENT_POLICY_CCC_OUT)

sim-reset-status-policy:
	iverilog -g2012 -Wall -o $(SIM_RESET_STATUS_POLICY_OUT) $(RTL_SRCS) tb/tb_i3c_reset_status_policy.v
	vvp $(SIM_RESET_STATUS_POLICY_OUT)

clean:
	rm -f $(SIM_RW_OUT) $(SIM_NACK_OUT) $(SIM_TARGET_OUT) $(SIM_DAA_OUT) $(SIM_CCC_OUT) $(SIM_DIRECT_CCC_WRITE_OUT) $(SIM_DIRECT_CCC_READ_OUT) $(SIM_SETDASA_OUT) $(SIM_GETPID_OUT) $(SIM_GETBCRDCR_OUT) $(SIM_GETSTATUS_OUT) $(SIM_ENTDAA_OUT) $(SIM_ENTDAA_MULTI_OUT) $(SIM_ENTDAA_STRESS_OUT) $(SIM_SCHEDULER_OUT) $(SIM_CTRL_TOP_SERVICE_OUT) $(SIM_EVENT_POLICY_CCC_OUT) $(SIM_RESET_STATUS_POLICY_OUT) tb_i3c_sdr_controller.vcd tb_i3c_sdr_nack.vcd tb_i3c_target_transport.vcd tb_i3c_broadcast_ccc.vcd tb_i3c_direct_ccc_write.vcd tb_i3c_direct_ccc_read.vcd tb_i3c_setdasa.vcd tb_i3c_getpid.vcd tb_i3c_getbcrdcr.vcd tb_i3c_getstatus.vcd tb_i3c_entdaa.vcd tb_i3c_entdaa_multi.vcd tb_i3c_entdaa_stress.vcd tb_i3c_scheduler.vcd tb_i3c_ctrl_top_service.vcd tb_i3c_event_policy_ccc.vcd tb_i3c_reset_status_policy.vcd
