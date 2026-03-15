// prefsDialog.ms — Demonstrates drawing a virtual window within a
// fixed-size raylib window, with the layout from prefsDialog.grfon.
// Run this script with raylib-miniscript, set up so that it can
// import the library scripts below.

rl = raylib
rl.SetTraceLogLevel rl.LOG_WARNING

// Standard MiniScript libs:
import "mapUtil"
import "grfon"

// Alchemy Layout libs:
import "layout"
import "eval"

font = rl.LoadFontEx("assets/DejaVuSans.ttf", 24, null, 0)
smallFont = rl.LoadFontEx("assets/DejaVuSans.ttf", 18, null, 0)

// The file class really should have this:
file.readText = function(path)
	f = file.open(path)
	if f == null then return null
	result = f.read
	f.close
	return result
end function

// Fixed outer window
outerW = 1024
outerH = 768
rl.SetWindowSize outerW, outerH
rl.SetWindowTitle "Prefs Dialog Demo"

// Virtual window state
titleBarH = 28
winX = 200
winY = 100
winW = 500
winH = 450
minWidth = 300
minHeight = 200
gripSize = 16
dragging = false
dragOffsetX = 0
dragOffsetY = 0
resizing = false
resizeOffsetX = 0
resizeOffsetY = 0

// Set up layout
lay = new layout.Layout
lay.init

root = lay.newBox("root")
root.specs.left = 0
root.specs.top = 0
root.specs.width = winW
root.specs.height = winH - titleBarH

// Read the layout from a GRFON file
data = grfon.parse(file.readText("assets/prefsDialog.grfon"))
for kv in data
	if kv.value isa map then
		// Define a new box!
		spec = kv.value
		parentName = spec.get("parent", "root")
		parent = lay.boxByName.get(parentName)
		if parent == null then
			print "ERROR: undefined parent " + parentName + " in " + kv.key
			exit
		end if
		box = lay.newBox(kv.key, parent)
		for spkv in spec
			box.specs[spkv.key] = spkv.value
		end for
		print box.name + ": " + box.specs
	else
		value = kv.value
		if value isa string then value = eval.eval(value)
		lay.constants[kv.key] = value
		print "constant " + kv.key + ": " + lay.constants[kv.key]
	end if
end for

resolveLayout = function
	// Position root at the virtual window's content area
	root.specs.left = winX
	root.specs.top = winY + titleBarH
	root.specs.width = winW
	root.specs.height = winH - titleBarH
	// Root is special -- we need to manually copy those properties (for now)
	root.left = root.specs.left; root.top = root.specs.top
	root.width = root.specs.width; root.height = root.specs.height
	// Then, resolve the layout
	lay.resolve
end function

resolveLayout

drawBox = function(box)
	if box.fullName == "root" then return
	c = box.specs.get("color", "#46465088")
	rl.DrawRectangle box.left, box.top, box.width, box.height, c
	rl.DrawRectangleLines box.left, box.top, box.width, box.height, [200, 200, 200, 100]
	text = box.specs.get("text")
	if text then
		if box.fullName == "title" then
			f = font
			fontSize = 24
		else
			f = smallFont
			fontSize = 18
		end if
		size = rl.MeasureTextEx(f, text, fontSize, 0)
		tx = box.left + floor((box.width - size.x) / 2)
		ty = box.top + floor((box.height - size.y) / 2)
		rl.DrawTextEx f, text, [tx, ty], fontSize, 0, rl.WHITE
	else
		rl.DrawTextEx font, box.fullName, [box.left + 4, box.top + 2], 12, 0, "#808080"
	end if
end function

drawVirtualWindow = function
	// Title bar
	rl.DrawRectangle winX, winY, winW, titleBarH, "#505070"
	rl.DrawRectangleLines winX, winY, winW, titleBarH, "#8080A0"
	titleText = "Preferences"
	tSize = rl.MeasureTextEx(smallFont, titleText, 18, 0)
	tx = winX + floor((winW - tSize.x) / 2)
	ty = winY + floor((titleBarH - tSize.y) / 2)
	rl.DrawTextEx smallFont, titleText, [tx, ty], 18, 0, rl.WHITE

	// Content area background
	rl.DrawRectangle winX, winY + titleBarH, winW, winH - titleBarH, "#38384A"

	// Draw all layout boxes
	for box in lay.boxes.values
		drawBox box
	end for

	// Window border
	rl.DrawRectangleLines winX, winY, winW, winH, "#8080A0"

	// Resize grip (bottom-right corner of virtual window)
	for i in range(0, 2)
		offset = 4 + i * 5
		rl.DrawLine winX + winW - offset, winY + winH - 1, winX + winW - 1, winY + winH - offset, "#88888888"
	end for
end function

while not rl.WindowShouldClose
	yield

	mouse = rl.GetMousePosition
	mouse.x = floor(mouse.x); mouse.y = floor(mouse.y)

	if rl.IsMouseButtonPressed(0) then
		// Check resize grip first (bottom-right of virtual window)
		gripLeft = winX + winW - gripSize
		gripTop = winY + winH - gripSize
		if mouse.x >= gripLeft and mouse.y >= gripTop and mouse.x < winX + winW and mouse.y < winY + winH then
			resizing = true
			resizeOffsetX = (winX + winW) - mouse.x
			resizeOffsetY = (winY + winH) - mouse.y
		else if mouse.x >= winX and mouse.x < winX + winW and mouse.y >= winY and mouse.y < winY + titleBarH then
			// Title bar drag
			dragging = true
			dragOffsetX = winX - mouse.x
			dragOffsetY = winY - mouse.y
		end if
	end if

	if rl.IsMouseButtonReleased(0) then
		dragging = false
		resizing = false
	end if

	needsResolve = false

	if dragging then
		winX = mouse.x + dragOffsetX
		winY = mouse.y + dragOffsetY
		needsResolve = true
	end if

	if resizing then
		newW = mouse.x + resizeOffsetX - winX
		newH = mouse.y + resizeOffsetY - winY
		if newW < minWidth then newW = minWidth
		if newH < minHeight then newH = minHeight
		if newW != winW or newH != winH then
			winW = newW
			winH = newH
			needsResolve = true
		end if
	end if

	if needsResolve then resolveLayout

	// Render
	rl.BeginDrawing
	rl.ClearBackground "#2A2A5A"

	drawVirtualWindow

	boxUnderMouse = lay.boxHit(mouse)
	if boxUnderMouse and boxUnderMouse.fullName != "root" then
		rl.DrawTextEx smallFont, boxUnderMouse.fullName, [4, outerH - 18],
		   18, 0, "#808080"
	end if

	rl.DrawFPS 4, 4
	rl.EndDrawing
end while
