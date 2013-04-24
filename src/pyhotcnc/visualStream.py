from __future__ import print_function

class vStream(object):
	def __init__(self,stream):
		self.stream=stream

	def warp(self,pos):
		self.stream.write('-'*10)
		self.stream.write('\n')
		self.stream.write(str(pos))
		self.stream.write('\n')

	def move(self,pos):
		self.stream.write(str(pos))
		self.stream.write('\n')

	def setZero(self):
		self.warp((0,0,0,0))

	def wait(self):
		self.stream.flush()

	def home(self):
		self.stream.write('Homing')
		self.stream.write('\n')
		self.setZero()

	def power(self,value):
		self.stream.write('Power %f'%value)
		self.stream.write('\n')



