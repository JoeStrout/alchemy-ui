// Alchemy UI system.
//
// A layout consists of a hierarchy of Rects or Rect subclasses.
// Some of those know how to render themselves and respond to
// input events.

import "mapUtil"
import "grfon"
import "Rect"
rl = raylib
rl.SetConfigFlags rl.FLAG_WINDOW_HIGHDPI + rl.FLAG_WINDOW_RESIZABLE
rl.InitWindow

// Image resize methods (applied separately for horizontal and vertical)
STRETCH = "STRETCH"  // scale image directly into output size
SLICE = "SLICE"  // keep ends constant size, but scale middle in between
TILE = "TILE"  // repeat image as needed to fill space

//----------------------------------------------------------------------
// Global helper function

// Normalize a value that may be a single number, a pair, or a quad
// into a list of the expected length (2 or 4).
normalizeSides = function(val, count)
	if val isa number then
		result = []
		for i in range(1, count)
			result.push val
		end for
		return result
	end if
	if val.len == 2 and count == 4 then
		return [val[0], val[1], val[0], val[1]]
	end if
	return val
end function

// file.readAll really should be part of the built-in API, but:
file_readAll = function(path)
	f = file.open(path)
	if not f then
		print "Unable to open file: " + path
		exit
	end if
	result = f.read
	f.close
	return result
end function

qa = {}
qa.assert = function(condition, msg)
	if condition then return
	if msg then
		msg = "Assertion failed: " + msg
	else
		msg = "Assertion failed"
	end if
	print msg
	for loc in stackTrace
		print " - " + loc
	end for
	exit
end function

//----------------------------------------------------------------------
// Font: represents a TrueType font; internally, it caches a Raylib
// font for each size it has needed.  It also provides handy drawing
// methods for common needs (drawing centered text, etc.).
Font = {}
Font.path = ""    // source path to font file
Font.cache = null // map of pixel size : Raylib font
Font.defaultSize = 24	// default size when not otherwise specified

Font.Load = function(path, defaultSize)
	info = file.info(path)
	if not info then
		print "Font path not found: " + path
		exit
	end if
	font = new self
	font.path = path
	font.cache = {}
	if defaultSize != null then font.defaultSize = defaultSize
	print "Made font: " + font
	return font
end function

Font.get = function(logicalSize)
	if not (logicalSize isa number) then
		print "Invalid argument to Font.get: " + logicalSize
		print stackTrace
		exit
	end if
	pixelSize = logicalSize * rl.GetWindowScaleDPI.x
	if not self.cache.hasIndex(pixelSize) then
		print "Loading font cache for " + pixelSize
		self.cache[pixelSize] = rl.LoadFontEx(self.path, pixelSize, null, 0)
	end if
	return self.cache[pixelSize]
end function

Font.print = function(s="", x=0, y=0, size=null, color=null)
	if color == null then color = [200, 200, 200, 255]
	if size == null then size = self.defaultSize
	rl.DrawTextEx self.get(size), s, [x, y], size, 0, color
end function

Font.width = function(s="M", fontSize)
	if fontSize == null then fontSize = self.defaultSize
	size = rl.MeasureTextEx(self.get(fontSize), s, fontSize, 0)
	return size.x
end function

Font.printCentered = function(s="", x=0, y=0, fontSize=null, color=null)
	w = self.width(s, fontSize)
	self.print s, x - w/2, y, fontSize, color
end function

//----------------------------------------------------------------------

// SourceFrame: a class that represents a portion of an image,
// and info about how this should be rendered into a framebuffer.
// All coordinates here are in SOURCE PIXELS, not logical (dest)
// units.  outset may be a single number applied to all four sides,
// or [hor, ver] values applied to horizontal and vertical sides, or
// [left, top, right, bottom] values supplied separately. Similarly,
// the hSides and vSides may be given as a single value, or a pair
// of values [left, right] or [top, bottom].
SourceFrame = {}
SourceFrame.image = null  // Raylib image
SourceFrame.srcR = null  // Rect describing source area in image
SourceFrame.outset = null // [left, top, right, bottom] in atlas pixels
SourceFrame.hType = STRETCH  // how to fill space horizontally
SourceFrame.vType = STRETCH  // how to fill space vertically
SourceFrame.hSides = null // [left, right] in atlas pixels
SourceFrame.vSides = null // [top, bottom] in atlas pixels
SourceFrame.imageScale = 1  // ratio of atlas pixels to logical points

SourceFrame.MakeFromResData = function(resMap, image, imageScale=1)
	noob = new self
	noob.image = image
	noob.imageScale = imageScale
	r = resMap.sourcePos
	noob.srcR = Rect.MakeLTWH(r[0], r[1], r[2], r[3])
	noob.hType = resMap.get("hType", noob.hType).upper
	noob.vType = resMap.get("vType", noob.vType).upper
	os = resMap.get("outset", 0)
	noob.outset = normalizeSides(os, 4)
	hs = resMap.get("hSides", 0)
	noob.hSides = normalizeSides(hs, 2)
	vs = resMap.get("vSides", 0)
	noob.vSides = normalizeSides(vs, 2)
	return noob
