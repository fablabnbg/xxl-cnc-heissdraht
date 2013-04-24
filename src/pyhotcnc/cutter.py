class Cutter(object):
	def __init__(self,output=None, filter=None):
		self.output=output
		self.input=None
		self.nextInputs=[]
		self.pos=(0,0,0,0)
		self.pos_stack=[]
		if filter is None:
			self.filter=lambda x:x
		else:
			self.filter=filter

	def removeNone(self,pos):
		return tuple(map(lambda a,b:a if not a is None else b,pos,self.pos))

	def NextMove(self):
		if self.input is None: return
		nextmove=self.input.next()
		if not nextmove is None:
			nextmove(self)
		else:
			if len(self.nextInputs)>0:
				self.input=self.nextInputs.pop(0)

	def _MoveTo(self,pos):
		self.pos=self.removeNone(self.filter(pos))

		if not self.output is None:
			for out in self.output:
				out.move(self.pos)
		return self

	def _WarpTo(self,pos):
		self.pos=self.removeNone(self.filter(pos))

		if not self.output is None:
			for out in self.output:
				out.warp(self.pos)
		return self

	def _setZero(self):
		self.pos=(0,0,0,0)
		if not self.output is None:
			for out in self.output:
				out.setZero()
		return self

	def _home(self):
		self.pos=(0,0,0,0)
		if not self.output is None:
			for out in self.output:
				out.home()
		return self

	def _power(self, value):
		if not self.output is None:
			for out in self.output:
				out.power(value)
		return self


	def _push(self):
		self.pos_stack.append(self.pos)
		return self

	def _pop(self):
		self._MoveTo(self.pos_stack.pop())
		return self


