-- Startbox resolution: canonical contract for lobby implementations.
-- The lobby (bar-lobby, BYAR-Chobby) produces these modoptions; this module
-- consumes them. Any lobby-side resolution must mirror resolveArrangement
-- below so previews match what the game enforces.
--
-- Modoptions (declared in modoptions.lua):
--   mapmetadata_startboxes_set     base64url(zlib(json)) of { num_teams_str: arrangement, ... }
--   mapmetadata_startbox_override  base64url(zlib(json)) of a single arrangement
--
-- arrangement shape == maps-metadata `startboxesInfo`:
--   https://github.com/beyond-all-reason/maps-metadata schemas/map_list.yaml

local SplineLib = VFS.Include("common/lib_spline.lua")
local ModoptionPayload = VFS.Include("common/luaUtilities/modoption_payload.lua")

local function GetStartboxName(midX, midZ)
	if midX < 0.33 then
		if midZ < 0.33 then
			return "North-West", "NW"
		elseif midZ > 0.66 then
			return "South-West", "SW"
		else
			return "West", "W"
		end
	elseif midX > 0.66 then
		if midZ < 0.33 then
			return "North-East", "NE"
		elseif midZ > 0.66 then
			return "South-East", "SE"
		else
			return "East", "E"
		end
	else
		if midZ < 0.33 then
			return "North", "N"
		elseif midZ > 0.66 then
			return "South", "S"
		else
			return "Center", "Center"
		end
	end
end

local function getActiveAllyTeamCount()
	local gaiaAllyTeamID
	local gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID then
		gaiaAllyTeamID = Spring.GetTeamAllyTeamID(gaiaTeamID)
	end

	local count = 0
	for _, atID in ipairs(Spring.GetAllyTeamList()) do
		if atID ~= gaiaAllyTeamID then
			count = count + 1
		end
	end

	return count
end

-- Will match any spare boxes, but will not leave any teams without a box.
local function matchOverride(override, numTeams)
	if override and override.startboxes and #override.startboxes >= numTeams then
		return override
	end

	return nil
end

local function matchSetExact(set, numTeams)
	if not set then
		return nil
	end

	return set[tostring(numTeams)]
end

local function matchSetLarger(set, numTeams)
	if not set then
		return nil
	end

	local bestKey, bestNum
	for k in pairs(set) do
		local kn = tonumber(k)
		if kn and kn > numTeams and (not bestNum or kn < bestNum) then
			bestKey = k
			bestNum = kn
		end
	end

	return bestKey and set[bestKey] or nil
end

local function matchSetSmaller(set, numTeams)
	if not set then
		return nil
	end

	local bestKey, bestNum
	for k in pairs(set) do
		local kn = tonumber(k)
		if kn and kn < numTeams and (not bestNum or kn > bestNum) then
			bestKey = k
			bestNum = kn
		end
	end

	return bestKey and set[bestKey] or nil
end

local function resolveArrangement(override, set, numTeams)
	local match = matchOverride(override, numTeams)
	if match then
		return match, "modoption_override"
	end

	match = matchSetExact(set, numTeams)
	if match then
		return match, "modoption_set"
	end

	match = matchSetLarger(set, numTeams)
	if match then
		return match, "modoption_set"
	end

	match = matchSetSmaller(set, numTeams)
	if match then
		return match, "modoption_set"
	end

	-- No modoption arrangement applies; defer to the engine startrect.
	return nil, nil
end

local function isExplicitSource(configSource)
	return configSource == "modoption_override" or configSource == "modoption_set"
end

local function expandPoly(poly)
	if #poly == 2 then
		local x1, z1 = poly[1].x, poly[1].y
		local x2, z2 = poly[2].x, poly[2].y

		return {
			{ x1, z1 },
			{ x2, z1 },
			{ x2, z2 },
			{ x1, z2 },
		}
	end

	local out = {}
	for i, p in ipairs(poly) do
		if p.strength ~= nil then
			out[i] = { p.x, p.y, p.strength }
		else
			out[i] = { p.x, p.y }
		end
	end

	return out
end

local function transformArrangement(arrangement)
	local config = {}
	local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
	local scaleX, scaleZ = mapSizeX / 200, mapSizeZ / 200

	for i, box in ipairs(arrangement.startboxes) do
		local allyTeamID = i - 1
		local poly = expandPoly(box.poly)

		local elmoPolygon = {}
		local sumX, sumZ = 0, 0
		for j, p in ipairs(poly) do
			local x = p[1] * scaleX
			local z = p[2] * scaleZ
			if p[3] ~= nil then
				elmoPolygon[j] = { x, z, p[3] }
			else
				elmoPolygon[j] = { x, z }
			end
			sumX = sumX + x
			sumZ = sumZ + z
		end

		local count = #elmoPolygon
		local centerX = sumX / count
		local centerZ = sumZ / count
		local nameLong, nameShort = GetStartboxName(centerX / mapSizeX, centerZ / mapSizeZ)

		config[allyTeamID] = {
			boxes = { elmoPolygon },
			startpoints = { { centerX, centerZ } },
			nameLong = nameLong,
			nameShort = nameShort,
		}
	end

	return config
