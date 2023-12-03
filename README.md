# Automated xy calibration for 3D printers using a scanner
This program can be used to calibration the x and y offset of a multi-material 3D printer by printing a calibration pattern on a piece of paper, scanning it using a digital scanner and analysing it. The code exists of a gcode generator in python, that generates the gcode for the calibration pattern, as well as a image processing script in Matlab that detects the offsets automatically. An example of how the calibration pattern might look is shown below.

<img width="705" alt="example" src="https://github.com/martijnschouten/scanner_3D_printer_calibration/assets/6079002/299cb75f-ac8e-4736-a79d-d5f4b6caa358">


# Generator usage
On windows:
1. Make sure you have a working python installation (tested using python 3.7.7)
1. Open command prompt
1. Use the `cd` to go to the gcode generator folder that containt the python script of the gcode generator
1. Make a virtual environment by running `python -m venv venv`
1. Activate the virtual environment by running `venv\Scripts\activate`
1. Modify `test_pattern_generator.py` such that it will produce the desired pattern
1. Run `test_pattern_generator.py`
1. Print the resulting gcode file using your printer

For more information on the gcode generator read the [documentation](gcode generator/docs/build/latex/gcodegenerator.pdf). Note that the generator uses G2 gcodes for generating controlled arc moves. These are not supported by every gcode visualiser. A gcode visualiser that was found to be able to simulate this is CAMotics.

# Analyser usage
1. Scan your 
1. Make an analyser object `Analyser = analyser;`
1. Run `Analyser.analyse_interlocked_differential('data/','example',1,[1,2,3,4,5],false,false)` to analyse an image named "example_12345-1.bmp" ,in the folder "data/", printed using nozzles 1,2,3,4 and 5 and in orientation 1 without making any figures.
1. The result will be written to the file "example_12345.mat".  with two cell arrays x_offset_mat and y_offset_mat. Each cell contains a matrix. Each row corresponds to a rotation and each column corresponds to a structure. The results in different cells are calculated using different algorithms:
-offset{1}: 1st harmonic, fft quadrature detection
-offset{2}: 2st harmonic, fft quadrature detection
-offset{3}: 3st harmonic, fft quadrature detection
-offset{4}: 4st harmonic, fft quadrature detection
-offset{5}: correlation based algorithm
-offset{6}: 1st harmonic, fir quadrature detection
-offset{7}: 2st harmonic, fir quadrature detection
-offset{8}: 3st harmonic, fir quadrature detection
1. For more information on the analyser class run `doc analyser`

# Acknowledgement
This work was developed within the Wearable Robotics programme, funded by the Dutch Research Council (NWO) and with support of Ultimaker.

<img src="https://github.com/martijnschouten/scanner_3D_printer_calibration/assets/6079002/3ee32e5d-3d7a-441d-9ef7-e05a4b7561dc" width="62" height="100"><img src="https://github.com/martijnschouten/scanner_3D_printer_calibration/assets/6079002/759158da-69d6-4cec-bdf6-240dc8832eab.png" width="165" height="100">
