import gcode
import moveUtil

class InputGcode(object):
	def __init__(self, data):
		code=gcode.Gcode()
		code.interpret(data.split('\n'))
		self.coords=code.coords
		self.cur=0

	def next(self):
		if self.cur>=len(self.coords):
			return None
		self.cur+=1
		return moveUtil.absMove(self.coords[self.cur-1])


