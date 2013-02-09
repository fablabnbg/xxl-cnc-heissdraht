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


