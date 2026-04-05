// This demo/test program draws images with various resize modes:
//	stretch: simply stretches the image across the full width/height
//	tile: repeats the image as many times as necessary to fill the space
//	slice: stretches a center portion, between two fixed side portions

rl = raylib
rl.SetTraceLogLevel rl.LOG_WARNING

import "grfon"
import "mapUtil"
import "stringUtil"
import "Rect"

readAll = function(path)
	f = file.open(path)
	if not f then
		print "Unable to open file: " + path
		exit
	end if
	result = f.read
	f.close
	return result
end function

resData = grfon.parse(readAll("assets/resources.grfon"))
print resData.images.DialogBG

rl.SetWindowSize 800, 600
rl.SetWindowTitle "Image Draw Test"

// Read the atlas image at resData.atlas (relative to assets folder)
atlas = rl.LoadTexture("assets/" + resData.atlas)
print "atlas: " + atlas

// Draw a sub-image from the atlas into a destination area,
// using the horizontal and vertical resize modes defined in imgData.
drawImage = function(imgData, destX, destY, destW, destH)
	sp = imgData.sourcePos
	srcX = sp[0]; srcY = sp[1]; srcW = sp[2]; srcH = sp[3]
	hType = imgData.get("hType", "stretch")
	vType = imgData.get("vType", "stretch")
	hSides = imgData.get("hSides")
	vSides = imgData.get("vSides")
	// Adjust for outset (extra space for shadow/glow effects).
	// Outset is [left, top, right, bottom]; the given dest rect
	// defines the content area, and we expand outward by the outset.
	outset = imgData.get("outset")
	if outset then
		destX -= outset[0]
		destY -= outset[1]
		destW += outset[0] + outset[2]
		destH += outset[1] + outset[3]
	end if

	// Build horizontal strips: each is [srcX, srcW, destX, destW]
	if hType == "stretch" then
		hStrips = [[srcX, srcW, destX, destW]]
	else if hType == "tile" then
		hStrips = []
		x = destX
		while x < destX + destW
			w = srcW
			if x + w > destX + destW then w = destX + destW - x
			hStrips.push [srcX, w, x, w]
			x += srcW
		end while
	else if hType == "slice" then
		leftW = hSides[0]; rightW = hSides[1]
		midSrcW = srcW - leftW - rightW
		midDestW = destW - leftW - rightW
		if midDestW < 0 then midDestW = 0
		hStrips = []
		hStrips.push [srcX, leftW, destX, leftW]
		if midDestW > 0 then
			hStrips.push [srcX + leftW, midSrcW, destX + leftW, midDestW]
		end if
		hStrips.push [srcX + srcW - rightW, rightW, destX + destW - rightW, rightW]
	end if

	// Build vertical strips: each is [srcY, srcH, destY, destH]
	if vType == "stretch" then
		vStrips = [[srcY, srcH, destY, destH]]
	else if vType == "tile" then
		vStrips = []
		y = destY
		while y < destY + destH
			h = srcH
			if y + h > destY + destH then h = destY + destH - y
			vStrips.push [srcY, h, y, h]
			y += srcH
		end while
	else if vType == "slice" then
		topH = vSides[0]; bottomH = vSides[1]
		midSrcH = srcH - topH - bottomH
		midDestH = destH - topH - bottomH
		if midDestH < 0 then midDestH = 0
		vStrips = []
		vStrips.push [srcY, topH, destY, topH]
		if midDestH > 0 then
			vStrips.push [srcY + topH, midSrcH, destY + topH, midDestH]
		end if
		vStrips.push [srcY + srcH - bottomH, bottomH, destY + destH - bottomH, bottomH]
	end if

	// Draw each combination of horizontal and vertical strips
	for hs in hStrips
		for vs in vStrips
			srcRect = [hs[0], vs[0], hs[1], vs[1]]
			destRect = [hs[2], vs[2], hs[3], vs[3]]
			rl.DrawTexturePro atlas, srcRect, destRect, [0,0], 0, rl.WHITE
		end for
	end for
end function

print @rl.DrawTexturePro
print @rl.DrawTexture
print @rl.DrawFPS

while not rl.WindowShouldClose
	rl.BeginDrawing
	rl.ClearBackground "#2AFAFA"

	// Draw a big ol' rectangle of that texture, stretching horizontally
	// but tiling vertically.
	drawImage resData.images.DialogBG, 10, 10, 600, 400
	
	// and now let's try some hemi-slice images
	drawImage resData.images.ScrollTrackH, 10, 410, 600, 108
	drawImage resData.images.ScrollTrackV, 610, 10, 108, 400

	// and a full 9-slice image
	drawImage resData.images.Button9Slice, 100, 100, 300, 200

	rl.DrawFPS 4, 4
	rl.EndDrawing
	yield
end while

exit