end function

SourceFrame.render = function(destR)
	// Draw our source frame to the given destination rect
	// (given in logical units, i.e. points).
	srcX = self.srcR.left; srcY = self.srcR.top
	srcW = self.srcR.width; srcH = self.srcR.height
	scale = self.imageScale

	// Start with the dest rect in logical points
	destX = destR.left; destY = destR.top
	destW = destR.width; destH = destR.height

	// Expand dest to account for outset (atlas pixels → logical points)
	os = self.outset
	if os then
		destX -= os[0] / scale
		destY -= os[1] / scale
		destW += (os[0] + os[2]) / scale
		destH += (os[1] + os[3]) / scale
	end if

	// Build horizontal strips: each is [srcX, srcW, destX, destW]
	if self.hType == STRETCH then
		hStrips = [[srcX, srcW, destX, destW]]
	else if self.hType == TILE then
		tileW = srcW / scale
		hStrips = []
		x = destX
		while x < destX + destW
			w = tileW
			sw = srcW
			if x + w > destX + destW then
				w = destX + destW - x
				sw = w * scale
			end if
			hStrips.push [srcX, sw, x, w]
			x += tileW
		end while
	else if self.hType == SLICE then
		leftSrcW = self.hSides[0]; rightSrcW = self.hSides[1]
		leftW = leftSrcW / scale; rightW = rightSrcW / scale
		midSrcW = srcW - leftSrcW - rightSrcW
		midDestW = destW - leftW - rightW
		if midDestW < 0 then midDestW = 0
		hStrips = []
		hStrips.push [srcX, leftSrcW, destX, leftW]
		if midDestW > 0 then
			hStrips.push [srcX + leftSrcW, midSrcW, destX + leftW, midDestW]
		end if
		hStrips.push [srcX + srcW - rightSrcW, rightSrcW, destX + destW - rightW, rightW]
	end if

	// Build vertical strips: each is [srcY, srcH, destY, destH]
	if self.vType == STRETCH then
		vStrips = [[srcY, srcH, destY, destH]]
	else if self.vType == TILE then
		tileH = srcH / scale
		vStrips = []
		y = destY
		while y < destY + destH
			h = tileH
			sh = srcH
			if y + h > destY + destH then
				h = destY + destH - y
				sh = h * scale
			end if
			vStrips.push [srcY, sh, y, h]
			y += tileH
		end while
	else if self.vType == SLICE then
		topSrcH = self.vSides[0]; bottomSrcH = self.vSides[1]
		topH = topSrcH / scale; bottomH = bottomSrcH / scale
		midSrcH = srcH - topSrcH - bottomSrcH
		midDestH = destH - topH - bottomH
		if midDestH < 0 then midDestH = 0
		vStrips = []
		vStrips.push [srcY, topSrcH, destY, topH]
		if midDestH > 0 then
			vStrips.push [srcY + topSrcH, midSrcH, destY + topH, midDestH]
		end if
		vStrips.push [srcY + srcH - bottomSrcH, bottomSrcH, destY + destH - bottomH, bottomH]
	end if

	// Draw each combination of horizontal and vertical strips
	for hs in hStrips
		for vs in vStrips
			srcRect = [hs[0], vs[0], hs[1], vs[1]]
			destRect = [hs[2], vs[2], hs[3], vs[3]]
			rl.DrawTexturePro self.image, srcRect, destRect, [0,0], 0, rl.WHITE
		end for
	end for
end function

//----------------------------------------------------------------------
// RenderContext: all the information a control needs to render itself;
// also includes a pipeline for handling events.
RenderContext = {}
// base (or "root") Rect that all control coordinates are relative to:
RenderContext.root = Rect.MakeLTWH(0, 0, 960, 640)
// all the SourceFrames in the resources file; map by name:
RenderContext.sourceFrames = null
// all the Fonts in the rources file; map by name:
RenderContext.fonts = null

RenderContext.MakeFromResData = function(data, dirPath)
	// Given a map of raw data, such as a parsed .grfon file,
	// build a new RenderContext with all resources loaded.
	rc = new RenderContext
	rc.title = data.title
	rc.atlasTex = rl.LoadTexture(file.child(dirPath, data.atlas))	
	qa.assert rc.atlasTex
	atlasScale = data.get("atlasScale", 1)

	rc.sourceFrames = {}
	for kv in data.images
		rc.sourceFrames[kv.key] = SourceFrame.MakeFromResData(
		  kv.value, rc.atlasTex, atlasScale)
	end for

	rc.fonts = {}
	for kv in data.fonts
		fileName = kv.value.name + ".ttf"
		fontPath = file.child(dirPath, fileName)
		if not file.exists(fontPath) then
			fontPath = file.child(file.parent(dirPath), fileName)
			qa.assert file.exists(fontPath)
		end if
		rc.fonts[kv.key] = Font.Load(fontPath, kv.value.size)
	end for

	return rc
end function

