def absMove(coord):
	return lambda c:c._MoveTo(coord)

def relMove(coord):
	return lambda c:c._MoveTo(map(lambda a,b:a+b,c.pos,coord))

def setZero(c):
	return c._setZero()

def push(c):
	return c._push()

def pop(c):
	return c._pop()

def home(c):
	return c._home()

def NoMove(c):
	pass
