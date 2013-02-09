import inputGcode
import Tkinter as tk
from tkFileDialog import askopenfilename

class FrameGcode(tk.Frame):
	def __init__(self,master=None,pMenu=None,cutter=None):
		tk.Frame.__init__(self,master)
		self.cutter=cutter
		if not pMenu is None:
			menu=tk.Menu(pMenu)
			pMenu.add_cascade(label="Gcode", menu=menu)
			menu.add_command(label="Open...", command=self.Open)
			menu.add_command(label="Start Cutting", command=self.Start)
		self.textbox=tk.Text(self)
		self.textbox.pack(expand=True,fill=tk.BOTH)

	def Open(self):
		filename=askopenfilename(filetypes=[('gcode','.ngc'),('textfiles','*.txt'),('all files', '.*')])
		if filename=='': return
		with open(filename) as f:
			data=f.read()
			self.textbox.delete(1.0,tk.END)
			self.textbox.insert(tk.END,data)

	def Start(self):
		oldin=self.cutter.input
		self.cutter.nextInputs.append(oldin)
		gcode=inputGcode.InputGcode(self.textbox.get(1.0,tk.END))
		self.cutter.input=gcode

