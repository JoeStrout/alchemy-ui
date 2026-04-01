## Mar 28, 2026

The goal of this project is to build a layout system and UI toolkit (including a nice set of prebuilt controls) for use with raylib-miniscript, Soda, and Mini Micro.  This will include a GUI layout editor that lets you quickly build and test your UI (one window/screen at a time).  We'll also need an atlas/theme/resource editor (not sure quite what to call it yet), which lets you define the source images, constants, and sounds for a particular look & feel.

Though I might eventually have a Mini Micro version of the resource and layout editors, I'm going to do them in raylib-miniscript first, for a couple reasons:

- It can provide a larger window for working in;
- raylib-miniscript users are less likely to want to use Mini Micro than a Mini Micro user is likely to use an external tool.

Today I want to get some thoughts down on these tools.

### Resource Editor

This tool is primarily an atlas editor: it lets you define the rects within a big atlas image where all the various UI parts are found.  But it also lets you define some constant values (e.g. "hGap" and "vGap" for the standard gap between controls), and also some feedback sounds like "limit hit", "stretch", and "snap".

I'm picturing a menu bar at the top, a large scrollable image area taking up most of the window, and on the right, two panels: items and properties.  "Items" (or maybe "Resource Items" to be explicit) is mostly a list of all the rectangular areas in the image, though it might also include things like "Constants" and "Sounds".  The "Properties" panel is the properties of the selected item.  For the common image-area entries, this will include the left/top/width/height, as well as the resize mode: Stretch, Tile, or 9-Slice; and if it's 9-Slice, then the bounds of the stretched center area.  There are unlikely to be a lot of properties, in most cases, so maybe we stack the "Items" and "Properties" panels vertically.  We might also offer a "Preview" panel that stretches the given image so you can check that it's defined correctly (or in the case of a sound, lets you play the chosen sound).

Most of the items, constants, and sounds will have standard names that the Alchemy UI controls already use, and these will appear predefined in the resource editor.  If you haven't actually assigned them to anything, then they'll appear grayed out, but all you have to do is click on one and fill in its properties to add it to the definitions.  You can also add your own bespoke definitions (via a "+" button or menu command).

The resource definition will be saved as a GRFON file, referencing support files (i.e. the source image, fonts, and sounds) by file name.  Under the File menu, we'll have commands to Split and Combine the atlas to/from individual image files.

Ooh, and the resource editor should have an Edit/Test toggle; in Test mode, it makes a working UI with some built-in busy layout that exercises most or all of the standard controls.

OK, so what controls do we need to build the resource editor?
- Menu bar/menus
- Divider (horizontal and vertical, draggable)
- Listbox
- Edit Field (single-line)
- Static Text
- Buttons
- Toggle Switch

### Layout Editor

This looks similar to the atlas editor, but its job is to define a UI layout for use in your game.  The layout can be a window/dialog, or it could be the whole game screen.  This editor also edits GRFON files, but these define control types, positions, and properties.

The layout of this editor is similar to the resource editor, but includes an extra "Library" panel on the left side.  This contains all the standard Alchemy UI controls, as well as "Rect" for when you just want to define a rectangular area without any standard behavior.  And instead of "Items", the main content list is called "Controls" or "Layout Items" or some such.  At the top of this list is "Globals"; selecting that lets you define (under Properties) the resource file and any global values you need.  The rest of the items are rects or controls; selecting any of those highlights the corresponding item in the main view, and presents its properties in the Properties panel.

This editor will also have an Edit/Test toggle in the menu bar; in test mode, you can interact with your UI, and as you mouse over things, it highlights the corresponding item in the Items list.  We might also add a Test Log panel that logs messages from the test controls: button clicked, resized to WxH pixels, etc.

The controls we need for this editor are pretty much the same as what's needed for the resource editor.

### Development Plan

Neither editor is technically _needed_ to get a UI up and running; you can always hand-write the equivalent GRFON.  So, that's how we will bootstrap: we'll develop the needed controls one by one, and hand-write GRFON resource and layout files for our editors until they are advanced enough to edit themselves.

The Split/Join function will be important to have early, as I'll be starting with individual control images (probably made with ArtText), and need to join them into an atlas.

I purchased the Knobz UI set, which comes as PSDs that I can separate using [Photopea](https://www.photopea.com).  I could also get Affinity Photo again — I used to own that, but don't seem to have it installed now.

However I'm tempted to just make my own control set using ArtText2, which is easy and fun to use.  And then I can be sure to make everything consistent.  For inspiration, I'll use both Knobz and Graphic, which has a nice dark-themed, subtle UI.


## Mar 31, 2026

OK, I've prototyped a lot of things and now I'm starting to shape it into something like a usable library.

A key innovation (compared to past UI libraries I've made) is to separate out the definition of *how* to draw something (i.e. the source texture, UV coordinates, and details on how to stretch/slice/tile it) from information about *where* and *when* to draw it.  So the new alchemyUI file has a SourceFrame class that represents the former; it can load from a definition in a map, like we get from a GRFON file, and it can draw itself to any given destination rect.

All this is working great on my external monitor, but things are still not working properly when the app is launched on a Retina (high-DPI) display.  Imma switch back to the raylib-miniscript project and try to pin this down.

...OK, got it.  It turns out that the only way to make a Raylib window behave properly with HIGHDPI is to set FLAG_WINDOW_HIGHDPI _before_ calling InitWindow, which was not possible with the way raylib-miniscript worked before.  That's been fixed (scripts now call InitWindow themselves, when ready), and alchemyUI now has beautiful high-res images on a Retina display, and standard res on a standard display.  Note that you draw in standard coordinates in either case; Raylib takes care of almost all the details for you (though I imagine we'll have to load a font at double the desired resolution).

Added a Font class which transparently takes care of loading (and caching) the correct font size for a given point size and current DPI.  Works like a charm.  In the test app, both image data (background and button) and font rendering are now perfect on both high-DPI and standard-DPI screens.

