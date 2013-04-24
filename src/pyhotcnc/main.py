#!/usr/bin/python
import sys
import Tkinter as tk

import visualTk
import visualStream
import outputGcode
from driverFabGrbl import drvFabGrbl,SIZE1,SIZE2
from inputRoundRobin import inRoundRobin
from menuCutter import MenuCutter
import cutter
import gcode
import keyhandler
import frameGcode
import inputTkCoord

def NextMove():
	c.NextMove()
	root.after(100,NextMove)
	
if __name__=='__main__':
	root=tk.Tk()
	menu=tk.Menu(root)
	root.config(menu=menu)
	inTkc=inputTkCoord.inputTkCoord(root)
	out1=visualTk.vTk(root,xSize=SIZE1,ySize=SIZE2,posVars=inTkc.coord)
	out2=outputGcode.outGcode(driver=drvFabGrbl('/dev/ttyUSB0'))
	out3=visualStream.vStream(sys.stdout)
	c=cutter.Cutter(output=[out1,out2])
	mc=MenuCutter(pMenu=menu,Cutter=c)
	gb=frameGcode.FrameGcode(root,pMenu=menu,cutter=c)
	gb.pack(side=tk.LEFT,fill=tk.BOTH,expand=True)
	inTkc.pack(side=tk.TOP)
	out1.pack(side=tk.TOP)
	inKMove=keyhandler.KeyboardMove(root)
	inKMisc=keyhandler.KeyboardMisc(root)
	keyhandler.KeyboardBasic(root)
	c.input=inRoundRobin([inKMove,inKMisc,out1,inTkc])
	root.after(100,NextMove)
	root.mainloop()

