import gcode
import moveUtil

class InputGcode(object):
	def __init__(self, data,bounding_box=False):
		code=gcode.Gcode()
		code.interpret(data.split('\n'))
		self.coords=code.boundingBox() if bounding_box else code.coords
		self.cur=-1

	def next(self):
		if self.cur==-1:                #Before actual gcode
			move=moveUtil.push      #Save current position
		elif self.cur==len(self.coords):#after gcode is over
			move=moveUtil.pop       #return to saves position
		elif self.cur>len(self.coords): #after return
			move=None               #do nothing
		else:
			move=moveUtil.absMove(self.coords[self.cur]) #positions from gcode
		self.cur+=1
		return move


