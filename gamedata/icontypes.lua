-- Inherit base Beyond All Reason icontypes and register custom proportional Zombie Defense minimap icons.
-- All custom zdef_* icons set radiusadjust = 0 so the engine does NOT multiply icon size by 3D model bounding radius,
-- preventing aircraft, tanks, and HQ from turning into giant opaque blobs on the minimap.
-- Large units use a compact center core pip (size = 0.42) in the engine pass while gui_zombie_defense_hud.lua's
-- DrawInMiniMap(sx, sy) renders true OpenGL alpha-blended semi-transparent circles with crisp borders around them.

local icontypes = {
	default = {
		bitmap = "icons/zdef_dot_infantry.png",
		size = 0.65,
		radiusadjust = 0,
		distance = 1.0,
		drawOrder = 1,
	},
}

-- Small Units: Compact, crisp dots so swarms of 300+ zombies and rifle squads remain clear and distinct
icontypes.zdef_walker = {
	bitmap = "icons/zdef_dot_walker.png",
	size = 0.56,
	radiusadjust = 0,
	distance = 0.85,
}

icontypes.zdef_zombie_med = {
	bitmap = "icons/zdef_dot_zombie_med.png",
	size = 0.68,
	radiusadjust = 0,
	distance = 0.90,
}

icontypes.zdef_infantry = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.72,
	radiusadjust = 0,
	distance = 0.90,
}

icontypes.zdef_paratrooper = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.76,
	radiusadjust = 0,
	distance = 0.90,
}

-- Large Units: Compact center core pip in engine pass + true alpha-blended semi-transparent circle with border in DrawInMiniMap
icontypes.zdef_brute = {
	bitmap = "icons/zdef_dot_zombie_med.png",
	size = 0.44,
	radiusadjust = 0,
	distance = 1.05,
}

icontypes.zdef_mrap = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.44,
	radiusadjust = 0,
	distance = 1.05,
}

icontypes.zdef_tank = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.48,
	radiusadjust = 0,
	distance = 1.15,
}

icontypes.zdef_a10 = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.44,
	radiusadjust = 0,
	distance = 1.20,
}

icontypes.zdef_c130 = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.48,
	radiusadjust = 0,
	distance = 1.25,
}

icontypes.zdef_hq = {
	bitmap = "icons/zdef_dot_infantry.png",
	size = 0.52,
	radiusadjust = 0,
	distance = 1.35,
}

return icontypes
