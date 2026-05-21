IceUI-GL4 icon folder
=====================

Drop command-menu icon images here (PNG recommended; DDS/TGA/JPG/BMP also work).

The IceUI-GL4 host widget scans this folder at startup and packs every image
into one shared texture atlas. The new commands menu then draws an icon on a
button when configs/iceui_ordermenu_icons.lua maps that command to a file here.

To add an icon:
  1. put the image in this folder, e.g.  move.png
  2. add a line in luaui/configs/iceui_ordermenu_icons.lua, e.g.  move = "move.png",
  3. restart BAR (newly added files need a VFS reindex)

Icons are tinted/blended over the button background. Square images with a
transparent background work best. Recommended size: 64x64 or 128x128.
