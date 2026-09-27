-- Where a placement drag puts its units: the layout half of the shared unit placer (refactor
-- plan, Phase U1), used by the mission editor and the terraform brush alike.
--
-- PURE. It knows nothing about missions, widgets or the engine: a unit type comes in as its
-- footprint (`xsize`, `zsize`, in footprint squares, as a UnitDef counts them) and positions
-- go out as numbers. What a consumer does with them -- write loadout records, spawn real units
-- -- is the consumer's business. Specs: spec/mission_editor/unit_placer_layout_spec.lua.
--
-- The rules are the engine's own (`CGuiHandler::GetBuildPositions`), the ones a player feels
-- every time they drag out a row of solars, as `luaui/Widgets/api_blueprint.lua` also ports
-- them. That widget keeps its versions file-local and works on blueprint objects, so this is a
-- plain-number port a placer can call and a spec can check; `api_blueprint` could adopt it.
--
--     local Layout = VFS.Include("luaui/Include/unit_placer/layout.lua")
--     local spots = Layout.positions({ xsize = 2, zsize = 2, mode = "GRID" }, x1, z1, x2, z2)

local Layout = {}

--- Elmos per footprint square, and per build square (the grid buildings snap to).
Layout.SQUARE_SIZE = 8
Layout.BUILD_SQUARE_SIZE = 16

--- The drag shapes, in the order a cycling control offers them.
Layout.MODES = { "SINGLE", "LINE", "SNAPLINE", "GRID", "BOX" }
local KNOWN_MODE = {}
for _, mode in ipairs(Layout.MODES) do
	KNOWN_MODE[mode] = true
end

--- The engine's facings: 0 south (+z), 1 east, 2 north, 3 west.
Layout.FACING_NAMES = { [0] = "S", "E", "N", "W" }

--- A facing as the Y rotation a model is drawn with: + pi/2 a quarter, as the Blueprint API
--- draws it (api_blueprint.lua: `unit.facing * (mathPi / 2)`). DrawUnitShapeGL4's own comment
--- says pi/2 points west; a +90 degree turn about Y takes +z to +x, which is east, and the
--- game's blueprints are drawn this way. The old minus sign mirrored every E/W ghost.
function Layout.facingRotation(facing)
	return ((tonumber(facing) or 0) % 4) * math.pi / 2
end

--- A footprint's width and depth in elmos, turned for its facing: an odd facing swaps the
--- axes, so a 3x5 building laid on its side occupies 5x3.
function Layout.footprint(xsize, zsize, facing)
	local w, h = Layout.SQUARE_SIZE * (tonumber(xsize) or 2), Layout.SQUARE_SIZE * (tonumber(zsize) or 2)
	if (tonumber(facing) or 0) % 2 == 1 then
		return h, w
	end
	return w, h
end