end

local function buildFallback()
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ

	if mapSizeZ > mapSizeX then
		return {
			[0] = {
				boxes = {
					{
						{ 0, 0 },
						{ 0, mapSizeZ * 0.2 },
						{ mapSizeX, mapSizeZ * 0.2 },
						{ mapSizeX, 0 },
					},
				},
				startpoints = { { mapSizeX * 0.5, mapSizeZ * 0.1 } },
				nameLong = "North",
				nameShort = "N",
			},
			[1] = {
				boxes = {
					{
						{ 0, mapSizeZ * 0.8 },
						{ 0, mapSizeZ },
						{ mapSizeX, mapSizeZ },
						{ mapSizeX, mapSizeZ * 0.8 },
					},
				},
				startpoints = { { mapSizeX * 0.5, mapSizeZ * 0.9 } },
				nameLong = "South",
				nameShort = "S",
			},
		}
	end

	return {
		[0] = {
			boxes = {
				{
					{ 0, 0 },
					{ 0, mapSizeZ },
					{ mapSizeX * 0.2, mapSizeZ },
					{ mapSizeX * 0.2, 0 },
				},
			},
			startpoints = { { mapSizeX * 0.1, mapSizeZ * 0.5 } },
			nameLong = "West",
			nameShort = "W",
		},
		[1] = {
			boxes = {
				{
					{ mapSizeX * 0.8, 0 },
					{ mapSizeX * 0.8, mapSizeZ - 1 },
					{ mapSizeX, mapSizeZ - 1 },
					{ mapSizeX, 0 },
				},
			},
			startpoints = { { mapSizeX * 0.9, mapSizeZ * 0.5 } },
			nameLong = "East",
			nameShort = "E",
		},
	}
end

local function ParseBoxes()
	local numTeams = getActiveAllyTeamCount()

	local modoptions = Spring.GetModOptions()
	local parsedOverride = ModoptionPayload.Decode(modoptions.mapmetadata_startbox_override)
	local parsedSet = ModoptionPayload.Decode(modoptions.mapmetadata_startboxes_set)

	local arrangement, configSource = resolveArrangement(parsedOverride, parsedSet, numTeams)

	local startBoxConfig
	if arrangement then
		startBoxConfig = transformArrangement(arrangement)
	else
		startBoxConfig = buildFallback()
		configSource = "fallback"
	end

	for _, entry in pairs(startBoxConfig) do
		local boxes = entry.boxes
		if boxes then
			for i = 1, #boxes do
				local poly = boxes[i]
				local tessellated = SplineLib.TessellateRing(poly)
				tessellated.anchors = poly
				boxes[i] = tessellated
			end
		end
	end

	local maxZ = Game.mapSizeZ - 1
	for _, box in pairs(startBoxConfig) do
		local boxes = box.boxes
		for i = 1, #boxes do
			local boxRow = boxes[i]
			for j = 1, #boxRow do
				local point = boxRow[j]
				if point[2] > maxZ then
					point[2] = maxZ
				end
			end
		end
	end

	return startBoxConfig, configSource, isExplicitSource(configSource)
end

--------------------------------------------------------------------------------
-- Shared accessors
--
-- Each of these answers a question about one allyteam's start box without the caller
-- needing to know whether the boxes came from a modoption or from the engine. That
-- distinction is what several callers got wrong: Spring.GetAllyTeamStartBox reports the
-- bounding box of a polygon rather than its shape, and during the gadget load phase it
-- still reports whatever the host put in the start script, because the config gadget
-- does not apply the modoption until its Initialize runs. Reading through here is
-- correct in both phases and on both sides of the sync boundary.
--------------------------------------------------------------------------------

local PolygonLib = VFS.Include("common/lib_polygon.lua")

local cachedConfig, cachedSource, cachedExplicit
local haveParsed = false

-- Modoptions and the allyteam list are both fixed for the life of the game, so the parse
-- happens once however many callers ask for it.
local function GetConfig()
	if not haveParsed then
		haveParsed = true
		local ok, config, source, explicit = pcall(ParseBoxes)
		if ok then
			cachedConfig, cachedSource, cachedExplicit = config, source, explicit
		else
			Spring.Log("startbox_utilities", LOG.WARNING, "Could not parse start boxes: " .. tostring(config))
		end
	end

	return cachedConfig, cachedSource, cachedExplicit
end

-- nil unless this allyteam has a polygon worth consulting, so every accessor below
-- shares one guard before falling back to the engine.
local function GetEntry(allyTeamID)
	local config, _, explicit = GetConfig()
	if not (explicit and config) then
		return nil
	end

	local entry = config[allyTeamID]
	if entry and entry.boxes and #entry.boxes > 0 then
		return entry
	end

	return nil
end

local function GetBounds(allyTeamID)
	local entry = GetEntry(allyTeamID)
	if entry then
		return PolygonLib.GetStartboxBounds(entry)
	end

	return Spring.GetAllyTeamStartBox(allyTeamID)
