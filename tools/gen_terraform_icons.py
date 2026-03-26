"""Generate placeholder PNG icons for the terraform brush UI."""
import os
import math
from PIL import Image, ImageDraw

OUTDIR = os.path.join(os.path.dirname(__file__), "..", "luaui", "images", "terraform_brush")
os.makedirs(OUTDIR, exist_ok=True)

SIZE = 64
PAD = 10
CLR = (220, 220, 220, 255)
CLR2 = (255, 180, 50, 255)
BG = (0, 0, 0, 0)


def new():
	return Image.new("RGBA", (SIZE, SIZE), BG)


def save(img, name):
	img.save(os.path.join(OUTDIR, name + ".png"))
	print(f"  {name}.png")


# ── MODE ICONS ──

# Raise: up arrow
img = new()
d = ImageDraw.Draw(img)
cx, cy = SIZE // 2, SIZE // 2
d.polygon([(cx, PAD), (SIZE - PAD, SIZE - PAD), (PAD, SIZE - PAD)], outline=CLR, width=3)
d.line([(cx, PAD + 8), (cx, SIZE - PAD - 4)], fill=CLR, width=3)
save(img, "mode_raise")

# Lower: down arrow
img = new()
d = ImageDraw.Draw(img)
d.polygon([(PAD, PAD), (SIZE - PAD, PAD), (cx, SIZE - PAD)], outline=CLR, width=3)
d.line([(cx, PAD + 4), (cx, SIZE - PAD - 8)], fill=CLR, width=3)
save(img, "mode_lower")

# Level: three horizontal lines
img = new()
d = ImageDraw.Draw(img)
for i, y in enumerate([PAD + 8, cy, SIZE - PAD - 8]):
	d.line([(PAD, y), (SIZE - PAD, y)], fill=CLR, width=3)
save(img, "mode_level")

# Ramp: diagonal slope
img = new()
d = ImageDraw.Draw(img)
d.line([(PAD, SIZE - PAD), (SIZE - PAD, PAD)], fill=CLR2, width=3)
d.line([(PAD, SIZE - PAD), (SIZE - PAD, SIZE - PAD)], fill=CLR2, width=2)
d.line([(SIZE - PAD, SIZE - PAD), (SIZE - PAD, PAD)], fill=CLR2, width=2)
save(img, "mode_ramp")

# Restore: circular revert arrow (undo)
img = new()
d = ImageDraw.Draw(img)
arc_r = 18
arc_box_r = (cx - arc_r, cy - arc_r, cx + arc_r, cy + arc_r)
d.arc(arc_box_r, 30, 330, fill=(170, 100, 220, 255), width=3)
# arrowhead at 330 degrees (top-right area)
ax = cx + int(arc_r * math.cos(math.radians(330)))
ay = cy + int(arc_r * math.sin(math.radians(330)))
d.polygon([(ax, ay), (ax - 9, ay - 2), (ax - 3, ay + 8)], fill=(170, 100, 220, 255))
save(img, "mode_restore")

# ── SHAPE ICONS ──

# Circle
img = new()
d = ImageDraw.Draw(img)
d.ellipse([(PAD, PAD), (SIZE - PAD, SIZE - PAD)], outline=CLR, width=3)
save(img, "shape_circle")

# Square
img = new()
d = ImageDraw.Draw(img)
d.rectangle([(PAD, PAD), (SIZE - PAD - 1, SIZE - PAD - 1)], outline=CLR, width=3)
save(img, "shape_square")

# Ring (two concentric circles)
img = new()
d = ImageDraw.Draw(img)
d.ellipse([(PAD, PAD), (SIZE - PAD, SIZE - PAD)], outline=CLR, width=3)
inner = 14
d.ellipse([(PAD + inner, PAD + inner), (SIZE - PAD - inner, SIZE - PAD - inner)], outline=CLR, width=2)
save(img, "shape_ring")

# ── ROTATION ICONS ──

# Rotate CCW: curved arrow left
img = new()
d = ImageDraw.Draw(img)
arc_box = (PAD + 4, PAD + 4, SIZE - PAD - 4, SIZE - PAD - 4)
d.arc(arc_box, 200, 340, fill=CLR, width=3)
# arrowhead at start of arc (200 degrees)
ax = cx + int(20 * math.cos(math.radians(200)))
ay = cy + int(20 * math.sin(math.radians(200)))
d.polygon([(ax, ay), (ax + 8, ay - 6), (ax + 2, ay + 8)], fill=CLR)
save(img, "rot_ccw")

# Rotate CW: curved arrow right
img = new()
d = ImageDraw.Draw(img)
d.arc(arc_box, 200, 340, fill=CLR, width=3)
# arrowhead at end (340 degrees)
ax = cx + int(20 * math.cos(math.radians(340)))
ay = cy + int(20 * math.sin(math.radians(340)))
d.polygon([(ax, ay), (ax - 8, ay - 6), (ax - 2, ay + 8)], fill=CLR)
save(img, "rot_cw")

# ── CURVE ICONS ──

# Curve flat (wide parabola)
img = new()
d = ImageDraw.Draw(img)
pts = []
for i in range(SIZE - 2 * PAD):
	x = PAD + i
	t = (i / (SIZE - 2 * PAD - 1)) * 2 - 1  # -1 to 1
	y = SIZE - PAD - int((1 - t * t) ** 0.5 * (SIZE - 2 * PAD - 10))
	pts.append((x, y))
d.line(pts, fill=CLR, width=3)
save(img, "curve_flat")

# Curve sharp (steep peak)
img = new()
d = ImageDraw.Draw(img)
pts = []
for i in range(SIZE - 2 * PAD):
	x = PAD + i
	t = (i / (SIZE - 2 * PAD - 1)) * 2 - 1
	y = SIZE - PAD - int((1 - t * t) ** 3 * (SIZE - 2 * PAD - 10))
	pts.append((x, y))
d.line(pts, fill=CLR, width=3)
save(img, "curve_sharp")

# ── HEIGHT CAP ICONS ──

# Cap max (ceiling line with arrow down)
img = new()
d = ImageDraw.Draw(img)
d.line([(PAD, PAD + 6), (SIZE - PAD, PAD + 6)], fill=CLR2, width=3)
d.line([(cx, PAD + 12), (cx, SIZE - PAD)], fill=CLR, width=2)
d.polygon([(cx, SIZE - PAD), (cx - 6, SIZE - PAD - 10), (cx + 6, SIZE - PAD - 10)], fill=CLR)
save(img, "cap_max")

# Cap min (floor line with arrow up)
img = new()
d = ImageDraw.Draw(img)
d.line([(PAD, SIZE - PAD - 6), (SIZE - PAD, SIZE - PAD - 6)], fill=CLR2, width=3)
d.line([(cx, PAD), (cx, SIZE - PAD - 12)], fill=CLR, width=2)
d.polygon([(cx, PAD), (cx - 6, PAD + 10), (cx + 6, PAD + 10)], fill=CLR)
save(img, "cap_min")

# Plus
img = new()
d = ImageDraw.Draw(img)
d.line([(cx, PAD + 6), (cx, SIZE - PAD - 6)], fill=CLR, width=4)
d.line([(PAD + 6, cy), (SIZE - PAD - 6, cy)], fill=CLR, width=4)
save(img, "plus")

# Minus
img = new()
d = ImageDraw.Draw(img)
d.line([(PAD + 6, cy), (SIZE - PAD - 6, cy)], fill=CLR, width=4)
save(img, "minus")

print("Done! Generated all icons.")
