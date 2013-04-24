#set encoding: latin1
import matplotlib
matplotlib.use('TkAgg',warn=False)
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import Tkinter as tk

class Graph(tk.Frame,object):
	def __init__(self,master=None,onClick=None,xSize=40,ySize=30):
		self.onClick=(lambda x,y,z:None) if onClick is None else onClick
		tk.Frame.__init__(self,master)

		self.f = Figure(figsize=(4,4), dpi=100)		# return a matplotlib.figure.Figure instance, Höhe und Breite in Inches
		self.a = self.f.add_subplot(111)		# Add a subplot with static key "111" and return instance to it
		
		self.a.grid(True)				# Set the axes grids on

		self.xSize=xSize
		self.ySize=ySize
		
		self.canvas = FigureCanvasTkAgg(self.f, master=self)	# The Canvas widget provides structured graphics facilities for Tkinter.
		self.canvas.mpl_connect('button_press_event', self.rawOnClick)
		
		self.canvas.show()				# Aus matplotlib: display all figures and block until the figures have been closed
		self.canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=1)

		self.setOffset((0,0))

	def addline(self,x,y):
		self.curline=matplotlib.lines.Line2D([y],[x])
		self.a.add_line(self.curline)

	def append(self,x,y):
		y0,x0=self.curline.get_data()
		x0.append(x)
		y0.append(y)
		self.curline.set_data(y0,x0)
		self.redraw()

	def rawOnClick(self,evt):
		print evt.key
		both=True if evt.key=='shift' else False
		self.onClick(evt.ydata, evt.xdata, both)

	def clear(self):
		self.a.clear()

	def setOffset(self,offset):
		self.a.set_ylim((-offset[0],self.xSize-offset[0]))
		self.a.set_xlim((-offset[1],self.ySize-offset[1]))
		self.a.clear()
		self.redraw()

	def redraw(self):
		self.canvas.draw()
	
if __name__=='__main__':
	r=tk.Tk()
	g=Graph(r)
	g.pack()
	g.addline(1,1)
	g.append(2,2)
	r.mainloop()