end

local function IsInside(allyTeamID, x, z)
	local entry = GetEntry(allyTeamID)
	if entry then
		return PolygonLib.PointInStartbox(x, z, entry)
	end

	local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyTeamID)
	if not (xmin and zmin and xmax and zmax) or xmin >= xmax or zmin >= zmax then
		return true -- no box means nowhere is out of bounds
	end

	return x >= xmin and x <= xmax and z >= zmin and z <= zmax
end

-- Callers hand-rolled this by comparing the box against the whole map, one of them
-- against the wrong axis. A box covering everything restricts nothing, which is what
-- those callers were really asking about.
local function HasStartbox(allyTeamID)
	if GetEntry(allyTeamID) then
		return true
	end

	local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyTeamID)
	if not (xmin and zmin and xmax and zmax) or xmin >= xmax or zmin >= zmax then
		return false
	end

	return not (xmin <= 0 and zmin <= 0 and xmax >= Game.mapSizeX and zmax >= Game.mapSizeZ)
end

local function GetCenter(allyTeamID)
	local entry = GetEntry(allyTeamID)
	if entry and entry.startpoints and entry.startpoints[1] then
		return entry.startpoints[1][1], entry.startpoints[1][2]
	end

	local xmin, zmin, xmax, zmax = GetBounds(allyTeamID)
	if not (xmin and zmin and xmax and zmax) then
		return Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5
	end

	return (xmin + xmax) * 0.5, (zmin + zmax) * 0.5
end

local DEFAULT_TRIES = 100

-- Rejection sampling inside the bounding box, so the result is uniform over the real
-- shape rather than over the rectangle around it. inset keeps whatever is being placed
-- clear of the edge; it is tested on the four cardinal offsets, which is cheaper than
-- eroding the polygon and good enough for deciding whether something fits.
--
-- Returns nil when nothing suitable turned up. Treat that as "no room" rather than
-- widening the search, or a deliberately small box stops meaning anything.
local function GetRandomPos(allyTeamID, inset, tries)
	local xmin, zmin, xmax, zmax = GetBounds(allyTeamID)
	if not (xmin and zmin and xmax and zmax) then
		return nil
	end

	inset = inset or 0
	xmin, zmin = math.max(xmin + inset, 0), math.max(zmin + inset, 0)
	xmax, zmax = math.min(xmax - inset, Game.mapSizeX), math.min(zmax - inset, Game.mapSizeZ)
	if xmin > xmax or zmin > zmax then
		return nil
	end

	for _ = 1, (tries or DEFAULT_TRIES) do
		local x = math.random(xmin, xmax)
		local z = math.random(zmin, zmax)
		if
			IsInside(allyTeamID, x, z)
			and (
				inset == 0
				or (
					IsInside(allyTeamID, x - inset, z)
					and IsInside(allyTeamID, x + inset, z)
					and IsInside(allyTeamID, x, z - inset)
					and IsInside(allyTeamID, x, z + inset)
				)
			)
		then
			return x, z
		end
	end

	return nil
end

-- For callers that used to clamp a point into the rectangle. A polygon has no clamp, so
-- a point outside is pulled onto the nearest edge instead.
local function ClosestPos(allyTeamID, x, z)
	if IsInside(allyTeamID, x, z) then
		return x, z
	end

	local entry = GetEntry(allyTeamID)
	if not entry then
		local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyTeamID)
		if not (xmin and zmin and xmax and zmax) or xmin >= xmax or zmin >= zmax then
			return x, z
		end

		return math.clamp(x, xmin, xmax), math.clamp(z, zmin, zmax)
	end

	local bestX, bestZ, bestDist = x, z, math.huge
	for i = 1, #entry.boxes do
		local poly = entry.boxes[i]
		local n = #poly
		for j = 1, n do
			local ax, az = poly[j][1], poly[j][2]
			local bx, bz = poly[(j % n) + 1][1], poly[(j % n) + 1][2]
			local ex, ez = bx - ax, bz - az
			local lenSq = (ex * ex) + (ez * ez)
			local t = 0
			if lenSq > 0 then
				t = math.clamp((((x - ax) * ex) + ((z - az) * ez)) / lenSq, 0, 1)
			end
			local px, pz = ax + (ex * t), az + (ez * t)
			local dx, dz = x - px, z - pz
			local dist = (dx * dx) + (dz * dz)
			if dist < bestDist then
				bestX, bestZ, bestDist = px, pz, dist
			end
		end
	end

	return bestX, bestZ
end

-- Callable as well as indexable: some callers include this file and call the result as the parser.
return setmetatable({
	ParseBoxes = ParseBoxes,
	GetConfig = GetConfig,
	GetBounds = GetBounds,
	GetCenter = GetCenter,
	HasStartbox = HasStartbox,
	IsInside = IsInside,
	GetRandomPos = GetRandomPos,
	ClosestPos = ClosestPos,
}, {
	__call = function(_, ...)
		return ParseBoxes(...)
	end,
})
