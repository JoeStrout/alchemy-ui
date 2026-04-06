// This module returns the Rect class, which represents a 2D axis-aligned rectangle.
// A Rect is defined by x, y, width, and height.
// But functions are provided to get and set its center, maxY, and maxX sides too.

min = function(a,b)
	if a <= b then return a else return b
end function

max = function(a,b)
	if a >= b then return a else return b
end function


Rect = {}
Rect.x = 0
Rect.y = 0
Rect.width = 100
Rect.height = 100

Rect.maxX = function; return self.x + self.width; end function
Rect.maxY = function; return self.y + self.height; end function
Rect.centerX = function; return self.x + self.width/2; end function
Rect.centerY = function; return self.y + self.height/2; end function
Rect.center = function; return [self.centerX, self.centerY]; end function
Rect.area = function; return self.width * self.height; end function
Rect.isEmpty = function; return self.width == 0 or self.height == 0; end function

Rect.str = function
	return "Rect[" + self.x + ", " + self.y + ", " + self.width + ", " + self.height + "]"
end function

Rect.setXY = function(x, y)
	self.x = x
	self.y = y
end function

Rect.setCenter = function(cx, cy)
	self.x = cx - self.width/2
	self.y = cy - self.height/2
end function

Rect.setMaxX = function(maxX)
	self.x = maxX - self.width
end function

Rect.setMaxY = function(maxY)
	self.y = maxY - self.height
end function

Rect.setMaxXY = function(maxX, maxY)
	self.x = maxX - self.width
	self.y = maxY - self.height
end function

Rect.setXYWH = function(x, y, width, height)
	self.x = x
	self.y = y
	self.width = width
	self.height = height
end function

Rect.setXYMaxXMaxY = function(x, y, maxX, maxY)
	self.x = x
	self.y = y
	self.width = maxX - x
	self.height = maxY - y
end function

Rect.MakeXYWH = function(x, y, width, height)
	r = new self
	r.x = x
	r.y = y
	r.width = width
	r.height = height
	return r
end function

Rect.MakeXYMaxXMaxY = function(x, y, maxX, maxY)
	r = new self
	r.x = x
	r.y = y
	r.width = maxX - x
	r.height = maxY - y
	return r
end function

Rect.fixInversion = function
	if self.width < 0 then
		self.x += self.width
		self.width = -self.width
	end if
	if self.height < 0 then
		self.y += self.height
		self.height = -self.height
	end if
end function

Rect.inset = function(dist)
	self.x += dist
	self.y += dist
	self.width -= dist*2
	self.height -= dist*2
end function

Rect.outset = function(dist)
	self.inset -dist
end function

Rect.offset = function(dx, dy)
	self.x += dx
	self.y += dy
end function

Rect.overlaps = function(other)
	return self.x + self.width > other.x and 
	  self.x < other.x + other.width and
	  self.y + self.height > other.y and 
	  self.y < other.y + other.height
end function

Rect.contains = function(x, y)
	if y == null and x isa list then
		y = x[1]
		x = x[0]
	else if y == null and x isa map then
		y = x.y
		x = x.x
	end if
	return self.x <= x < self.x + self.width and
	       self.y <= y < self.y + self.height
end function

Rect.intersection = function(other)
	return Rect.MakeXYMaxXMaxY(min(self.maxX, other.x), min(self.maxY, other.y),
	  max(self.maxX, other.x), max(self.maxY, other.y))
end function

Rect.union = function(other)
	return Rect.MakeXYMaxXMaxY(min(self.x, other.x), min(self.y, other.y),
	  max(self.maxX, other.maxX), max(self.maxY, other.maxY))
end function

Rect.relativeTo = function(other)
	return Rect.MakeXYWH(self.x + other.x, self.maxY + other.y,
	  self.width, self.height)
end function


