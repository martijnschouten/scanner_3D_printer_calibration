.. gcode generator documentation master file, created by
   sphinx-quickstart on Wed Nov 24 16:23:19 2021.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to gcode generator's documentation!
===========================================


The gcode generator consists of two classes. The :class:`generator` class is used to make it easier to generate gcode for basic geometric moves. The :class:`calibration_pattern` class is used to generate the actual calibration patterns. To use the module to generate a gcode file called "example.g" with a calibration pattern for tools 1,2,3,4 and 5 and with tool 2 as reference use :

.. code-block:: python

	from calibration_pattern import calibartion_pattern

	pattern = calibartion_pattern()

	tool_list = [1,2,3,4,5]
	reference_tool = 2
	lines = pattern.full_interlocked_print(tool_list,reference_tool,"example.g")
	
By default the code assumes you are using a Diabase H-series 3D printer. To configure it for another printer or change slicer settings of the gen instance in pattern should be changed. For example to make the code suitable for a dual material printer add the following code before running the :meth:`calibration_pattern.full_interlocked_print` function:

.. code-block:: python

	pattern.gen.tools = [0,1]
	pattern.gen.standby_temperatures = [175,175]
	pattern.gen.printing_temperatures = [200,200]
	pattern.gen.extrusion_multiplier = [1.1,1.1]
	pattern.gen.retraction_distance =[5,5]
	pattern.gen.x_offsets = [0,0]
	pattern.gen.y_offsets = [0,0]
	
.. toctree::
   :maxdepth: 2
   :caption: Contents:

generator class
===============
.. automodule:: generator
   :members:
   :undoc-members:
   :show-inheritance:
   
calibration_pattern class
===============
.. automodule:: calibration_pattern
   :members:
   :undoc-members:
   :show-inheritance:




Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
