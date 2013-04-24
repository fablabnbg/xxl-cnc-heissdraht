import time
import threading as thr
import serial
import Queue

BUFLEN=100
SIZE1=240.0
SIZE2=235.0

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
		self.s.write("\n\n")
		# Wait for grbl to initialize and flush startup text in serial input
		time.sleep(2)
		self.s.flushInput()
		# check if there really is a grbl
		self.s.write("\n")
		res=self.s.readline().strip()
		if res[:2]!='ok':
			raise EnvironmentError('grbl is not responding')
		# set steps/mm to reasonable values
                params=[91.5,91.5,91.5,30,3000,3000,0.1,4,100,0.05,91.5];
                for i,p in enumerate(params):
                        self.s.write("$%i=%.3f\n"%(i,p))
                        print self.s.readline()
		# Always keep motors on
		self.s.write("M100\n")
		time.sleep(2)
		self.s.flushInput()
		buffill=[]
		while self.running:
			cmd=self.queue.get()
			while sum(buffill)+len(cmd)>=BUFLEN:
				res=self.s.readline().strip()
				if res[:2]!='ok':
					self.error='Error: "%s" at Command "%s"'%(res,cmd)
					print self.error
					self.error=None
					self.s.write("\n")
					self.s.readline()
					self.s.flushInput()
					#raise EnvironmentError(self.error)
				buffill.pop(0)
			self.s.write(cmd)
			buffill.append(len(cmd))
			self.queue.task_done()

	def close(self):
		self.running=False
		self.write("")
		self.thread.join()
		self.s.close()

	def write(self,cmd):
		if not self.error is None:
			print self.error
			#raise EnvironmentError(self.error)
		cmd=cmd.strip()+'\n'
		self.queue.put(cmd)

	def flush(self):
		self.queue.join()
		
	def home(self):
		self.write('G91')
		self.write('G01 W%.3f X%.3f Y%.3f Z%.3f F1000'%(-SIZE1/4,-SIZE2/4,-SIZE1/4,-SIZE2/4))
		self.write('G90')
