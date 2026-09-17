---@class StartPlacement where start positions go when an editor lays them out by shape: pure geometry, in elmos, clamped to the map
local Placement = {}

---@class StartPlacementShape
---@field shape "circle"|"square"|"triangle"|"hexagon"|"octagon"
---@field radius number elmos
---@field count integer positions to place
---@field rotation number degrees

local SIDES = { circle = 0, square = 4, triangle = 3, hexagon = 6, octagon = 8 }

---@param x number
---@param z number
---@param mapSizeX number
---@param mapSizeZ number
---@return number x
---@return number z
local function clamp(x, z, mapSizeX, mapSizeZ)
	return math.max(0, math.min(mapSizeX, x)), math.max(0, math.min(mapSizeZ, z))
end

---@param cx number
---@param cz number
---@param radius number
---@param count integer
---@param rotation number degrees
---@return { x: number, z: number }[] evenly around the circle, from the rotation
local function onCircle(cx, cz, radius, count, rotation)
	local pts = {}
	local step = (2 * math.pi) / count
	local rot = rotation * math.pi / 180
	for i = 1, count do
		local angle = rot + (i - 1) * step
		pts[i] = { x = cx + radius * math.cos(angle), z = cz + radius * math.sin(angle) }
	end
	return pts
end

---@param cx number
---@param cz number
---@param radius number
---@param sides integer
---@param count integer
---@param rotation number degrees
---@return { x: number, z: number }[] the polygon's vertices first, then edge midpoints, subdividing until count is met
local function onPolygon(cx, cz, radius, sides, count, rotation)
	local points = onCircle(cx, cz, radius, sides, rotation)
	local level = 1
	while #points < count and level <= 6 do
		local finer = {}
		for i = 1, #points do
			local j = (i % #points) + 1
			finer[#finer + 1] = points[i]
			finer[#finer + 1] = { x = (points[i].x + points[j].x) * 0.5, z = (points[i].z + points[j].z) * 0.5 }
		end
		points = finer
		level = level + 1
	end
	local pts = {}
	for i = 1, math.min(count, #points) do
		pts[i] = points[i]
	end
	return pts
end

---@param cx number
---@param cz number
---@param shape StartPlacementShape
---@param mapSizeX number
---@param mapSizeZ number
---@return { x: number, z: number }[]
function Placement.Shape(cx, cz, shape, mapSizeX, mapSizeZ)
	local sides = SIDES[shape.shape] or 0
	local pts = sides == 0 and onCircle(cx, cz, shape.radius, shape.count, shape.rotation)
		or onPolygon(cx, cz, shape.radius, sides, shape.count, shape.rotation)
	for i, p in ipairs(pts) do
		local x, z = clamp(p.x, p.z, mapSizeX, mapSizeZ)
		pts[i] = { x = x, z = z }
	end
	return pts
end

---@param cx number
---@param cz number
---@param shape StartPlacementShape only radius and count matter: points fall uniformly inside the circle
---@param mapSizeX number
---@param mapSizeZ number
---@param random (fun(): number)|nil uniform in [0, 1); math.random when absent
---@return { x: number, z: number }[]
function Placement.Random(cx, cz, shape, mapSizeX, mapSizeZ, random)
	random = random or math.random
	local pts = {}
	for i = 1, shape.count do
		local angle = random() * 2 * math.pi
		local r = shape.radius * math.sqrt(random())
		local x, z = clamp(cx + r * math.cos(angle), cz + r * math.sin(angle), mapSizeX, mapSizeZ)
		pts[i] = { x = x, z = z }
	end
	return pts
end

---@param index integer 1-based position in the placement
---@param allyTeams integer
---@param teamsPerAlly integer
---@param mode "roundrobin"|"sequential" roundrobin: A1 B1 C1 A2 B2 C2; sequential: A1 A2 B1 B2 C1 C2
---@return integer allyTeam
---@return integer teamSlot
function Placement.SlotFor(index, allyTeams, teamsPerAlly, mode)
	local i = index - 1
	local numAlly, numSlot = math.max(1, allyTeams), math.max(1, teamsPerAlly)
	if mode == "sequential" then
		return math.floor(i / numSlot) % numAlly + 1, (i % numSlot) + 1
	end
	return (i % numAlly) + 1, math.floor(i / numAlly) % numSlot + 1
end

-- The slope a commander can spawn on, in the 1 - cos(angle) space Spring.GetGroundNormal reports.
-- The modoption startpos_max_slope overrides it; otherwise the tightest maxSlope among commander
-- unit defs, found by the usual customParams conventions; 0.5 (about 30 degrees) when there is none.

---@param unitDefs table<any, table> UnitDefs
---@param modOptions table|nil
---@return number
function Placement.CommanderMaxSlope(unitDefs, modOptions)
	local override = modOptions and tonumber(modOptions.startpos_max_slope)
	if override then
		return override
	end
	local best = nil
	for _, ud in pairs(unitDefs) do
		local cp = ud.customParams
		local name = ud.name and ud.name:lower()
		local isCommander = cp and (cp.iscommander or cp.isCommander or cp.commander or cp.is_commander)
			or name
				and (name:find("commander") or name:find("^armcom") or name:find("^corcom") or name:find("^legcom"))
		local maxSlope = isCommander and ud.moveDef and ud.moveDef.maxSlope
		if maxSlope and maxSlope > 0 and (not best or maxSlope < best) then
			best = maxSlope
		end
	end
	return best or 0.5
end

return Placement
