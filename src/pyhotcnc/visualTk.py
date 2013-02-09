import Tkinter as tk
import moveUtil
from tkGraph import Graph

class vTk(tk.Frame,object):
	def __init__(self,master=None,xSize=40,ySize=30):
		tk.Frame.__init__(self,master)
		self.moveQueue=[]
		self.Wtext=tk.StringVar()
		self.Xtext=tk.StringVar()
		self.Ytext=tk.StringVar()
		self.Ztext=tk.StringVar()
		self.WX=Graph(self,xSize=xSize,ySize=ySize,onClick=self.clickWX)
		self.YZ=Graph(self,xSize=xSize,ySize=ySize,onClick=self.clickYZ)

		tk.Label(self,textvariable=self.Wtext).pack(side=tk.TOP)
		tk.Label(self,textvariable=self.Xtext).pack(side=tk.TOP)
		self.WX.pack(side=tk.TOP)
		tk.Label(self,textvariable=self.Ytext).pack(side=tk.TOP)
		tk.Label(self,textvariable=self.Ztext).pack(side=tk.TOP)
		self.YZ.pack(side=tk.TOP)

	def next(self):
		if len(self.moveQueue)!=0:
			return self.moveQueue.pop(0)
		else:
			return moveUtil.NoMove

	def setText(self,pos):
		w=pos[0]
		x=pos[1]
		y=pos[2]
		z=pos[3]
		if not w is None: self.Wtext.set("W=%.2f"%w)
		if not x is None: self.Xtext.set("X=%.2f"%x)
		if not y is None: self.Ytext.set("Y=%.2f"%y)
		if not y is None: self.Ztext.set("Z=%.2f"%z)

	def warp(self,pos):
		self.setText(pos)
		self.WX.addline(*pos[0:2])
		self.YZ.addline(*pos[2:4])

	def move(self,pos):
		self.setText(pos)
		self.WX.append(*pos[0:2])
		self.YZ.append(*pos[2:4])

	def setZero(self):
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
