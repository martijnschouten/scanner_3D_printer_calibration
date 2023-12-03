
from calibration_pattern import calibration_pattern

pattern = calibration_pattern()

pattern.gen.x_offsets = [0,0,0,0,0]
pattern.gen.y_offsets = [0,0,0,0,0]
tool_list = [1,2,3,4,5]
lines = pattern.full_interlocked_print(tool_list,2,"interlocked_calibration_pattern_diabase.gcode")

tool_list = [2,2,2,2,2]
pattern.gen.x_offsets = [0,-0.05,0.05,-0.1,0.1]
pattern.gen.y_offsets = [0,-0.05,0.05,-0.1,0.1]
lines = pattern.full_interlocked_print(tool_list,2,"interlocked_calibration_pattern_diabase_one_tool_only_with_offsets.gcode")

pattern.spacing = 0.5
pattern.gen.rotation = 0
pattern.width = 40
pattern.length = 10
lines = pattern.meander_print(1,'meander_print.gcode')

