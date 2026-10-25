-- Where a placement drag puts its units: the layout half of the shared unit placer (refactor
-- plan, Phase U1), used by the mission editor and the terraform brush alike.
--
-- PURE. It knows nothing about missions, widgets or the engine: a unit type comes in as its
-- footprint (`xsize`, `zsize`, in footprint squares, as a UnitDef counts them) and positions
-- go out as numbers. What a consumer does with them -- write loadout records, spawn real units
-- -- is the consumer's business. Specs: spec/luaui/Include/unit_placer_layout_spec.lua.
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

--- A formation for `count` units already placed (mission editor units S6): offsets from the
--- formation's centre, `cell` elmos apart. LINE stands abreast across the facing (a line
--- facing south runs east to west), GRID is as square as the count allows with a short last
--- rank centred, BOX spreads them evenly round a square ring (under four, a GRID). Nothing is
--- snapped: the caller snaps each unit for its own footprint.
---@return table offsets { { dx, dz }, ... }, `count` of them
function Layout.arrange(count, mode, cell, facing)
	count = math.max(0, math.floor(tonumber(count) or 0))
	cell = tonumber(cell) or 32
	local sideways = (math.floor(tonumber(facing) or 0) % 2) == 1
	local out = {}
	-- `a` along the rank, `b` along the file; an east or west facing turns both.
	local function put(a, b)
		if sideways then
			out[#out + 1] = { dx = b, dz = a }
		else
			out[#out + 1] = { dx = a, dz = b }
		end
	end
	if count == 0 then
		return out
	end
	if mode == "LINE" then
		for i = 0, count - 1 do
			put((i - (count - 1) / 2) * cell, 0)
		end
	elseif mode == "BOX" and count >= 4 then
		local side = 2
		while 4 * (side - 1) < count do
			side = side + 1
		end
		local last = side - 1
		local ring = {}
		for i = 0, last - 1 do
			ring[#ring + 1] = { i, 0 }
		end
		for j = 0, last - 1 do
			ring[#ring + 1] = { last, j }
		end
		for i = last, 1, -1 do
			ring[#ring + 1] = { i, last }
		end
		for j = last, 1, -1 do
			ring[#ring + 1] = { 0, j }
		end
		for k = 0, count - 1 do
			local spot = ring[math.floor(k * #ring / count) + 1]
			put((spot[1] - last / 2) * cell, (spot[2] - last / 2) * cell)
		end
	else
		local cols = math.ceil(math.sqrt(count))
		local rows = math.ceil(count / cols)
		for k = 0, count - 1 do
			local r, c = math.floor(k / cols), k % cols
			local inRank = (r == rows - 1) and (count - r * cols) or cols
			put((c - (inRank - 1) / 2) * cell, (r - (rows - 1) / 2) * cell)
		end
	end
	return out
end

--- The facing (0 S, 1 E, 2 N, 3 W) that looks from (x, z) toward (tx, tz): the nearer cardinal.
function Layout.facingToward(x, z, tx, tz)
	local dx, dz = (tonumber(tx) or 0) - (tonumber(x) or 0), (tonumber(tz) or 0) - (tonumber(z) or 0)
	if math.abs(dx) > math.abs(dz) then
		return dx > 0 and 1 or 3
	end
	return dz >= 0 and 0 or 2
end

--- Placed units re-formed as a LINE, GRID or BOX where they stand (the mission editor's
--- squad tools, the terraform brush's selection tools): round the same centre, one cell the
--- largest footprint plus a build square, every unit facing the way the first one faces.
--- Each slot takes the nearest unit not yet placed, so a re-formed group does not cross
--- itself; each unit is snapped for its own turned footprint.
---@param units table { { x, z, facing, xsize, zsize }, ... } footprints in squares
---@param mode string "LINE" | "GRID" | "BOX" (BOX under four units is a GRID)
---@return table spots { { x, z, facing }, ... } at the same indices as `units`
function Layout.reform(units, mode)
	units = units or {}
	local out = {}
	if #units == 0 then
		return out
	end
	local facing = math.floor(tonumber(units[1].facing) or 0) % 4
	local cell = 0
	for _, unit in ipairs(units) do
		local w, h = Layout.footprint(unit.xsize, unit.zsize, facing)
		cell = math.max(cell, w, h)
	end
	cell = cell + Layout.BUILD_SQUARE_SIZE
	local _, cx, cz = Layout.centreOffsets(units)
	local slots = Layout.arrange(#units, mode, cell, facing)
	local taken = {}
	for _, slot in ipairs(slots) do
		local tx, tz = cx + slot.dx, cz + slot.dz
		local best, bestDistance
		for index, unit in ipairs(units) do
			if not taken[index] then
				local d = ((tonumber(unit.x) or 0) - tx) ^ 2 + ((tonumber(unit.z) or 0) - tz) ^ 2
				if not bestDistance or d < bestDistance then
					best, bestDistance = index, d
				end
			end
		end
		taken[best] = true
		local unit = units[best]
		local w, h = Layout.footprint(unit.xsize, unit.zsize, facing)
		out[best] = { x = Layout.snapAxis(tx, w), z = Layout.snapAxis(tz, h), facing = facing }
	end
	return out
end

--- Placed units pulled toward or pushed away from their centre by `factor` (0.75 tighter,
--- 4/3 looser), each snapped for its own footprint. Tightening that would bring two units
--- closer than the largest footprint gives nil: they are as tight as they go.
---@param units table { { x, z, facing, xsize, zsize }, ... }
---@param factor number
---@return table|nil spots { { x, z }, ... } at the same indices as `units`
function Layout.space(units, factor)
	units = units or {}
	factor = tonumber(factor) or 1
	local offsets, cx, cz = Layout.centreOffsets(units)
	local build = Layout.BUILD_SQUARE_SIZE
	-- Scaled, but by at least one build step: a small squad's offsets are only a step or
	-- two, and a plain x4/3 snaps straight back onto the grid line it came from.
	local function scaled(d)
		if d == 0 or factor == 1 then
			return d
		end
		local size = math.abs(d)
		if factor > 1 then
			size = math.max(size * factor, size + build)
		else
			size = math.max(0, math.min(size * factor, size - build))
		end
		return d > 0 and size or -size
	end
	local spots, reach = {}, 0
	for index, unit in ipairs(units) do
		local w, h = Layout.footprint(unit.xsize, unit.zsize, unit.facing)
		reach = math.max(reach, w, h)
		spots[index] = {
			x = Layout.snapAxis(cx + scaled(offsets[index].dx), w),
			z = Layout.snapAxis(cz + scaled(offsets[index].dz), h),
		}
	end
	if factor < 1 then
		for i = 1, #spots do
			for j = i + 1, #spots do
				if math.abs(spots[i].x - spots[j].x) < reach and math.abs(spots[i].z - spots[j].z) < reach then
					return nil
				end
			end
		end
	end
	return spots
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
