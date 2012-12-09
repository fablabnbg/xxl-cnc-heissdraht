#! /usr/bin/python
#
# 2012 (c) jw@suse.de - BSD Licensed.
#
# FROM: http://www.vtk.org/Wiki/VTK/Examples/Python/STLReader
#
import vtk
 
filename = "myfile.stl"
  
reader = vtk.vtkSTLReader()
reader.SetFileName(filename)
   
polyDataOutput = reader.GetOutput()
