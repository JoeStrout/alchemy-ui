// Layout Engine
//
// Resolves a hierarchy of.boxByName with formula-based positioning.
// Each box specifies exactly 2 horizontal (left/right/center/width)
// and 2 vertical (top/bottom/middle/height) constraints, which may
// be numbers or formulas referencing other.boxByName' properties.

import "eval"
import "listUtil"

// --- Box prototype ---
Box = {}
Box.name = ""
Box.index = null
Box.fullName = ""
Box.parent = null
Box.children = null
Box.specs = null
Box.left = null
Box.width = null
Box.top = null
Box.height = null

Box.right = function; return self.left + self.width; end function
Box.bottom = function; return self.top + self.height; end function
Box.center = function; return self.left + self.width/2; end function
Box.middle = function; return self.top + self.height/2; end function

Box.contains = function(point)
	return self.left <= point.x < self.right and
	       self.top <= point.y < self.bottom
end function

// --- Layout engine ---
Layout = {}
Layout.root = null
Layout.boxByName = null  // key: name; value: Box
Layout.boxes = null      // list of boxes, in creation order
Layout.constants = null  // key: identifier; value: numeric value

Layout.init = function
	self.boxByName = {}
	self.boxes = []
	self.constants = {}
	return self
end function

Layout.newBox = function(name, parent, index)
	box = new Box
	box.name = name
	box.index = index
	if index != null then
		box.fullName = name + "[" + index + "]"
	else
		box.fullName = name
	end if
	box.children = []
	box.specs = {}
	box.left = null
	box.width = null
	box.top = null
	box.height = null
	if parent == null then
		self.root = box
	else
		parent.children.push box
		box.parent = parent
	end if
	self.boxByName[box.fullName] = box
	self.boxes.push box
	return box
end function

Layout.boxHit = function(point)
	// iterate.boxByName backwards, on the assumption that the later
	//.boxByName are the ones more "on top"
	for i in range(self.boxes.len-1, 0, -1)
		if self.boxes[i].contains(point) then return self.boxes[i]
	end for
	return null
end function

// Replace self/parent/root prefixes in a formula with actual box names.
Layout.preprocess = function(formula, box)
	if formula isa number then return formula
	tokens = eval.lex(formula)
	for i in tokens.indexes
		tok = tokens[i]
		dotPos = tok.indexOf(".")
		if dotPos == null then continue
		prefix = tok[:dotPos]
		suffix = tok[dotPos:]
		if prefix == "self" then
			tokens[i] = box.fullName + suffix
		else if prefix == "parent" and box.parent != null then
			tokens[i] = box.parent.fullName + suffix
		else if prefix == "root" and self.root != null then
			tokens[i] = self.root.fullName + suffix
		end if
	end for
	return tokens.join(" ")
end function

// Check if all identifiers in a formula are available in eval.variables.
Layout.canEval = function(formula)
	if formula isa number then return true
	tokens = eval.lex(formula)
	for tok in tokens
		c = tok[0]
		if c >= "0" and c <= "9" then continue
		if "+-*/^()=".indexOf(c) != null then continue
		if eval.variables.hasIndex(tok) then continue
		if eval.lookupFunc(tok) != null then continue
		return false
	end for
	return true
end function

// Derive left and width from whichever two horizontal properties are known.
Layout.deriveH = function(box)
	L = box.left; W = box.width; R = box.right; C = box.center
	count = (L != null) + (W != null) + (R != null) + (C != null)
	if count < 2 then return false
	if L != null and W != null then
		// already have what we need; just publish derived
	else if L != null and R != null then
		W = R - L
	else if L != null and C != null then
		W = (C - L) * 2
	else if W != null and R != null then
		L = R - W
	else if W != null and C != null then
		L = C - W / 2
	else if R != null and C != null then
		W = (R - C) * 2
		L = R - W
	end if
	if L == null or W == null then return false
	changed = false
	if box.left == null then
		box.left = L
		changed = true
	end if
	if box.width == null then
		box.width = W
		changed = true
	end if
	return changed
end function

// Derive top and height from whichever two vertical properties are known.
Layout.deriveV = function(box)
	T = box.top; H = box.height; B = box.bottom; M = box.middle
	count = (T != null) + (H != null) + (B != null) + (M != null)
	if count < 2 then return false
	if T != null and H != null then
		// already have what we need; just publish derived
	else if T != null and B != null then
		H = B - T
	else if T != null and M != null then
		H = (M - T) * 2
	else if H != null and B != null then
		T = B - H
	else if H != null and M != null then
		T = M - H / 2
	else if B != null and M != null then
		H = (B - M) * 2
		T = B - H
	end if
	if T == null or H == null then return false
	changed = false
	if box.top == null then 
		box.top = T
		changed = true
	end if
	if box.height == null then
		box.height = H
		changed = true
	end if
	return changed
end function

// Extract dependency node keys from a formula for a given box.
// Each dotted ref like "field.left" maps to a derive node ("field:H" or "field:V").
Layout.extractDeps = function(formula, box)
	if formula isa number then return []
	processed = self.preprocess(formula, box)
	tokens = eval.lex(processed)
	deps = []
	seen = {}
	for tok in tokens
		dotPos = tok.indexOf(".")
		if dotPos == null then continue
		c = tok[0]
		if c >= "0" and c <= "9" then continue
		boxName = tok[:dotPos]
		prop = tok[dotPos+1:]
		// If the referenced property is directly specified as a spec,
		// depend on that spec node.  Otherwise depend on the derive node.
		if self.boxByName.hasIndex(boxName) and self.boxByName[boxName].specs.hasIndex(prop) then
			depKey = boxName + ":" + prop
		else if prop == "left" or prop == "width" or prop == "right" or prop == "center" then
			depKey = boxName + ":H"
		else
			depKey = boxName + ":V"
		end if
		if not seen.hasIndex(depKey) then
			deps.push depKey
			seen[depKey] = true
		end if
	end for
	return deps
