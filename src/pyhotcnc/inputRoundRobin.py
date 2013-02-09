import moveUtil
class inRoundRobin(object):
	def __init__(self,inputs):
		self.inputs=inputs
		self.cur=0

	def next(self):
		for i in xrange(len(self.inputs)):
			now=(self.cur+i)%len(self.inputs)
			nextmove=self.inputs[now].next()
			if nextmove is moveUtil.NoMove:
				continue
			else:
				self.cur+=1
				self.cur%=len(self.inputs)
				return nextmove
		return None
