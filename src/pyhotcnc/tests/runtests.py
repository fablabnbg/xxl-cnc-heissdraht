import unittest
import sys,os

sys.path.insert(0, os.path.join(os.path.dirname(__file__),'..'))

from gcode_test import TestGcodeReader
from driverGrbl_test import TestDriveGrbl

suites=[]
suites.append(unittest.TestLoader().loadTestsFromTestCase(TestGcodeReader))
suites.append(unittest.TestLoader().loadTestsFromTestCase(TestDriveGrbl))

suite=unittest.TestSuite(suites)
unittest.TextTestRunner(verbosity=2).run(suite)
