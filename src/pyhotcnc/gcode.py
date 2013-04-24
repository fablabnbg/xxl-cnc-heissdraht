import pyparsing
AXES=['W','X','Y','Z']
CMDS=['G','M','T']
MM_PER_INCH=2.45

class Gcode(object):
	def __init__(self):
		self.coords=[(0,0,0,0)]
		self.limitsMax=[-100000,-100000,-100000,-100000]
		self.limitsMin=[100000,100000,100000,100000]
		self.inches=False
		self.absolute=True
		self.offset=(0,0,0,0)

	def interpret(self,f):
		opened=False
		if isinstance(f,str):
			opened=True
			f=open(f)
		for l in f:
			if self.interpretLine(l):
				break

		if opened:
			f.close()
		self.coords.pop(0)

	def interpretLine(self,l):
		#Construct parsing rules
		natural=pyparsing.Word(pyparsing.nums)
		natural_n=pyparsing.Word(pyparsing.nums)
		natural_n.setParseAction(lambda t: int(t[0]))
		integer=pyparsing.Optional(pyparsing.oneOf(['-', '+']))+natural
		decimal=pyparsing.Word('.',pyparsing.nums)
		exponent=pyparsing.Literal('e')+integer
		number=pyparsing.Combine(integer+pyparsing.Optional(decimal)+pyparsing.Optional(exponent))
		number.setParseAction(lambda t: float(t[0]))
		cmd=pyparsing.Group(pyparsing.oneOf(CMDS)+natural_n)
		coord=pyparsing.Group(pyparsing.oneOf(AXES)+number)
		line=cmd+pyparsing.Group(pyparsing.ZeroOrMore(coord))

		if len(l.strip())==0: return False

		res=line.parseString(l).asList()
		letter=res[0][0]
		num=res[0][1]
		if letter=='G':
			return self.interpretG(num,res[1])
		if letter=='M':
			return self.interpretM(num)
		if letter=='T':
			return self.interpretT(num)
		
	def interpretG(self,num,data):
		if num==0 :self.appendCoords(self.getCoords(data))
		elif num==1 :self.appendCoords(self.getCoords(data))
		elif num==90: self.absolute=True
		elif num==91: self.absolute=False
		elif num==92 :self.setOffset(data)
		else:
			raise RuntimeError('Illegal command: G%i'%num)
		return False

	def interpretM(self,num):
		if num==2: return True
		elif num==30: return True
		else:
			raise RuntimeError('Illegal command: M%i'%num)
		return False

	def interpretT(self,num):
		return False

	def getRawCoords(self,data):
		coords=[None]*len(AXES)
		for c in data:
			coords[AXES.index(c[0])]=c[1]
		return coords
	
	def getCoords(self,data):
		coords=self.getRawCoords(data)
		if self.inches:
			coords=map(lambda a: a*MM_PER_INCH if not a is None else None,coords)
		if not self.absolute:
			coords=map(lambda a,b:a+b if not a is None else None,coords,self.coords[-1])
		else:
			coords=map(lambda a,b:a+b if not a is None else None,coords,self.offset)
		coords=map(lambda a,b:a if not a is None else b,coords,self.coords[-1])
		return tuple(coords)

	def setOffset(self,data):
		coords=self.getRawCoords(data)
		self.offset=map(lambda a,b,c:c-a if not a is None else b, coords, self.offset, self.coords[-1])

	def appendCoords(self,coord):
		self.coords.append(coord)

	def boundingBox(self):
		limitsMin=[min(x) for x in zip(*self.coords)]
		limitsMax=[max(x) for x in zip(*self.coords)]
		res=[
			(limitsMax[0],limitsMin[1],limitsMax[2],limitsMin[3]),
			(limitsMax[0],limitsMax[1],limitsMax[2],limitsMax[3]),
			(limitsMin[0],limitsMax[1],limitsMin[2],limitsMax[3]),
			(limitsMin[0],limitsMin[1],limitsMin[2],limitsMin[3]),
			(limitsMax[0],limitsMin[1],limitsMax[2],limitsMin[3])
		]
		return res
