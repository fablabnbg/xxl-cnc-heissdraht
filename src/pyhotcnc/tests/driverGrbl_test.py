import unittest
import pyparsing
from threading import Lock
import time

from driverFabGrbl import drvFabGrbl

class MockSerial(object):
	def __init__(self):
		self.data=''
	def write(self,data):
		self.data+=data
	def readline(self):
		time.sleep(1)
		return 'ok\r\n'
	def flushInput(self):
		pass
	def close(self):
		pass

class TestDriveGrbl(unittest.TestCase):
	def setUp(self):
		self.s=MockSerial()
		self.drv=drvFabGrbl(device=self.s)

	def test_init(self):
		self.drv.flush()
		self.assertEqual(self.s.data,'\r\n\r\n')

	def test_oneLine(self):
		self.drv.write('abc')
		self.drv.flush()
		self.assertEqual(self.s.data,'\r\n\r\nabc\r\n')

	def test_twoLines(self):
		self.drv.write('abc')
		self.drv.write('def')
		self.drv.flush()
		self.assertEqual(self.s.data,'\r\n\r\nabc\r\ndef\r\n')
