"""
.. module:: generator
    :synopsis: This class can be used to make simple gcode patterns
.. moduleauthor:: Martijn Schouten <github.com/martijnschouten>
"""
import math

class generator:
    """This class can be used to make simple gcode patterns
    """
    
    #printer specific parameters
    #diabase
    tools = [1,2,3,4,5] 
    """List containing the tool numbers of the tools of the 3D printer"""
    
    nozzle_diameters = [0.4,0.4,0.4,0.4,0.4] #mm diameter of the hole in the used nozzle. One for each tool
    """Diameter of the nozzle of the tools in the tools list in millimeter. Should be of the same size as tools."""

    standby_temperatures = [175,175,175,175,175]
    """Standby temperature used for the tools in the tools list in degrees Celsius. Should be of the same size as tools."""

    printing_temperatures = [200,200,200,200,200]
    """Printing temperature used for the tools in the tools list in degrees Celsius. Should be of the same size as tools."""
    
    extrusion_multiplier = [1.1, 1.1, 1.1, 1.1, 1.1]
    """Extrusion multiplier used for the tools in the tools list. Should be of the same size as tools."""

    retraction_distance = [5,5,5,5,5]
    """Retraction distance used for the tools in the tools list. Should be of the same size as tools."""

    retraction_speed = 80
    """Retraction speed in mm/s used by all tools"""

    z_offset = 0.15
    """Additional offset in the z direction given to all z moves in millimeter. Allows compensating for printers improperly calibrated in the z direction"""
    
    insert_pause = True
    """Insert a pause between probing the bed and actually printing, during which a piece of paper can be placed on the bed."""
    
    x_offsets = [0,0,0,0,0]
    """List with additional offsets in the x direction (mm) given to all x moves of the tools in the tools list. Should be of the same size as tools."""

    y_offsets = [0,0,0,0,0]
    """List with additional offsets in the y direction (mm) given to all y moves of the tools in the tools list. Should be of the same size as tools."""

    x_center = 0
    """Location where the center of the printed structure will be (in mm)"""

    y_center = 0
    """Location where the center of the printed structure will be (in mm)"""

    rotation = math.pi/180*15
    """Rotation of the structure in radians"""

    #filament parameters
    bed_temp = 60
    """Temperature in degrees celsius to which the bed will be heated"""

    layer_height = 0.2 #mm
    """Used layer height in millimeter"""

    print_speed = 30 #mm/s
    """Used printing speed in mm/s"""

    enable_retraction = True
    """Wether or not retraction should be enabled"""

    z_hop = 0.5
    """Wether or not a z-hop should be performed during a retraction"""
    
    filament_diameter = 1.75
    """Diameter of the used filament in millimeter"""
    
    #don't touch
    _current_tool_index = -1
    _tool_offset_index = -1
    
    def extrusion_volume_to_length(self,volume):
        """Convert a desired volume to be extruded out of the nozzle, to the length of filament that needs to be extruded

        :param volume: The desired volume to be extruded out of the nozzle
        :return: The length of filament that needs to be extruded
        :rtype: float
        """
        return volume / (self.filament_diameter * self.filament_diameter * 3.14159 * 0.25)

    def extrusion_for_length(self,length):
        """Convert a desired line length, to the extrusion volume needed

        :param volume: The desired line length
        :return: The extrusion volume needed
        :rtype: float
        """

        return self.extrusion_volume_to_length(length * self.nozzle_diameters[self.current_tool_index] * self.layer_height * self.extrusion_multiplier[self.current_tool_index])

    def rotate(self,x_cor,y_cor):
        """Rotate a coordinate around the center of the print

        :param x_cor: The x value of the coordinate to rotate around the center
        :param y_cor: The y value of the coordinate to rotate around the center
        :return: The rotated coordinate
        :rtype: list
        """ 
        x_rel = x_cor-self.x_center
        y_rel = y_cor-self.y_center
        x_new = math.cos(self.rotation)*x_rel-math.sin(self.rotation)*y_rel
        y_new = math.sin(self.rotation)*x_rel+math.cos(self.rotation)*y_rel
        x_new = x_new+self.x_center
        y_new = y_new+self.y_center
        return x_new,y_new

    def rotate_around_origin(self,x_cor,y_cor):
        """Rotate a coordinate around the origin (0,0)

        :param x_cor: The x value of the coordinate to rotate around (0,0)
        :param y_cor: The y value of the coordinate to rotate around (0,0)
        :return: The rotated coordinate
        :rtype: list
        """ 
        x_new = math.cos(self.rotation)*x_cor-math.sin(self.rotation)*y_cor
        y_new = math.sin(self.rotation)*x_cor+math.cos(self.rotation)*y_cor
        return x_new,y_new
        

    def line(self,x,y):
        """Generate the gcode for a line from current position with a specific length in x an y

        :param x: Distance to move in the x direction
        :param y: Distance to move in the y direction
        :return: The gcode to generate the line
        :rtype: string
        """ 
        length = math.sqrt(x**2 + y**2)
        self.curr_x += x
        self.curr_y += y
        x_pos = self.curr_x+self.x_offsets[self._tool_offset_index]
        y_pos = self.curr_y+self.y_offsets[self._tool_offset_index]
        x_rot,y_rot = self.rotate(x_pos,y_pos)
        return "G1 X%.3f Y%.3f E%.4f F%.0f\n" % (x_rot, y_rot, self.extrusion_for_length(length), self.print_speed * 60)
    
    def move_to(self,x,y):
        """Generate the gcode for a move from the current position to a specific coordinate

        :param x: The x value of the coordinate to move towards in millimeter
        :param y: The y value of the coordinate to move towards in millimeter
        :return: The gcode to generate the move
        :rtype: string
        """
        self.curr_x = x
        self.curr_y = y
        x_pos = x+self.x_offsets[self._tool_offset_index]
        y_pos = y+self.y_offsets[self._tool_offset_index]
        x_rot,y_rot = self.rotate(x_pos,y_pos)
        return "G1 X%.3f Y%.3f F%0.0f\n" % (x_rot,y_rot,self.print_speed*60)
         
    
    def extrude(self,amount):
        """Extrude a specifc amount of filament

        :param amount: The amount of filament to extrude
        :return: The gcode to generate the extrusion
        :rtype: string
        """
        return "G1 E%.3f F%0.0f\n" % (amount, self.print_speed*60)
    
    def move(self,x,y):
        """Generate the gcode for a move from current position with a specific length in x an y

        :param x: Distance to move in the x direction in millimeter
        :param y: Distance to move in the y direction in millimeter
        :return: The gcode to generate the move
        :rtype: string
        """ 
        self.curr_x += x
        self.curr_y += y
        x_pos = self.curr_x+self.x_offsets[self._tool_offset_index]
        y_pos = self.curr_y+self.y_offsets[self._tool_offset_index]
        x_rot,y_rot = self.rotate(x_pos,y_pos)
        return "G1 X%.3f Y%.3f\n" % (x_rot,y_rot)


    def quarter_turn(self,x,y,clockwise):
        """Generate the gcode for a quarter turn from the currrent position to a new position at a specified distance in x and y

        :param x: Distance to move in the x direction in millimeter
        :param y: Distance to move in the y direction in millimeter
        :param clockwise: If the turn should be clockwise or counter clockwise
        :return: The gcode to generate the quarter_turn
        :rtype: string
        """         
        distance = math.sqrt(x**2 + y**2)
        angle = math.atan2(y,x)
        center_dist = distance/math.sqrt(2)
        length = 3.14159*distance/4
        self.curr_x += x
        self.curr_y += y
        curr_x_comp = self.curr_x+self.x_offsets[self._tool_offset_index]
        curr_y_comp = self.curr_y+self.y_offsets[self._tool_offset_index]
        curr_x_rot,curr_y_rot = self.rotate(curr_x_comp,curr_y_comp)
        if clockwise:
            x_center2 = math.cos(angle-math.pi/4)*center_dist
            y_center2 = math.sin(angle-math.pi/4)*center_dist
            x_center_rot, y_center_rot = self.rotate_around_origin(x_center2,y_center2)
            return "G2 X%.3f Y%.3f I%.3f J%.3f E%.4f F%.0f\n" % (curr_x_rot, curr_y_rot, x_center_rot, y_center_rot, self.extrusion_for_length(length), self.print_speed * 60)
        else:
            x_center2 = math.cos(angle+math.pi/4)*center_dist
            y_center2 = math.sin(angle+math.pi/4)*center_dist
            x_center_rot, y_center_rot = self.rotate_around_origin(x_center2,y_center2)
            return "G3 X%.3f Y%.3f I%.3f J%.3f E%.4f F%.0f\n" % (curr_x_rot, curr_y_rot, x_center_rot, y_center_rot, self.extrusion_for_length(length), self.print_speed * 60)

    def u_turn(self,x,y,clockwise):
        """Generate the gcode for a u turn from the currrent position to a new position at a specified distance in x and y

        :param x: Distance to move in the x direction in millimeter
        :param y: Distance to move in the y direction in millimeter
        :param clockwise: Boolean indicating if the turn should be clockwise or counter clockwise
        :return: The gcode to generate the u turn
        :rtype: string
        """    
        x_halfway = x/2
        y_halfway = y/2
        self.curr_x += x
        self.curr_y += y
        distance = math.sqrt(x**2 + y**2)
        length = 3.14159*distance/2
        curr_x_comp = self.curr_x+self.x_offsets[self._tool_offset_index]
        curr_y_comp = self.curr_y+self.y_offsets[self._tool_offset_index]
        curr_x_rot, curr_y_rot = self.rotate(curr_x_comp,curr_y_comp)
        x_half_rot, y_half_rot = self.rotate(curr_x_comp-x_halfway, curr_y_comp-y_halfway)
        x_half_rot2 = curr_x_rot - x_half_rot
        y_half_rot2 = curr_y_rot - y_half_rot
        if clockwise:
            return "G2 X%.3f Y%.3f I%.3f J%.3f E%.4f F%.0f\n" % (curr_x_rot, curr_y_rot, x_half_rot2, y_half_rot2, self.extrusion_for_length(length), self.print_speed * 60)
        else:
            return "G3 X%.3f Y%.3f I%.3f J%.3f E%.4f F%.0f\n" % (curr_x_rot, curr_y_rot, x_half_rot2, y_half_rot2, self.extrusion_for_length(length), self.print_speed * 60)

    def square(self,x,y,clockwise):
        """Generate the gcode for square with a specific size and the bottom left corner at the current position

        :param x: The size of the square in the x direction
        :param y: The size of the square in the y direction
        :param clockwise: Boolean indicating if the square should be printed clockwise or counter clockwise
        :return: The gcode to generate the square
        :rtype: string
        """
        lines = ""
        if clockwise:
            lines += self.line(x,0)
            lines += self.line(0,y)
            lines += self.line(-x,0)
            lines += self.line(0,-y)
        else:
            lines += self.line(0,y)
            lines += self.line(x,0)
            lines += self.line(0,-y)
            lines += self.line(-x,0)
        return lines

    def retract(self):
        """Generate the gcode for a retraction in case retraction is enabled

        :return: The gcode to generate the retraction
        :rtype: string
        """
        if self.enable_retraction:
            return "G1 Z%.3f E%.4f F%.0f\n" % (self.layer_height+self.z_hop+self.z_offset, -self.retraction_distance[self.current_tool_index], self.retraction_speed*60)
        else:
            return ""
    
    def reretract(self):
        """Generate the gcode for a reverse retraction in case retraction is enabled

        :return: The gcode to generate the reverse retraction
        :rtype: string
        """
        if self.enable_retraction:
            return "G1 Z%.3f E%.4f F%.0f\n" % (self.layer_height+self.z_offset, self.retraction_distance[self.current_tool_index], self.retraction_speed*60)
        else:
            return ""
    
    def starting_code(self,tool_list_indexes):
        """Generate the gcode to start a print. This includes things as homing, heating up the bed and heating up tools

        :param tool_list_indexes: List of tool indices that should be heated. The indices will be used to select a tool in :attr:`generator.tools` 
        :return: The starting gcode 
        :rtype: string
        """
        lines = ""
        self.current_tool_index = -1
        for index in tool_list_indexes:
            lines += 'G10 P%.0f R%.0f  S%.0f\n' % (self.tools[index],self.standby_temperatures[index],self.printing_temperatures[index])
        lines += 'M140 S%.0f\n' % (self.bed_temp)
        lines += 'M116\n'
        lines += "G54\n"
        lines += "G28\n"
        lines += "G32\n"
        lines += "M83\n"
        if self.insert_pause:
            lines+= "M25\n"
        return lines        

    def stop_code(self):
        """Generate the gcode to stop a print. This includes things as moving up the bed and turning off heaters

        :return: The stopping gcode 
        :rtype: string
        """
        lines = ""
        lines += "G1 Z25\n"
        lines += "M84\n"
        lines += "M0 H1\n"
        return lines

    def tool_change(self,tool_index):
        """Generate the gcode to perform a tool change

        :param tool_list_indexes: Tool indices of the tool that should be selected. The indice will be used to select a tool in :attr:`generator.tools` 
        :return: The gcode for the tool change
        :rtype: string
        """
        lines = ""
        if not self.current_tool_index == tool_index:
            lines += "T%.0f\n" % (self.tools[tool_index])
            self.current_tool_index = tool_index
        return lines

    def find_tools(self,tool_list):
        """Find the tool indexes belonging to a tool number. Usefull to generate the tool_index parameter of :meth:`generator.tool_change`

        :param tool_list: A list of tool numbers.
        :return: A List of tool indices
        :rtype: list
        """
        tool_list_indexes = []
        found_tool = False
        for item in tool_list:
            for i1 in range(len(self.tools)):
                if item == self.tools[i1]:
                    tool_list_indexes.append(i1)
                    found_tool = True
                    break
            if found_tool == False:
                raise Exception("unknown tool in tool list")
        return tool_list_indexes
    