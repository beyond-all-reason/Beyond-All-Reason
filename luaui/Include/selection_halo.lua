-- A selected unit's mark on the ground: one mark, sleek, not a plate. A thin,
-- crisp ring held at a constant width on screen whatever the zoom, its edges feathered so it
-- reads as antialiased, broken into four arcs with small gaps; inside, only a whisper of the
-- colour. It follows the ground. Shared by the mission editor's world layer and the brush's UNITS
-- tool, so a selection looks the same wherever it is drawn, and is drawn once.
--
--     local Halo = VFS.Include("luaui/Include/selection_halo.lua")
--     Halo.draw(x, z, radius, { r, g, b }, strength)   -- inside a GL draw call-in

local Halo = {}

local spGetGroundHeight = Spring.GetGroundHeight
local glColor, glVertex, glBeginEnd = gl.Color, gl.Vertex, gl.BeginEnd
local TRIANGLE_STRIP = GL.TRIANGLE_STRIP

local LIFT = 3
-- The ring's width on screen, in pixels (at 1440 lines; scaled with the screen), and the
-- feather on each side of it.
local CORE_PX, FEATHER_PX = 1.6, 1.1
-- Four arcs: each spans this much of its quarter, the rest is the gap; turned by 45 degrees so
-- the gaps sit on the diagonals.
local ARC_FILL = 0.84
local ARC_STEPS = 10
local TURN = math.pi / 4

--- Elmos per screen pixel at a world point (the camera's distance and field of view).
local function elmosPerPixel(x, y, z)
	local cx, cy, cz = Spring.GetCameraPosition()
	local dx, dy, dz = x - cx, y - cy, z - cz
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	local _, vsy = Spring.GetViewGeometry()
	local fov = math.rad(Spring.GetCameraFOV and Spring.GetCameraFOV() or 45)
	return distance * 2 * math.tan(fov / 2) / math.max(1, vsy)
end

local function vertex(x, z, radius, angle, r, g, b, alpha)
	local px, pz = x + math.cos(angle) * radius, z + math.sin(angle) * radius
	glColor(r, g, b, alpha)
	glVertex(px, spGetGroundHeight(px, pz) + LIFT, pz)
end

--- A band between two radii along an arc, `alphaIn` at the inner edge and `alphaOut` at the
--- outer.
local function band(x, z, a0, a1, inner, outer, r, g, b, alphaIn, alphaOut)
	glBeginEnd(TRIANGLE_STRIP, function()
		for step = 0, ARC_STEPS do
			local angle = a0 + (a1 - a0) * step / ARC_STEPS
			vertex(x, z, inner, angle, r, g, b, alphaIn)
			vertex(x, z, outer, angle, r, g, b, alphaOut)
		end
	end)
end

--- The mark round (x, z). `radius` in elmos (the unit's footprint radius), `colour` an
--- { r, g, b } table, `strength` 0 to 1 (a hover is fainter than a selection), `fill` the
--- inside's alpha at the ring (default a whisper, 0.07 x strength; more says "a press here grabs
--- it").
function Halo.draw(x, z, radius, colour, strength, fill)
	strength = strength or 1
	fill = fill or 0.07 * strength
	local r, g, b = colour[1], colour[2], colour[3]
	local _, vsy = Spring.GetViewGeometry()
	local scale = math.max(1, vsy / 1440)
	local px = elmosPerPixel(x, spGetGroundHeight(x, z), z) * scale
	local core, feather = CORE_PX * px / 2, FEATHER_PX * px
	-- Never thicker than a fifth of the ring, however far the camera.
	core = math.min(core, radius * 0.1)
	feather = math.min(feather, radius * 0.1)
	-- A whisper of colour inside, fading in towards the ring.
	glBeginEnd(TRIANGLE_STRIP, function()
		for step = 0, 32 do
			local angle = step / 32 * math.pi * 2
			vertex(x, z, radius * 0.45, angle, r, g, b, 0)
			vertex(x, z, radius - core, angle, r, g, b, fill)
		end
	end)
	-- The ring: four arcs, a crisp core with a feather either side.
	local quarter = math.pi / 2
	local span = quarter * ARC_FILL
	for arc = 0, 3 do
		local a0 = TURN + arc * quarter + (quarter - span) / 2
		local a1 = a0 + span
		local alpha = 0.95 * strength
		band(x, z, a0, a1, radius - core - feather, radius - core, r, g, b, 0, alpha)
		band(x, z, a0, a1, radius - core, radius + core, r, g, b, alpha, alpha)
		band(x, z, a0, a1, radius + core, radius + core + feather, r, g, b, alpha, 0)
	end
end

--- The ring's radius for a unit, from its footprint in build squares: snug, not a plate.
function Halo.radiusOf(xsize, zsize)
	return math.max(tonumber(xsize) or 2, tonumber(zsize) or 2) * 8 * 0.62 + 4
end

return Halo
