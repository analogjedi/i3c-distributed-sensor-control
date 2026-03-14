# Vivado batch build for the CMOD S7 dual-target I3C lab demo.

set part_name    "xc7s25csga225-1"
set project_name "i3c_dual_target_lab"

if { $argc >= 1 } {
    set part_name [lindex $argv 0]
}
if { $argc >= 2 } {
    set project_name [lindex $argv 1]
}

set build_dir [file normalize [file join "build" $project_name]]

puts "=== Dual-Target I3C Lab Build ==="
puts "Part:    $part_name"
puts "Project: $project_name"
puts "Output:  $build_dir"
puts "================================="

create_project $project_name $build_dir -part $part_name -force

add_files [glob rtl/*.v]
add_files [glob rtl/fpga_test/*.v]
add_files -fileset constrs_1 constraints/spartan7_i3c_demo.xdc

set_property top spartan7_i3c_dual_target_lab_top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    puts "ERROR: Synthesis failed."
    exit 1
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    puts "ERROR: Implementation failed."
    exit 1
}

open_run impl_1
report_timing_summary -file [file join $build_dir "timing_summary.rpt"]
report_utilization    -file [file join $build_dir "utilization.rpt"]

puts "Build complete. Outputs are under: $build_dir"
