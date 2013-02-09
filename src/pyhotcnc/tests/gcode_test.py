import unittest
import pyparsing
from StringIO import StringIO

from gcode import Gcode

class TestGcodeReader(unittest.TestCase):
	def setUp(self):
		self.a=Gcode()

	def test_empty(self):
		code=StringIO('')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0)])

	def test_onlyM2(self):
		code=StringIO('M2')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0)])

	def test_onlyM30(self):
		code=StringIO('M30')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0)])

	def test_singleG0(self):
		code=StringIO('G0')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,0,0,0)])

	def test_singleG1(self):
		code=StringIO('G1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,0,0,0)])

	def test_emptyLine(self):
		code=StringIO('G0\n\nM2')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,0,0,0)])

	def test_allG0(self):
		code=StringIO('G0 W1 X2 Y3 Z4')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(1,2,3,4)])

	def test_allG1(self):
		code=StringIO('G1 W1 X2 Y3 Z4')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(1,2,3,4)])

	def test_G0X(self):
		code=StringIO('G0 X2')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,2,0,0)])

	def test_G02digits(self):
		code=StringIO('G0 X20')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,20,0,0)])

	def test_MoveEndMove(self):
		code=StringIO('G0 X2\nM2\nG0 X2')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,2,0,0)])

	#two moves one coord
	def test_2MovesX(self):
		code=StringIO('G0 X2\nG0 X3')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,2,0,0),(0,3,0,0)])

	def test_2MovesXY(self):
		code=StringIO('G0 X2\nG0 Y3')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,2,0,0),(0,2,3,0)])

	def test_MoveOffset0Move(self):
		code=StringIO('G0 X1\nG92 X0\nG0 X1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,1,0,0),(0,2,0,0)])

	def test_MoveOffset1Move(self):
		code=StringIO('G0 X1\nG92 X1\nG0 X1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,1,0,0),(0,1,0,0)])
	
	def test_twoRelMoves(self):
		code=StringIO('G91\nG0 X1\nG0 X1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,1,0,0),(0,2,0,0)])
	
	def test_absRelAbs(self):
		code=StringIO('G0 X1\nG91\nG0 X1\nG90\nG0 X1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,1,0,0),(0,2,0,0),(0,1,0,0)])
	
	def test_absOffRel(self):
		code=StringIO('G0 X1\nG92 X10\nG91\nG0 X1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,1,0,0),(0,2,0,0)])
	
	def test_negatives(self):
		code=StringIO('G0 X-1')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,-1,0,0)])
	
	def test_decimals(self):
		code=StringIO('G0 X1.5')
		self.a.interpret(code)
		self.assertEqual(self.a.coords,[(0,0,0,0),(0,1.5,0,0)])
	
	def test_illegal(self):
		code=StringIO('R5')
		with self.assertRaises(pyparsing.ParseException):
			self.a.interpret(code)
	
	def test_illegalCmd(self):
		code=StringIO('G9999')
		with self.assertRaises(RuntimeError):
			self.a.interpret(code)
	
