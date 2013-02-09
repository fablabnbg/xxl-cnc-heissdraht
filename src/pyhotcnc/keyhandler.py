import moveUtil

class KeyboardBasic(object):
	def __init__(self, tkroot):
		tkroot.bind('<Escape>',lambda x: tkroot.quit())

class KeyboardMisc(object):
	def __init__(self, tkroot):
		self.doSet=False
		tkroot.bind('<Control-0>',self._setZero)
	def _setZero(self,evt):
		self.doSet=True
	def next(self):
		if self.doSet:
			self.doSet=False
			return moveUtil.setZero
		else:
			return None

class KeyboardMove(object):
	def __init__(self, tkroot):
		self.tkroot=tkroot
		self.toMove=[0,0,0,0]
		self.speed=10
		self.ctrl=False

		tkroot.bind('<KeyPress-Left>',lambda x: self.PressDir(1,-1))
		tkroot.bind('<KeyPress-Right>', lambda x: self.PressDir(1,1))
		tkroot.bind('<KeyPress-Up>', lambda x: self.PressDir(0,1))
		tkroot.bind('<KeyPress-Down>', lambda x: self.PressDir(0,-1))
		tkroot.bind('<KeyPress-a>',lambda x: self.PressDir(3,-1))
		tkroot.bind('<KeyPress-d>', lambda x: self.PressDir(3,1))
		tkroot.bind('<KeyPress-w>', lambda x: self.PressDir(2,1))
		tkroot.bind('<KeyPress-s>', lambda x: self.PressDir(2,-1))
		tkroot.bind('<KeyPress-A>',lambda x: self.PressDir(3,-1))
		tkroot.bind('<KeyPress-D>', lambda x: self.PressDir(3,1))
		tkroot.bind('<KeyPress-W>', lambda x: self.PressDir(2,1))
		tkroot.bind('<KeyPress-S>', lambda x: self.PressDir(2,-1))
		tkroot.bind('<KeyPress-Shift_L>', lambda x: self.setSpeed(1))
		tkroot.bind('<KeyPress-Shift_R>', lambda x: self.setSpeed(1))
		tkroot.bind('<KeyPress-Control_L>', lambda x: self.setCTRL(True))
		tkroot.bind('<KeyPress-Control_R>', lambda x: self.setCTRL(True))

		tkroot.bind('<KeyRelease-Control_L>', lambda x: self.setCTRL(False))
		tkroot.bind('<KeyRelease-Control_R>', lambda x: self.setCTRL(False))
		tkroot.bind('<KeyRelease-Left>', lambda x: self.ReleaseDir(1))
		tkroot.bind('<KeyRelease-Right>', lambda x: self.ReleaseDir(1))
		tkroot.bind('<KeyRelease-Up>', lambda x: self.ReleaseDir(0))
		tkroot.bind('<KeyRelease-Down>', lambda x: self.ReleaseDir(0))
		tkroot.bind('<KeyRelease-a>', lambda x: self.ReleaseDir(3))
		tkroot.bind('<KeyRelease-d>', lambda x: self.ReleaseDir(3))
		tkroot.bind('<KeyRelease-w>', lambda x: self.ReleaseDir(2))
		tkroot.bind('<KeyRelease-s>', lambda x: self.ReleaseDir(2))
		tkroot.bind('<KeyRelease-A>', lambda x: self.ReleaseDir(3))
		tkroot.bind('<KeyRelease-D>', lambda x: self.ReleaseDir(3))
		tkroot.bind('<KeyRelease-W>', lambda x: self.ReleaseDir(2))
		tkroot.bind('<KeyRelease-S>', lambda x: self.ReleaseDir(2))
		tkroot.bind('<KeyRelease-Shift_L>', lambda x: self.setSpeed(10))
		tkroot.bind('<KeyRelease-Shift_R>', lambda x: self.setSpeed(10))

	def setCTRL(self,val):
		self.ctrl=val

	def setSpeed(self,spd):
		self.speed=spd
		for i in xrange(len(self.toMove)):
			if self.toMove[i]!=0:
				d=1 if self.toMove[i]>0 else -1
				self.toMove[i]=self.speed*d

	def PressDir(self,idx,direction):
		if not self.ctrl: return
		self.toMove[idx]=direction*self.speed
	def ReleaseDir(self,idx):
		self.toMove[idx]=0

	def next(self):
		if any(a!=0 for a in self.toMove):
			return moveUtil.relMove(self.toMove)
		else:
			return moveUtil.NoMove
