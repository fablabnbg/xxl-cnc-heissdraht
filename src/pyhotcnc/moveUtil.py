def absMove(coord):
	return lambda c:c._MoveTo(coord)

def relMove(coord):
	return lambda c:c._MoveTo(map(lambda a,b:a+b,c.pos,coord))

def setZero(c):
	return c._setZero()

def NoMove(c):
	pass
