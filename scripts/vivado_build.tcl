if { $argc < 2 } {
    puts "Usage: vivado -mode batch -source scripts/vivado_build.tcl -tclargs <part> <project_name>"
    puts "Example: vivado -mode batch -source scripts/vivado_build.tcl -tclargs xc7s50csga324-1 i3c_demo"
    exit 1
}

set part_name    [lindex $argv 0]
set project_name [lindex $argv 1]
set build_dir    [file normalize [file join "build" $project_name]]

create_project $project_name $build_dir -part $part_name -force

add_files [glob rtl/*.v]
add_files -fileset constrs_1 constraints/spartan7_i3c_demo.xdc

set_property top spartan7_i3c_top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1
report_timing_summary -file [file join $build_dir "timing_summary.rpt"]
report_utilization    -file [file join $build_dir "utilization.rpt"]

puts "Build complete. Outputs are under: $build_dir"

