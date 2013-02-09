class outGcode(object):
	def __init__(self, driver, axes=('W','X','Y','Z')):
		self.driver=driver
		self.template=(" %c%%.2f"*4)%axes+' F2500\n'

	def move(self,pos):
		cmd="G1"+self.template%pos
		self.driver.write(cmd)

	def warp(self,pos):
		cmd="G0"+self.template%pos
		self.driver.write(cmd)

	def setZero(self):
		cmd="G92 W0 X0 Y0 Z0"
		self.driver.write(cmd)

	def wait(self):
		self.driver.flush()

