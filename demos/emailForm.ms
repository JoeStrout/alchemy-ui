// layoutTest.ms — Visual test of the layout engine using raylib.
// Run this script with raylib-miniscript, set up so that it can
// import the library scripts below.

// Standard MiniScript libs:
import "mapUtil"
import "grfon"

// Alchemy Layout libs:
import "layout"
import "eval"

rl = raylib
rl.SetTraceLogLevel rl.LOG_WARNING
rl.SetWindowState 4 // rl.FLAG_WINDOW_RESIZABLE

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
		parent = lay.boxes.get(parentName)
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

while not rl.WindowShouldClose
	// Re-resolve if window resized
	w = rl.GetScreenWidth; h = rl.GetScreenHeight
	if w != root.specs.width or h != root.specs.height then
		// update layout with new window size
		root.specs.width = w
		root.specs.height = h
		lay.resolve
	end if

	rl.BeginDrawing
	rl.ClearBackground [30, 30, 40, 255]
	for box in lay.boxes.values
		drawBox box
	end for
	rl.DrawFPS 4, 4
	rl.EndDrawing
	yield
end while

rl.CloseWindow
