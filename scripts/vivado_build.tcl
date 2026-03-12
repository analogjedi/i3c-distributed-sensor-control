# Vivado batch build for I3C controller demo on CMOD S7
#
# Usage:
#   vivado -mode batch -source scripts/vivado_build.tcl
#   vivado -mode batch -source scripts/vivado_build.tcl -tclargs <part> [project_name]
#
# Defaults: xc7s25csga225-1, i3c_demo

set part_name    "xc7s25csga225-1"
set project_name "i3c_demo"

if { $argc >= 1 } {
    set part_name [lindex $argv 0]
}
if { $argc >= 2 } {
    set project_name [lindex $argv 1]
}

set build_dir [file normalize [file join "build" $project_name]]

puts "=== I3C Controller Demo Build ==="
puts "Part:    $part_name"
puts "Project: $project_name"
puts "Output:  $build_dir"
puts "================================="

create_project $project_name $build_dir -part $part_name -force

# Core protocol RTL + FPGA-test demo wrappers (including board top)
add_files [glob rtl/*.v]
add_files [glob rtl/fpga_test/*.v]
add_files -fileset constrs_1 constraints/spartan7_i3c_demo.xdc

set_property top spartan7_i3c_unified_demo_top [current_fileset]
update_compile_order -fileset sources_1

# Synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    puts "ERROR: Synthesis failed."
    exit 1
}

# Implementation through bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    puts "ERROR: Implementation failed."
    exit 1
}

# Reports
open_run impl_1
report_timing_summary -file [file join $build_dir "timing_summary.rpt"]
report_utilization    -file [file join $build_dir "utilization.rpt"]

puts "Build complete. Outputs are under: $build_dir"
