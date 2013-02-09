import sys
import Tkinter as tk

import visualTk
import visualStream
import outputGcode
from driverFabGrbl import drvFabGrbl
from inputRoundRobin import inRoundRobin
import cutter
import gcode
import keyhandler
import frameGcode

def NextMove():
	c.NextMove()
	root.after(100,NextMove)
	
if __name__=='__main__':
	root=tk.Tk()
	menu=tk.Menu(root)
	root.config(menu=menu)
	out1=visualTk.vTk(root,xSize=270,ySize=280)
	out1.pack(side=tk.RIGHT)
	out2=outputGcode.outGcode(driver=drvFabGrbl('/dev/ttyUSB0'))
	out3=visualStream.vStream(sys.stdout)
	c=cutter.Cutter(output=[out1,out2,out3])
	gb=frameGcode.FrameGcode(root,pMenu=menu,cutter=c)
	gb.pack(fill=tk.BOTH,expand=True)
	inKMove=keyhandler.KeyboardMove(root)
	inKMisc=keyhandler.KeyboardMisc(root)
	keyhandler.KeyboardBasic(root)
	c.input=inRoundRobin([inKMove,inKMisc,out1])
	root.after(100,NextMove)
	root.mainloop()

