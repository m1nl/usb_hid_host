# usb

set_property IOSTANDARD LVCMOS33 [get_ports usb_dm_0]
set_property IOSTANDARD LVCMOS33 [get_ports usb_dp_0]
set_property IOSTANDARD LVCMOS33 [get_ports usb_dm_1]
set_property IOSTANDARD LVCMOS33 [get_ports usb_dp_1]
set_property PACKAGE_PIN J18 [get_ports usb_dm_0]
set_property PACKAGE_PIN G20 [get_ports usb_dp_0]
set_property PACKAGE_PIN H20 [get_ports usb_dm_1]
set_property PACKAGE_PIN G19 [get_ports usb_dp_1]
set_property SLEW SLOW [get_ports usb_dm_0]
set_property SLEW SLOW [get_ports usb_dp_0]
set_property SLEW SLOW [get_ports usb_dm_1]
set_property SLEW SLOW [get_ports usb_dp_1]
set_property DRIVE 8 [get_ports usb_dm_0]
set_property DRIVE 8 [get_ports usb_dp_0]
set_property DRIVE 8 [get_ports usb_dm_1]
set_property DRIVE 8 [get_ports usb_dp_1]

# skip when using external resistor for pull-down

set_property PULLTYPE PULLDOWN [get_ports usb_dm_0]
set_property PULLTYPE PULLDOWN [get_ports usb_dp_0]
set_property PULLTYPE PULLDOWN [get_ports usb_dm_1]
set_property PULLTYPE PULLDOWN [get_ports usb_dp_1]

# input / output delay

set_false_path -to [get_ports usb_dm_0]
set_false_path -to [get_ports usb_dm_1]

set_input_delay -reference_pin [get_ports usb_dm_0] -max 0.150 [get_ports usb_dp_0]
set_input_delay -reference_pin [get_ports usb_dm_0] -min -0.150 [get_ports usb_dp_0]
set_input_delay -reference_pin [get_ports usb_dm_1] -max 0.150 [get_ports usb_dp_1]
set_input_delay -reference_pin [get_ports usb_dm_1] -min -0.150 [get_ports usb_dp_1]

set_output_delay -reference_pin [get_ports usb_dm_0] -max 0.150 [get_ports usb_dp_0]
set_output_delay -reference_pin [get_ports usb_dm_0] -min -0.150 [get_ports usb_dp_0]
set_output_delay -reference_pin [get_ports usb_dm_1] -max 0.150 [get_ports usb_dp_1]
set_output_delay -reference_pin [get_ports usb_dm_1] -min -0.150 [get_ports usb_dp_1]