//----------------------------------------------------------------------
// Control: a standard Rect subclass that handles rendering and
// basic input events.
Control = new Rect
Control.name = "Control"
Control.sourceFrame = null
Control.Make = function(name, bounds)
	noob = new self
	if name then noob.name = name
	if bounds then noob.setLTWH(
	  bounds.left, bounds.bottom, bounds.width, bounds.height)
	return noob
end function

Control.render = function(context)
	// Subclasses must override this.
end function

Control.canCaptureMouse = function(context, xy)
	// Return 0 if you don't want to capture this click (e.g. 
	// because you can't, or it's well out of bounds); 0.5
	// if willing to capture but it doesn't seem ideal; or 1
	// if this is definitely a click for this control.
	if @self.captureMouse == null then return 0
	bounds = self.relativeTo(context.root)
	print "self y: " + self.top + " - " + self.bottom
	print "bounds y: " + bounds.top + " - " + bounds.bottom
	if bounds.contains(xy) then return 1
	bounds.outset 10 * rl.GetWindowScaleDPI.x
	if bounds.contains(xy) then return 0.5
	return 0
end function

Control.captureMouse = null

//----------------------------------------------------------------------


//----------------------------------------------------------------------
// PushButton: a control that the user can press to invoke some event.
// Comes in several styles (but for now, just the "main button" style,
// mostly used at the bottom of modal dialogs).
PushButton = new Control
PushButton.name = "PushButton"
PushButton.caption = "caption"
PushButton.trackingMouse = false

PushButton.render = function(context)
	destR = self.relativeTo(context.root)
	src = context.sourceFrames.ButtonMed
	if self.trackingMouse then
		if rl.IsMouseButtonReleased then
			self.trackingMouse = false
			print "destR y: " + destR.top + " - " + destR.bottom
		else if destR.contains(rl.GetMouseX, rl.GetMouseY) then
			src = context.sourceFrames.ButtonMedFlat
		end if
	end if
	src.render destR
	font = context.fonts.System
	font.printCentered self.caption, destR.centerX, destR.top+6,
			font.defaultSize, rl.WHITE
end function

PushButton.captureMouse = function
	self.trackingMouse = true
end function


//----------------------------------------------------------------------
// StaticText: a control that just displays a string of text.  It normally
// does not have any user interaction (except maybe supporting Copy if
// the user really wants to do that).
StaticText = new Control
StaticText.name = "StaticText"
StaticText.text = "Text goes here"
StaticText.font = "System"

//----------------------------------------------------------------------
// Spinner: a control that draws a spinning symbol indicating to the
// user that the computer is hard at work doing something (and we don't
// know how long it will take).  No user interaction.
Spinner = new Control
Spinner.name = "Spinner"
Spinner.render = function(context)
	destR = self.relativeTo(context.root)
	frameNum = floor(time * 16) % 8
	context.sourceFrames["Spinner_" + frameNum].render destR
end function

test = function
	rl.SetWindowTitle "Alchemy UI Test"

	dpiScale = rl.GetWindowScaleDPI
	print "DPI scale: " + dpiScale

	resPath = "assets/subdark/resources.grfon"
	rawData = file_readAll(resPath)
	if not rawData then
		print "Unable to read: " + resPath
		exit
	end if
	resData = grfon.parse(rawData)
	context = RenderContext.MakeFromResData(resData, "assets/subdark")

	// For testing purposes, let's draw the background over the whole window,
	// and then a single button, all at proper logical size.
	atlasTex = rl.LoadTexture("assets/subdark/" + resData.atlas)
	backgroundSrc = context.sourceFrames.DialogBG

	btn = PushButton.Make("HelloBtn", Rect.MakeLTWH(400-50, 500, 100, 32))
	btn.caption = "Hello!"
	
	spinner = Spinner.Make("Spinner", Rect.MakeLTWH(480, 500, 32, 32))

	controls = [btn, spinner]
	
	bgDestR = Rect.MakeLTWH(0, 0, 800, 600)
	captionFont = context.fonts.System

	while not rl.WindowShouldClose
		yield
		rl.SetWindowTitle rl.GetMouseX + ", " + rl.GetMouseY

		curScale = rl.GetWindowScaleDPI
		if curScale != dpiScale then
			print "DPI scale changed to: " + curScale
			dpiScale = curScale
		end if

		rl.BeginDrawing
		rl.ClearBackground rl.BLACK

		backgroundSrc.render context.root
		for ctl in controls
			ctl.render context
		end for

		if rl.IsMouseButtonPressed then
			mouse = {"x":rl.GetMouseX, "y":rl.GetMouseY}
			bestCtl = null
			bestScore = 0
			for ctl in controls
				score = ctl.canCaptureMouse(context, mouse)
				if score > bestScore then
					bestScore = score
					bestCtl = ctl
				end if
			end for
			if bestCtl then
				print "Capturing mouse: " + bestCtl.name
				bestCtl.captureMouse
			end if			
		end if
		
		rl.EndDrawing
	end while
end function

if locals == globals then test
