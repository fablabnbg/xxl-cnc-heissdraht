import time
import threading as thr
import serial
import Queue

class drvFabGrbl(object):
	def __init__(self, device):
		self.device=device
		self.queue=Queue.Queue(maxsize=0)
		self.running=True
		self.error=None
		self.thread=thr.Thread(target=self.start)
		self.thread.daemon=True
		self.thread.start()

	def start(self):
		if isinstance(self.device,str):
			self.s = serial.Serial(self.device,9600)
		else:
			self.s = self.device
		self.s.write("\r\n\r\n")
		# Wait for grbl to initialize and flush startup text in serial input
		time.sleep(2)
		self.s.flushInput()
		while self.running:
			cmd=self.queue.get()
			self.s.write(cmd)
			print "DEBUG drvgrbl: %s"%cmd
			time.sleep(2)
			res=self.s.readline().strip()
			if res!='ok':
				self.error='Error: "%s" at Command "%s"'%(res,cmd)
				raise EnvironmentError(self.error)
			self.queue.task_done()

	def close(self):
		self.running=False
		self.write("")
		self.thread.join()
		self.s.close()

	def write(self,cmd):
		if not self.error is None:
			raise EnvironmentError(self.error)
		cmd=cmd.strip()+'\r\n'
		self.queue.put(cmd)

	def flush(self):
		self.queue.join()
		
