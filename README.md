# alchemy-ui
formula-based UI layout system, with widget classes for several MiniScript environments

## Overview

This project is developing a UI toolkit for use in [Mini Micro](https://miniscript.org/MiniMicro), [Soda](https://github.com/JoeStrout/soda), and [raylib-miniscript](https://github.com/JoeStrout/raylib-miniscript).

One of the hardest parts of any UI system is specifying the layout.  Alchemy UI uses a _formula-based_ layout system.  The basic idea is this:

- Horizontally, you specify **any two** of `left`, `right`, `center`, and `width`.
- Vertically, you specify **any two** of `top`, `bottom`, `middle`, and `height`.
- Those specifications can be simple pixel values (relative to the parent), or they can be spreadsheet-style formulas, like `SomeOtherControl.right + gap` or `parent.width * 0.25`.

This lets you make a responsive UI in a very straightforward manner, matching how you probably think about your layout already.  No complex system of anchors and pivots, no CSS-style hierarchy of margins and padding and modes; just simple values and formulas.

## Control Kit

The other hard part of any UI system is defining a set of built-in controls that make all the easy cases easy, while still allowing you the freedom to handle the weird cases.  We're still in the early stages of the design here, but it's likely to include at least:

- Image panel
- StaticText
- Button
- Scrollbar (horizontal and vertical)
- Slider
- Checkbox
- Radio Button
- Popup Menu
- Text Field (single-line or multi-line)
- Separator
- Group Box
- Canvas (for arbitrary drawing or simple custom controls)
- Tab Panel
- Divider (draggable)
- Switch

## Status

This project is just getting under way.  Giving it a star ⭐️ at the top of this page makes it go faster!


