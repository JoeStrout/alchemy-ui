// layoutTest.ms — Visual test of the layout engine using raylib.
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

// Manual resize handling (instead of rl.FLAG_WINDOW_RESIZABLE,
// which blocks the main loop during resize on most platforms)
gripSize = 16
resizing = false
resizeOffsetX = 0
resizeOffsetY = 0
minWidth = 200
minHeight = 150

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

// Set up layout

lay = new layout.Layout
lay.init

root = lay.newBox("root")
root.specs.left = 0
root.specs.top = 0
root.specs.width = rl.GetScreenWidth
root.specs.height = rl.GetScreenHeight

// Read the layout from a GRFON file
data = grfon.parse(file.readText("assets/emailForm.grfon"))
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

lay.resolve

drawBox = function(box)
	if box.fullName == "root" then return
	c = box.specs.get("color", "#464650")
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

adjustLayout = function(force = false)
	w = rl.GetScreenWidth; h = rl.GetScreenHeight
	if w == root.specs.width and h == root.specs.height and not force then return
	root.specs.width = w
	root.specs.height = h
	lay.resolve
	rl.SetWindowTitle "emailForm Demo (" + w + " x " + h + ")"
end function
adjustLayout true

drawResizeGrip = function
	w = rl.GetScreenWidth; h = rl.GetScreenHeight
	gripColor = [150, 150, 150, 100]
	for i in range(0, 2)
		offset = 4 + i * 5
		rl.DrawLine w - offset, h - 1, w - 1, h - offset, "#88888888"
	end for
end function

while not rl.WindowShouldClose
	yield

	// Start resize grab when mouse pressed in bottom-right grip zone
	mouse = rl.GetMousePosition
	mouse.x = floor(mouse.x); mouse.y = floor(mouse.y)
	w = rl.GetScreenWidth; h = rl.GetScreenHeight
	if rl.IsMouseButtonPressed(0) then
		if mouse.x >= w - gripSize and mouse.y >= h - gripSize then
			resizing = true
			resizeOffsetX = w - mouse.x
			resizeOffsetY = h - mouse.y
		end if
	end if

	// End resize grab on mouse release
	if resizing and rl.IsMouseButtonReleased(0) then
		resizing = false
	end if

	// While resizing, update window size each frame
	if resizing then
		newW = floor(mouse.x + resizeOffsetX)
		newH = floor(mouse.y + resizeOffsetY)
		if newW < minWidth then newW = minWidth
		if newH < minHeight then newH = minHeight
		if newW != w or newH != h then
			// Resize the window.
			rl.SetWindowSize newW, newH
			// Unfortunately, GLFW will still often show one frame of the 
			// old layout, streched to fit the new window size, despite
			// us immediately drawing with the new layout (below).  This
			// results in some (currently unavoidable) wiggle in the UI
			// while resizing.
		end if
	end if

	// Re-resolve layout if window size changed
	adjustLayout

	// Render
	rl.BeginDrawing
	rl.ClearBackground [30, 30, 40, 255]
	for box in lay.boxes.values
		drawBox box
	end for

	drawResizeGrip

	boxUnderMouse = lay.boxHit(mouse)
	if boxUnderMouse then
		rl.DrawTextEx smallFont, boxUnderMouse.fullName, [4, rl.GetScreenHeight-18], 
		   18, 0, "#808080"
	end if

	rl.DrawFPS 4, 4
	rl.EndDrawing
end while