runUnitTests = function
	qa = {}
	qa.assert = function(condition)
		if condition then return
		print "Assertion failed"
		print stackTrace
		exit
	end function

	// Test MakeXYWH factory method
	r1 = Rect.MakeXYWH(10, 20, 50, 60)
	qa.assert r1.x == 10 and r1.y == 20
	qa.assert r1.width == 50 and r1.height == 60

	// Test getter methods: maxX, maxY, centerX, centerY, center, area
	qa.assert r1.maxX == 60 and r1.maxY == 80
	qa.assert r1.centerX == 35 and r1.centerY == 50
	qa.assert r1.center == [35, 50]
	qa.assert r1.area == 3000

	// Test MakeXYMaxXMaxY factory method
	r2 = Rect.MakeXYMaxXMaxY(10, 20, 60, 80)
	qa.assert r2.x == 10 and r2.y == 20
	qa.assert r2.width == 50 and r2.height == 60
	qa.assert r2.maxX == 60 and r2.maxY == 80

	// Test isEmpty
	r3 = Rect.MakeXYWH(0, 0, 0, 0)
	qa.assert r3.isEmpty
	r4 = Rect.MakeXYWH(0, 0, 10, 0)
	qa.assert r4.isEmpty
	r5 = Rect.MakeXYWH(0, 0, 0, 10)
	qa.assert r5.isEmpty
	r6 = Rect.MakeXYWH(0, 0, 10, 10)
	qa.assert not r6.isEmpty

	// Test offset
	r7 = Rect.MakeXYWH(10, 20, 50, 60)
	r7.offset 5, 10
	qa.assert r7.x == 15 and r7.y == 30
	qa.assert r7.width == 50 and r7.height == 60

	// Test setXY
	r8 = Rect.MakeXYWH(10, 20, 50, 60)
	r8.setXY 100, 200
	qa.assert r8.x == 100 and r8.y == 200
	qa.assert r8.width == 50 and r8.height == 60

	// Test setCenter
	r9 = Rect.MakeXYWH(10, 20, 50, 60)
	r9.setCenter 100, 200
	qa.assert r9.centerX == 100 and r9.centerY == 200
	qa.assert r9.x == 75 and r9.y == 170

	// Test setMaxX
	r10 = Rect.MakeXYWH(10, 20, 50, 60)
	r10.setMaxX 100
	qa.assert r10.maxX == 100
	qa.assert r10.x == 50 and r10.width == 50

	// Test setMaxY
	r11 = Rect.MakeXYWH(10, 20, 50, 60)
	r11.setMaxY 100
	qa.assert r11.maxY == 100
	qa.assert r11.y == 40 and r11.height == 60

	// Test setMaxXY
	r12 = Rect.MakeXYWH(10, 20, 50, 60)
	r12.setMaxXY 100, 200
	qa.assert r12.maxX == 100 and r12.maxY == 200
	qa.assert r12.x == 50 and r12.y == 140

	// Test fixInversion with negative width
	r15 = Rect.MakeXYWH(50, 50, -20, 30)
	r15.fixInversion
	qa.assert r15.x == 30 and r15.y == 50
	qa.assert r15.width == 20 and r15.height == 30

	// Test fixInversion with negative height
	r16 = Rect.MakeXYWH(50, 50, 20, -30)
	r16.fixInversion
	qa.assert r16.x == 50 and r16.y == 20
	qa.assert r16.width == 20 and r16.height == 30

	// Test fixInversion with both negative
	r17 = Rect.MakeXYWH(50, 50, -20, -30)
	r17.fixInversion
	qa.assert r17.x == 30 and r17.y == 20
	qa.assert r17.width == 20 and r17.height == 30

	// Test inset
	r18 = Rect.MakeXYWH(10, 20, 100, 80)
	r18.inset 10
	qa.assert r18.x == 20 and r18.y == 30
	qa.assert r18.width == 80 and r18.height == 60

	// Test outset
	r19 = Rect.MakeXYWH(20, 30, 80, 60)
	r19.outset 10
	qa.assert r19.x == 10 and r19.y == 20
	qa.assert r19.width == 100 and r19.height == 80

	// Test contains with separate x, y
	r20 = Rect.MakeXYWH(10, 20, 50, 60)
	qa.assert r20.contains(35, 50)
	qa.assert r20.contains(10, 20)
	qa.assert not r20.contains(5, 50)
	qa.assert not r20.contains(35, 15)
	qa.assert not r20.contains(60, 50)  // maxX edge (exclusive)
	qa.assert not r20.contains(35, 80)  // maxY edge (exclusive)

	// Test contains with list
	r21 = Rect.MakeXYWH(10, 20, 50, 60)
	qa.assert r21.contains([35, 50])
	qa.assert not r21.contains([5, 50])

	// Test contains with map
	r22 = Rect.MakeXYWH(10, 20, 50, 60)
	qa.assert r22.contains({"x": 35, "y": 50})
	qa.assert not r22.contains({"x": 5, "y": 50})

	// Test overlaps - non-overlapping rects
	r23 = Rect.MakeXYWH(10, 10, 20, 20)
	r24 = Rect.MakeXYWH(50, 50, 20, 20)
	qa.assert not r23.overlaps(r24)
	qa.assert not r24.overlaps(r23)

	// Test overlaps - overlapping rects
	r25 = Rect.MakeXYWH(10, 10, 30, 30)
	r26 = Rect.MakeXYWH(20, 20, 30, 30)
	qa.assert r25.overlaps(r26)
	qa.assert r26.overlaps(r25)

	// Test overlaps - touching edges (should not overlap)
	r27 = Rect.MakeXYWH(10, 10, 20, 20)
	r28 = Rect.MakeXYWH(30, 10, 20, 20)
	qa.assert not r27.overlaps(r28)

	// Test intersection
	r29 = Rect.MakeXYWH(10, 10, 30, 30)
	r30 = Rect.MakeXYWH(20, 20, 30, 30)
	r31 = r29.intersection(r30)
	qa.assert r31.x == 20 and r31.y == 20
	qa.assert r31.maxX == 40 and r31.maxY == 40

	// Test union
	r32 = Rect.MakeXYWH(10, 10, 20, 20)
	r33 = Rect.MakeXYWH(40, 40, 20, 20)
	r34 = r32.union(r33)
	qa.assert r34.x == 10 and r34.y == 10
	qa.assert r34.maxX == 60 and r34.maxY == 60

	print "All unit tests passed."
end function


if locals == globals then
	runUnitTests
else
	return Rect
end if