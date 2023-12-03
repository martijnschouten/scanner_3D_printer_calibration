"""
.. module:: calibartion_pattern
    :synopsis: This class can be used to make calibartion patterns that can be used 
.. moduleauthor:: Martijn Schouten <github.com/martijnschouten>
"""

import math
from generator import generator

class calibration_pattern:
    #pattern parameters
    width = 8 
    """Length of lines in the test pattern"""

    pitch = 1
    """Milimeter spacing between the lines of the test pattern"""
    
    sigref_only = 2 
    """Space where this only a sig or a ref pattern"""

    length = 70
    """Total length of all the meanders"""
    
    square_lines = 3 
    """Number of lines of the square around the structure"""
    
    spacing = 3 
    """Spacing between two patterns of different nozzles"""
    
    spacing_to_square = 5 
    """Spacing between the patterns and the square"""

    interlocked_period = 4 
    """How many milliemeters it takes before the structure repeats itself"""

    interlocked_pitch = 0.75 
    """The pitch of the lines in the center of the structure in millimeters"""

    gen = generator()
    """An instance of the generator class to generate the gcode"""


    def repetitions(self):
        """Calculates the number of repetions/periods of the repetitie pattern.

        :return: The number of repetions/periods of the repetitie pattern.
        :rtype: int
        """

        return math.floor(self.length/self.pitch/2)

    def repetitions_interlocked(self):
        """Calculates the number of repetions/periods of the interlocked repetitive pattern.

        :return: The number of repetions/periods of the interlocked repetitive pattern.
        :rtype: int
        """
        return math.floor(self.length/self.interlocked_period)

    def effective_length(self):
        """Calculates actual length of a structure, taking into account that the 

        :return: The actual length of a structure
        :rtype: float
        """
        return self.repetitions()*self.pitch*2
    
    def effective_length_interlocked(self):
        """Calculates actual length of a structure, taking into account that the 

        :return: The actual length of a structure
        :rtype: float
        """
        return self.repetitions_interlocked()*self.interlocked_period

    def total_one_dir_width(self):
        """Calculates the total width of all the patterns in one direction

        :return: the total width of all the patterns in one direction
        :rtype: float
        """
        return self.n_tools*(self.width+self.spacing)*2-self.spacing

    def total_width(self):
        """Calculates the total width of the patterns in both directions together

        :return: the total width of the patterns in both directions together
        :rtype: float
        """ 
        return self.total_one_dir_width()+self.effective_length()+self.spacing
    
    def total_width_interlocked(self):
        """Calculates the total width of the patterns in both directions together in case of an interlocked print

        :return: the total width of the patterns in both directions together
        :rtype: float
        """ 
        return self.total_one_dir_width()+self.effective_length_interlocked()+self.spacing

    def total_height(self):
        """Calculates the total height of the patterns in both directions together

        :return: the total height of the patterns in both directions together
        :rtype: float
        """ 
        return max((self.total_one_dir_width(),self.effective_length()))

    def total_height_interlocked(self):
        """Calculates the total height of the patterns in both directions together in case of an interlocked print

        :return: the total height of the patterns in both directions together
        :rtype: float
        """ 
        return max((self.total_one_dir_width(),self.effective_length_interlocked()))

    def square_pattern(self,x_start,y_start,x,y,clockwise,n):
        """Generate the gcode to print a square at a specific location with a specific size and a specified thickness

        :param x_start: The x location of the bottom left corner of the square
        :param y_start: The y location of the bottom left corner of the square
        :param x: The size of the square in the x direction
        :param y: The size of the square in the y direction
        :param clockwise: Boolean indicating if the square should be printed clockwise or counter clockwise
        :param n: The thickness of the lines of the square in number of times the nozzle diameter
        :return: The gcode to generate the square
        :rtype: string
        """
        lines = ""
        d = self.gen.nozzle_diameters[self.gen.current_tool_index]
        lines += self.gen.move_to(x_start,y_start)
        lines += self.gen.reretract()
        for i1 in range(n):
            lines += self.gen.move_to(x_start + i1*d,y_start + i1*d)
            lines += self.gen.square(x-i1*d*2,y-i1*d*2,clockwise)
        lines += self.gen.retract()
        return lines

    def interlocked_reference_pattern(self,x_start,y_start,direction):
        """Generate the gcode to print a single interlocked reference pattern

        :param x_start: The x location of the bottom left corner of the pattern
        :param y_start: The y location of the bottom left corner of the pattern
        :param direction: The direction the pattern should be printed in. Options are: '+y', '-y','+x', '-x'
        :return: The gcode to generate the pattern
        :rtype: string
        """
        repititions = self.repetitions_interlocked()

        lines = ""
        
        if direction == '+y':
            lines += self.gen.move_to(x_start+self.width,y_start+self.interlocked_period/2)
            lines += self.gen.reretract()
            for i1 in range(repititions):
                #make sure retraction artefact can be take of print
                if i1 ==0:
                    lines += self.gen.move(-(self.width-self.sigref_only),0)
                else:
                    lines += self.gen.line(-(self.width-self.sigref_only),0)
                lines += self.gen.u_turn(0,self.interlocked_pitch,True)
                lines += self.gen.line(self.width-self.sigref_only,0)
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,self.interlocked_pitch/2,False)
                lines += self.gen.line(0,self.interlocked_period-2*self.interlocked_pitch)
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,self.interlocked_pitch/2,False)
            lines += self.gen.move(-(self.width-self.sigref_only),0)
        elif direction == '-y':
            lines += self.gen.move_to(x_start+self.width,y_start-self.interlocked_period/2)
            lines += self.gen.reretract()
            for i1 in range(repititions):
                #make sure retraction artefact can be take of print
                if i1 ==0:
                    lines += self.gen.move(-(self.width-self.sigref_only),0)
                else:
                    lines += self.gen.line(-(self.width-self.sigref_only),0)
                lines += self.gen.u_turn(0,-self.interlocked_pitch,False)
                lines += self.gen.line(self.width-self.sigref_only,0)
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,-self.interlocked_pitch/2,True)
                lines += self.gen.line(0,-(self.interlocked_period-2*self.interlocked_pitch))
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,-self.interlocked_pitch/2,True)
            lines += self.gen.move(-(self.width-self.sigref_only),0)
        elif direction == '+x':
            lines += self.gen.move_to(x_start+self.interlocked_period/2,y_start+self.width)
            lines += self.gen.reretract()
            for i1 in range(repititions):
                if i1 == 0:
                    lines += self.gen.move(0,-(self.width-self.sigref_only))
                else:
                    lines += self.gen.line(0,-(self.width-self.sigref_only))
                lines += self.gen.u_turn(self.interlocked_pitch,0,False)
                lines += self.gen.line(0,self.width-self.sigref_only)
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,self.interlocked_pitch/2,True)
                lines += self.gen.line(self.interlocked_period-2*self.interlocked_pitch,0)
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,-self.interlocked_pitch/2,True)
            lines += self.gen.move(0,-(self.width-self.sigref_only))
        elif direction == '-x':
            lines += self.gen.move_to(x_start-self.interlocked_period/2,y_start+self.width)
            lines += self.gen.reretract()
            for i1 in range(repititions):
                if i1 == 0:
                    lines += self.gen.move(0,-(self.width-self.sigref_only))
                else:
                    lines += self.gen.line(0,-(self.width-self.sigref_only))
                lines += self.gen.u_turn(-self.interlocked_pitch,0,True)
                lines += self.gen.line(0,self.width-self.sigref_only)
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,self.interlocked_pitch/2,False)
                lines += self.gen.line(-(self.interlocked_period-2*self.interlocked_pitch),0)
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,-self.interlocked_pitch/2,False)
            lines += self.gen.move(0,-(self.width-self.sigref_only))
        else:
            raise Exception("Unknown direction given to single_pattern function")
        lines += self.gen.retract()
        return lines

    def interlocked_signal_pattern(self,x_start,y_start,direction):
        repititions = self.repetitions_interlocked()

        lines = ""
        lines += self.gen.move_to(x_start,y_start)
        lines += self.gen.reretract()
        if direction == '+y':
            for i1 in range(repititions):
                #make sure retraction artefact can be taken of print
                if i1 ==0:
                    lines += self.gen.move(self.width-self.sigref_only,0)
                else:
                    lines += self.gen.line(self.width-self.sigref_only,0)
                lines += self.gen.u_turn(0,self.interlocked_pitch,False)
                lines += self.gen.line(-(self.width-self.sigref_only),0)
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,self.interlocked_pitch/2,True)
                lines += self.gen.line(0,self.interlocked_period-2*self.interlocked_pitch)
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,self.interlocked_pitch/2,True)
            lines += self.gen.move(self.width-self.sigref_only,0)
        elif direction == '-y':
            for i1 in range(repititions):
                #make sure retraction artefact can be taken of print
                if i1 ==0:
                    lines += self.gen.move(self.width-self.sigref_only,0)
                else:
                    lines += self.gen.line(self.width-self.sigref_only,0)
                lines += self.gen.u_turn(0,-self.interlocked_pitch,True)
                lines += self.gen.line(-(self.width-self.sigref_only),0)
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,-self.interlocked_pitch/2,False)
                lines += self.gen.line(0,-(self.interlocked_period-2*self.interlocked_pitch))
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,-self.interlocked_pitch/2,False)
            lines += self.gen.move(self.width-self.sigref_only,0)
        elif direction == '+x':
            for i1 in range(repititions):
                #make sure retraction artefact can be taken of print
                if i1 ==0:
                    lines += self.gen.move(0,self.width-self.sigref_only)
                else:
                    lines += self.gen.line(0,self.width-self.sigref_only)
                lines += self.gen.u_turn(self.interlocked_pitch,0,True)
                lines += self.gen.line(0,-(self.width-self.sigref_only))
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,-self.interlocked_pitch/2,False)
                lines += self.gen.line(self.interlocked_period-2*self.interlocked_pitch,0)
                lines += self.gen.quarter_turn(self.interlocked_pitch/2,self.interlocked_pitch/2,False)
            lines += self.gen.move(0,self.width-self.sigref_only)
        elif direction == '-x':
            for i1 in range(repititions):
                #make sure retraction artefact can be taken of print
                if i1 ==0:
                    lines += self.gen.move(0,self.width-self.sigref_only)
                else:
                    lines += self.gen.line(0,self.width-self.sigref_only)
                lines += self.gen.u_turn(-self.interlocked_pitch,0,False)
                lines += self.gen.line(0,-(self.width-self.sigref_only))
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,-self.interlocked_pitch/2,True)
                lines += self.gen.line(-(self.interlocked_period-2*self.interlocked_pitch),0)
                lines += self.gen.quarter_turn(-self.interlocked_pitch/2,self.interlocked_pitch/2,True)
            lines += self.gen.move(0,self.width-self.sigref_only)
        else:
            raise Exception("Unknown direction given to single_pattern function")
        lines += self.gen.retract()
        return lines

    def single_pattern(self,x_start,y_start,direction):
        """Generate the gcode to print a single simple reference pattern

        :param x_start: The x location of the bottom left corner of the pattern
        :param y_start: The y location of the bottom left corner of the pattern
        :param direction: The direction the pattern should be printed in. Options are: '+y', '-y','+x', '-x'
        :return: The gcode to generate the pattern
        :rtype: string
        """
        repetitions = self.repetitions()
        lines = ""
        lines += self.gen.move_to(x_start,y_start)
        lines += self.gen.reretract()
        if direction == '+y':
            for i1 in range(repetitions):
                #make sure retraction artefact can be take of print
                if i1 ==0:
                    lines += self.gen.move(self.width-2*self.pitch,0)
                else:
                    lines += self.gen.line(self.width-2*self.pitch,0)
                lines += self.gen.u_turn(0,self.pitch,False)
                lines += self.gen.line(-(self.width-2*self.pitch),0)
                lines += self.gen.u_turn(0,self.pitch,True)
            lines += self.gen.move(self.width,0)
        elif direction == '-y':
            for i1 in range(repetitions):
                if i1 ==0:
                    lines += self.gen.move(self.width-2*self.pitch,0)
                else:
                    lines += self.gen.line(self.width-2*self.pitch,0)
                lines += self.gen.u_turn(0,-self.pitch,True)
                lines += self.gen.line(-(self.width-2*self.pitch),0)
                lines += self.gen.u_turn(0,-self.pitch,False)
            lines += self.gen.move(self.width,0)
        elif direction == '+x':
            lines += self.gen.line(0,self.pitch)
            for i1 in range(repetitions):
                if i1 == 0:
                    lines += self.gen.move(0,self.width-2*self.pitch)
                else:
                    lines += self.gen.line(0,self.width-2*self.pitch)
                lines += self.gen.u_turn(self.pitch,0,True)
                lines += self.gen.line(0,-(self.width-2*self.pitch))
                lines += self.gen.u_turn(self.pitch,0,False)
            lines += self.gen.move(0,self.width)
        elif direction == '-x':
            lines += self.gen.line(0,self.pitch)
            for i1 in range(repetitions):
                if i1 == 0:
                    lines += self.gen.move(0,self.width-2*self.pitch)
                else:
                    lines += self.gen.line(0,self.width-2*self.pitch)
                lines += self.gen.u_turn(-self.pitch,0,False)
                lines += self.gen.line(0,-(self.width-2*self.pitch))
                lines += self.gen.u_turn(-self.pitch,0,True)
            lines += self.move(0,self.width)
        else:
            raise Exception("Unknown direction given to single_pattern function")
        lines += self.gen.retract()
        return lines

    def differential_interlocked_reference_pattern(self,x_start,y_start,direction):
        """Generate the gcode to print one side (the reference side) of two interlocked patterns, one going up and one going down

        :param x_start: The x location of the bottom left corner of the pattern
        :param y_start: The y location of the bottom left corner of the pattern
        :param direction: The direction the pattern should be printed in. Options are: '+y','+x'
        :return: The gcode to generate the pattern
        :rtype: string
        """
        lines = ""
        if direction == 'y':
            lines += self.interlocked_reference_pattern(x_start,y_start,'+y')
            lines += self.gen.move(self.width,0)
            lines += self.gen.move(0,-self.length)
            lines += self.interlocked_reference_pattern(x_start+self.spacing+self.width,y_start,'+y')
            lines += self.gen.move(self.width,0)
            lines += self.gen.move(0,-self.length)
            #lines += self.interlocked_reference_pattern(x_start+self.spacing+self.width,y_start+self.effective_length(),'-y')
        elif direction == 'x':
            lines += self.interlocked_reference_pattern(x_start,y_start,'+x')
            lines += self.gen.move(0,self.width)
            lines += self.gen.move(-self.length,0)
            lines += self.interlocked_reference_pattern(x_start,y_start+self.spacing+self.width,'+x')
            lines += self.gen.move(0,self.width)
            lines += self.gen.move(-self.length,0)
            #lines += self.interlocked_reference_pattern(x_start+self.effective_length(),y_start+self.spacing+self.width,'-x')
        else:
            raise Exception("Unknown direction given to differential_pattern function")
        return lines

    def differential_interlocked_signal_pattern(self,x_start,y_start,direction):
        """Generate the gcode to print one side (the signal side) of two interlocked patterns, one going up and one going down

        :param x_start: The x location of the bottom left corner of the pattern
        :param y_start: The y location of the bottom left corner of the pattern
        :param direction: The direction the pattern should be printed in. Options are: '+y','+x'
        :return: The gcode to generate the pattern
        :rtype: string
        """
        lines = ""
        if direction == 'y':
            lines += self.interlocked_signal_pattern(x_start,y_start,'+y')
            lines += self.interlocked_signal_pattern(x_start+self.spacing+self.width,y_start+self.effective_length_interlocked()+self.interlocked_pitch,'-y')
        elif direction == 'x':
            lines += self.interlocked_signal_pattern(x_start,y_start,'+x')
            lines += self.interlocked_signal_pattern(x_start+self.effective_length_interlocked()+self.interlocked_pitch,y_start+self.spacing+self.width ,'-x')
        else:
            raise Exception("Unknown direction given to differential_pattern function")
        return lines


    def meander_print(self,tool,save_file_name):
        """Generate the gcode to print a simple meandering structure, that fir example can be used to better understand conduction in 3D printed conductors.

        :param tool: tool number of the tool that will be used for the print
        :param save_file_name: Name of the file the gcode will be written to
        :return: The gcode to generate the print
        :rtype: string
        """
        tool_index_list = self.gen.find_tools([tool])
        tool_index = tool_index_list[0]
        lines = ""
        lines += self.gen.starting_code(tool_index_list)
        lines += self.gen.tool_change(tool_index)
        lines += self.gen.move_to(self.gen.x_center-self.width/2,self.gen.y_center-self.length/2-10)
        lines += self.gen.extrude(15)
        lines += self.gen.retract()
        lines += self.gen.move_to(self.gen.x_center-self.width/2,self.gen.y_center-self.length/2)
        lines += self.gen.reretract()
        lines += self.single_pattern(self.gen.x_center-self.width/2,self.gen.y_center-self.length/2,'+y')
        lines += self.gen.retract()
        lines += self.gen.stop_code() 

        f = open(save_file_name,"w")
        f.write(lines)
        f.close()

        return lines

    def full_interlocked_print(self,tool_list,reference_tool,save_file_name):
        """Generate the gcode to print a complete interlocked calibration pattern, that can be scanned and analysed to find the xy offsets.

        :param tool: List of tool number of the tools. Each tool will be used for 4 calibration patterns. One in both the positive and negative x and y directions.
        :param save_file_name: Name of the file the gcode will be written to
        :return: The gcode to generate the print
        :rtype: string
        """

        tool_list_indexes = self.gen.find_tools(tool_list)
        lines = ""
        lines += self.gen.starting_code(tool_list_indexes)

        reference_tool_index = self.gen.find_tools([reference_tool])
        reference_tool_index = reference_tool_index[0]

        self.n_tools = len(tool_list)
        square_width = self.total_width_interlocked()+2*self.spacing_to_square
        square_height = self.total_height_interlocked()+2*self.spacing_to_square

        lines += self.gen.tool_change(reference_tool_index)
        self._tool_offset_index = 0
        lines += self.square_pattern(self.gen.x_center-square_width/2,self.gen.y_center-square_height/2,square_width,square_height,True,self.square_lines)
        for i1 in range(self.n_tools):
            lines += ";print vertical interlocked reference pattern %.0f\n" % (i1)
            x_start = self.gen.x_center-self.total_width()/2+2*i1*(self.width+self.spacing)
            y_start = self.gen.y_center-self.effective_length()/2
            lines += self.differential_interlocked_reference_pattern(x_start,y_start,"y")
        
        for i1 in range(self.n_tools):
            lines += ";print horizontal interlocked reference pattern %.0f\n" % (i1)
            x_start = self.gen.x_center+self.total_width()/2-self.length
            y_start = self.gen.y_center-self.total_one_dir_width()/2+2*i1*(self.width+self.spacing)
            lines += self.differential_interlocked_reference_pattern(x_start,y_start,"x")

        for i1 in range(self.n_tools):
            lines += ";print vertical interlocked signal pattern %.0f\n" % (i1)
            lines += self.gen.tool_change(tool_list_indexes[i1])
            self._tool_offset_index = i1
            x_start = self.gen.x_center-self.total_width()/2+2*i1*(self.width+self.spacing)
            y_start = self.gen.y_center-self.effective_length()/2
            lines += self.differential_interlocked_signal_pattern(x_start,y_start,"y")

            lines += ";print horizontal interlocked signal pattern %.0f\n" % (i1)
            x_start = self.gen.x_center+self.total_width()/2-self.length
            y_start = self.gen.y_center-self.total_one_dir_width()/2+2*i1*(self.width+self.spacing)
            lines += self.differential_interlocked_signal_pattern(x_start,y_start,"x")

            
        lines += self.gen.stop_code()
        
        f = open(save_file_name,"w")
        f.write(lines)
        f.close()

        return lines