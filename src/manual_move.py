import serial
import time
import Tkinter as tk

def MoveLeft1(*args):
	s.write('G0 X0.5\r\n')
	print s.readline()
def MoveLeft2(*args):
	s.write('G0 Z0.5\r\n')
	print s.readline()
def MoveRight1(*args):
	s.write('G0 X-0.5\r\n')
	print s.readline()
def MoveRight2(*args):
	s.write('G0 Z-0.5\r\n')
	print s.readline()
def MoveUp1(*args):
	s.write('G0 W0.5\r\n')
	print s.readline()
def MoveUp2(*args):
	s.write('G0 Y0.5\r\n')
	print s.readline()
def MoveDown1(*args):
	s.write('G0 W-0.5\r\n')
	print s.readline()
def MoveDown2(*args):
	s.write('G0 Y-0.5\r\n')
	print s.readline()

if __name__=='__main__':
	s=serial.Serial('/dev/ttyUSB0',9600)
	s.write('\r\n\r\n')
	time.sleep(2)
	s.flush()
	s.write('G91\r\n')
	print s.readline()
	s.write('M100\r\n')
	print s.readline()
	
	root=tk.Tk()
	root.bind('<Left>',MoveLeft1)
	root.bind('<Right>',MoveRight1)
	root.bind('<Up>',MoveUp1)
	root.bind('<Down>',MoveDown1)
	root.bind('<a>',MoveLeft2)
	root.bind('<d>',MoveRight2)
	root.bind('<w>',MoveUp2)
	root.bind('<s>',MoveDown2)
	root.mainloop()