end function

// Resolve all box positions via topological sort.
Layout.resolve = function
	// Set up eval lookupFunc
	eval.variables = {}
	layout = self
	eval.lookupFunc = function(ident)
		if layout.constants.hasIndex(ident) then return layout.constants[ident]

		dotPos = ident.indexOf(".")
		if dotPos == null then return null
		boxName = ident[:dotPos]
		prop = ident[dotPos+1:]
		if not layout.boxByName.hasIndex(boxName) then return null
		box = layout.boxByName[boxName]
		if prop == "left" then return box.left
		if prop == "width" then return box.width
		if prop == "top" then return box.top
		if prop == "height" then return box.height
		if prop == "right" then return box.right
		if prop == "bottom" then return box.bottom
		if prop == "center" then return box.center
		if prop == "middle" then return box.middle
		return null
	end function

	// Reset box properties
	for box in self.boxes
		specs = box.specs
		for prop in ["left", "width", "top", "height", "right", "bottom", "center", "middle"]
			if not specs.hasIndex(prop) or not eval.isNumber(specs[prop]) then
				box.remove prop
			else
				box[prop] = specs[prop]
			end if
		end for
	end for

	// Build dependency graph
	// Nodes: "box:prop" for each spec, "box:H" and "box:V" for derivation steps
	nodes = {}
	for box in self.boxes
		fn = box.fullName
		hSpecKeys = []
		vSpecKeys = []
		for prop in box.specs.indexes
			nodeKey = fn + ":" + prop
			deps = self.extractDeps(box.specs[prop], box)
			nodes[nodeKey] = {"deps": deps, "box": box, "prop": prop}
			if prop == "left" or prop == "width" or prop == "right" or prop == "center" then
				hSpecKeys.push nodeKey
			else
				vSpecKeys.push nodeKey
			end if
		end for
		nodes[fn + ":H"] = {"deps": hSpecKeys, "box": box, "prop": "deriveH"}
		nodes[fn + ":V"] = {"deps": vSpecKeys, "box": box, "prop": "deriveV"}
	end for

	// Topological sort (DFS post-order)
	order = []
	state = {}  // key -> 1 (visiting) or 2 (visited)
	cycleError = null
	visit = function(key)
		if not nodes.hasIndex(key) then return
		if state.hasIndex(key) then
			if state[key] == 1 then outer.cycleError = key
			return
		end if
		state[key] = 1
		for dep in nodes[key].deps
			outer.visit(dep)
			if outer.cycleError then return
		end for
		state[key] = 2
		order.push key
	end function
	for key in nodes.indexes
		visit key
		if cycleError then
			print "ERROR: Circular dependency at " + cycleError
			return false
		end if
	end for

	// Evaluate in topological order
	for key in order
		node = nodes[key]
		if node.prop == "deriveH" then
			self.deriveH node.box
		else if node.prop == "deriveV" then
			self.deriveV node.box
		else
			spec = node.box.specs[node.prop]
			if spec isa number then
				node.box[node.prop] = spec
			else
				processed = self.preprocess(spec, node.box)
				node.box[node.prop] = eval.eval(processed)
			end if
		end if
	end for

	// Check for unresolved properties
	errors = []
	for box in self.boxes
		for prop in ["left", "width", "top", "height"]
			if box[prop] == null then errors.push box.fullName + "." + prop
		end for
	end for
	if errors.len > 0 then
		print "ERROR: Could not resolve: " + errors.join(", ")
		return false
	end if
	return true
end function

Layout.printAll = function(box, indent)
	if box == null then box = self.root
	if indent == null then indent = ""
	fn = box.fullName
	print indent + fn + ": " +
	  "left=" + box.left + "  top=" + box.top +
	  "  width=" + box.width + "  height=" + box.height +
	  "  (right=" + box.right +
	  "  bottom=" + box.bottom + ")"
	for child in box.children
		self.printAll child, indent + "  "
	end for
end function

// --- Demo / Test ---
if locals == globals then
	layout = new Layout
	layout.init

	layout.constants.gap = 20
	layout.constants.fieldH = 30

	root = layout.newBox("root")
	root.specs.left = 0
	root.specs.top = 0
	root.specs.width = 800
	root.specs.height = 600

	field = layout.newBox("field", root)
	field.specs.left = 200
	field.specs.top = 50
	field.specs.width = 300
	field.specs.height = "fieldH"

	label = layout.newBox("label", root)
	label.specs.right = "field.left - gap"
	label.specs.top = "field.top"
	label.specs.width = 80
	label.specs.height = "field.height"

	okBtn = layout.newBox("okBtn", root)
	okBtn.specs.left = "parent.center/2 + gap/2"
	okBtn.specs.top = "field.bottom + gap"
	okBtn.specs.width = 100
	okBtn.specs.height = "fieldH"

	cancelBtn = layout.newBox("cancelBtn", root)
	cancelBtn.specs.right = "okBtn.left - gap"
	cancelBtn.specs.top = "okBtn.top"
	cancelBtn.specs.width = 100
	cancelBtn.specs.height = "fieldH"

	if layout.resolve then
		print "Layout resolved successfully:"
		layout.printAll
	end if
end if