--- One axis snapped to the build grid for a footprint of `size` elmos. An odd number of
--- build squares centres on a cell, an even number on a grid line (api_blueprint's
--- snapAxisToBuildGrid, the engine's Pos2BuildPos rule).
function Layout.snapAxis(coord, size)
	local square, build = Layout.SQUARE_SIZE, Layout.BUILD_SQUARE_SIZE
	local half = (math.floor(size / build) % 2) * square
	return math.floor((coord + square - half) / build) * build + half
end

local function rotate(x, z, angle)
	if angle == 0 then
		return x, z
	end
	local c, s = math.cos(angle), math.sin(angle)
	return x * c - z * s, x * s + z * c
end

--- Every position a drag from (x1, z1) to (x2, z2) asks for.
---
--- `spec`:
--- - `xsize`, `zsize`: the unit's footprint in squares (UnitDef.xsize / zsize)
--- - `mode`: one of Layout.MODES (SINGLE when unknown)
--- - `facing`: 0-3, every unit's facing
--- - `spacing`: extra squares between footprints, each side (the engine's build spacing)
--- - `snap`: false to place off the build grid; anything else snaps
--- - `angle`: radians the LAYOUT is turned about the drag start. The units still face a
---   cardinal (`facing`): the runtime's loadout takes nothing else
--- - `mapX`, `mapZ`: when given, positions are kept on the map
---
--- Counts follow the engine: `floor((|delta| + size * 1.4) / size)` per axis, so a drag a
--- little over one footprint gives two units, as it does when a player builds.
---@return table spots array of { x, z, facing }
function Layout.positions(spec, x1, z1, x2, z2)
	spec = spec or {}
	local facing = (tonumber(spec.facing) or 0) % 4
	local mode = tostring(spec.mode or "SINGLE")
	if not KNOWN_MODE[mode] then
		mode = "SINGLE"
	end
	local angle = tonumber(spec.angle) or 0
	local snap = spec.snap ~= false
	local w, h = Layout.footprint(spec.xsize, spec.zsize, facing)
	local gap = Layout.SQUARE_SIZE * (tonumber(spec.spacing) or 0) * 2
	local sizeX, sizeZ = w + gap, h + gap

	x2, z2 = x2 or x1, z2 or z1
	-- The drag in the layout's own frame: turned back by the layout angle, so every shape is
	-- worked out axis-aligned and turned forward again at the end.
	local dx, dz = rotate(x2 - x1, z2 - z1, -angle)

	local numX = math.max(1, math.floor((math.abs(dx) + sizeX * 1.4) / sizeX))
	local numZ = math.max(1, math.floor((math.abs(dz) + sizeZ * 1.4) / sizeZ))
	local stepX = (dx >= 0) and sizeX or -sizeX
	local stepZ = (dz >= 0) and sizeZ or -sizeZ

	local local_ = {}
	local function put(lx, lz)
		local_[#local_ + 1] = { lx, lz }
	end

	if mode == "SINGLE" then
		put(0, 0)
	elseif mode == "LINE" or mode == "SNAPLINE" then
		local xDominates = math.abs(dx) > math.abs(dz)
		local n = xDominates and numX or numZ
		local sx, sz
		if xDominates then
			sx = stepX
			-- LINE follows the drag's slope; SNAPLINE keeps to the dominant axis.
			sz = (mode == "LINE" and dx ~= 0) and (stepX * dz / dx) or 0
		else
			sz = stepZ
			sx = (mode == "LINE" and dz ~= 0) and (stepZ * dx / dz) or 0
		end
		for i = 0, n - 1 do
			put(i * sx, i * sz)
		end
	elseif mode == "GRID" then
		-- Rows alternate direction, as the engine lays them, so the order the units come out
		-- in is the order a builder would walk.
		for j = 0, numZ - 1 do
			for k = 0, numX - 1 do
				local i = (j % 2 == 0) and k or (numX - 1 - k)
				put(i * stepX, j * stepZ)
			end
		end
	else -- BOX: the edge only, a perimeter or a wall
		if numX > 1 and numZ > 1 then
			for j = 1, numZ - 1 do
				put(0, j * stepZ)
			end
			for i = 1, numX - 1 do
				put(i * stepX, (numZ - 1) * stepZ)
			end
			for j = numZ - 2, 0, -1 do
				put((numX - 1) * stepX, j * stepZ)
			end
			for i = numX - 2, 0, -1 do
				put(i * stepX, 0)
			end
		elseif numX == 1 then
			for j = 0, numZ - 1 do
				put(0, j * stepZ)
			end
		else
			for i = 0, numX - 1 do
				put(i * stepX, 0)
			end
		end
	end

	local spots, seen = {}, {}
	for _, point in ipairs(local_) do
		local ox, oz = rotate(point[1], point[2], angle)
		local x, z = x1 + ox, z1 + oz
		if snap then
			x, z = Layout.snapAxis(x, w), Layout.snapAxis(z, h)
		end
		if spec.mapX and spec.mapZ then
			x = math.max(0, math.min(spec.mapX, x))
			z = math.max(0, math.min(spec.mapZ, z))
		end
		x, z = math.floor(x + 0.5), math.floor(z + 0.5)
		-- A turned layout snapped to the grid can put two spots in one cell; one unit there.
		local key = x .. ":" .. z
		if not seen[key] then
			seen[key] = true
			spots[#spots + 1] = { x = x, z = z, facing = facing }
		end
	end
	return spots
end

--- Turn an offset by quarter turns, the way a facing turns: one turn takes south (+z) to
--- east (+x).
function Layout.turnOffset(dx, dz, turns)
	for _ = 1, (tonumber(turns) or 0) % 4 do
		dx, dz = dz, -dx
	end
	return dx, dz
end

--- Where a GROUP lands (a paste or a blueprint, U8/U9): every unit at its offset from the
--- point, the whole group turned by quarter turns (offsets and facings together), each unit
--- snapped to the build grid for its own turned footprint.
---
--- `units`: { { dx, dz, facing, xsize, zsize }, ... } -- offsets from the group's centre.
---@return table spots array of { x, z, facing, index } (index into `units`)
function Layout.groupPositions(units, x, z, turns, snap, mapX, mapZ)
	local spots = {}
	for index, unit in ipairs(units or {}) do
		local ox, oz = Layout.turnOffset(tonumber(unit.dx) or 0, tonumber(unit.dz) or 0, turns)
		local facing = ((tonumber(unit.facing) or 0) + (tonumber(turns) or 0)) % 4
		local px, pz = x + ox, z + oz
		if snap ~= false then
			local w, h = Layout.footprint(unit.xsize, unit.zsize, facing)
			px, pz = Layout.snapAxis(px, w), Layout.snapAxis(pz, h)
		end
		if mapX and mapZ then
			px = math.max(0, math.min(mapX, px))
			pz = math.max(0, math.min(mapZ, pz))
		end
		spots[#spots + 1] = { x = math.floor(px + 0.5), z = math.floor(pz + 0.5), facing = facing, index = index }
	end
	return spots
end

--- The offsets of a set of placed units from their centre (the middle of their bounds),
--- which is what a copy or a blueprint stores.
---@param units table { { x, z, ... }, ... }
---@return table offsets { { dx, dz }, ... } in the same order
---@return number cx
---@return number cz
function Layout.centreOffsets(units)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, unit in ipairs(units or {}) do
		local x, z = tonumber(unit.x) or 0, tonumber(unit.z) or 0
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end
	if minX == math.huge then
		return {}, 0, 0
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local out = {}
	for index, unit in ipairs(units) do
		out[index] = { dx = (tonumber(unit.x) or 0) - cx, dz = (tonumber(unit.z) or 0) - cz }
	end
	return out, cx, cz
end

--- The next mode in Layout.MODES after `mode`, wrapping round.
function Layout.nextMode(mode)
	for index, candidate in ipairs(Layout.MODES) do
		if candidate == mode then
			return Layout.MODES[index % #Layout.MODES + 1]
		end
	end
	return Layout.MODES[1]
end

return Layout
