import Tkinter as tk
import moveUtil
from tkGraph import Graph

class vTk(tk.Frame,object):
	def __init__(self,master=None,xSize=40,ySize=30,posVars=None):
		tk.Frame.__init__(self,master)
		self.moveQueue=[]
		if posVars is None:
			self.posVars=[]
			for i in xrange(4):
				self.posVars.append(tk.StringVar)
		else:
			self.posVars=posVars
		self.WX=Graph(self,xSize=xSize,ySize=ySize,onClick=self.clickWX)
		self.YZ=Graph(self,xSize=xSize,ySize=ySize,onClick=self.clickYZ)

		self.WX.pack(side=tk.TOP)
		self.YZ.pack(side=tk.TOP)
		self.pos=(0,0,0,0)
		self.offset=(0,0,0,0)
		self.warp(self.pos)

	def next(self):
		if len(self.moveQueue)!=0:
			return self.moveQueue.pop(0)
		else:
			return moveUtil.NoMove

	def setText(self,pos):
		for i in range(4):
			if not pos[i] is None:
				self.posVars[i].set("%.2f"%pos[i])

	def warp(self,pos):
		self.setText(pos)
		self.WX.addline(*pos[0:2])
		self.YZ.addline(*pos[2:4])
		self.pos=pos

	def move(self,pos):
		self.setText(pos)
		self.WX.append(*pos[0:2])
		self.YZ.append(*pos[2:4])
		self.pos=pos

	def setZero(self):
		self.offset=map(lambda a,b:a+b,self.pos,self.offset)
		self.WX.setOffset(self.offset[0:2])
		self.YZ.setOffset(self.offset[2:4])
		self.warp((0,0,0,0))

	def clickWX(self,w,x,both):
		pos=[None]*4
		pos[0]=w
		pos[1]=x
		if both:
			pos[2]=w
			pos[3]=x
		print both
		self.moveQueue.append(moveUtil.absMove(pos))

	def clickYZ(self,y,z,both):
		pos=[None]*4
		pos[2]=y
		pos[3]=z
		if both:
			pos[0]=y
			pos[1]=z
		print both
		self.moveQueue.append(moveUtil.absMove(pos))

	def wait(self):
		pass

	def home(self):
		self.offset=(0,0,0,0)
		self.pos=(0,0,0,0)
		self.setZero()

	def power(self,value):
		val='red' if value>0.01 else 'white'
		self.WX.a.set_axis_bgcolor(val)
		self.YZ.a.set_axis_bgcolor(val)
		self.WX.redraw()
		self.YZ.redraw()
