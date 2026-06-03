local SplineLib = VFS.Include("common/lib_spline.lua")
local base64 = VFS.Include("common/luaUtilities/base64.lua")

local function GetStartboxName(midX, midZ)
	if (midX < 0.33) then
		if (midZ < 0.33) then
			return "North-West", "NW"
		elseif (midZ > 0.66) then
			return "South-West", "SW"
		else
			return "West", "W"
		end
	elseif (midX > 0.66) then
		if (midZ < 0.33) then
			return "North-East", "NE"
		elseif (midZ > 0.66) then
			return "South-East", "SE"
		else
			return "East", "E"
		end
	else
		if (midZ < 0.33) then
			return "North", "N"
		elseif (midZ > 0.66) then
			return "South", "S"
		else
			return "Center", "Center"
		end
	end
end

local function decodeModoption(raw)
	if not raw or #raw == 0 then
		return nil
	end

	local okDecode, decoded = pcall(base64.Decode, raw)
	if not okDecode or not decoded then
		return nil
	end

	local decompressed = VFS.ZlibDecompress(decoded)
	if not decompressed then
		return nil
	end

	local okJson, parsed = pcall(Json.decode, decompressed)
	if not okJson or type(parsed) ~= "table" then
		return nil
	end

	return parsed
end

local function getActiveAllyTeamCount()
	local gaiaAllyTeamID
	local gaiaTeamID = Spring.GetGaiaTeamID()
	if gaiaTeamID then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID, false))
	end

	local count = 0
	for _, atID in ipairs(Spring.GetAllyTeamList()) do
		if atID ~= gaiaAllyTeamID then
			count = count + 1
		end
	end

	return count
end

local function resolveArrangement(parsedOverride, parsedSet, numTeams)
	if parsedOverride and parsedOverride.startboxes and #parsedOverride.startboxes == numTeams then
		return parsedOverride, "modoption_override"
	end

	if parsedSet then
		local exact = parsedSet[tostring(numTeams)]
		if exact then
			return exact, "modoption_set"
		end

		local bestKey, bestNum
		for k in pairs(parsedSet) do
			local kn = tonumber(k)
			if kn and kn > numTeams then
				if not bestNum or kn < bestNum then
					bestKey = k
					bestNum = kn
				end
			end
		end
		if bestKey then
			return parsedSet[bestKey], "modoption_set"
		end
	end

	return nil, nil
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
				boxes = {{
					{0, 0},
					{0, mapSizeZ * 0.2},
					{mapSizeX, mapSizeZ * 0.2},
					{mapSizeX, 0},
				}},
				startpoints = {{ mapSizeX * 0.5, mapSizeZ * 0.1 }},
				nameLong = "North",
				nameShort = "N",
			},
			[1] = {
				boxes = {{
					{0, mapSizeZ * 0.8},
					{0, mapSizeZ},
					{mapSizeX, mapSizeZ},
					{mapSizeX, mapSizeZ * 0.8},
				}},
				startpoints = {{ mapSizeX * 0.5, mapSizeZ * 0.9 }},
				nameLong = "South",
				nameShort = "S",
			},
		}
	end

	return {
		[0] = {
			boxes = {{
				{0, 0},
				{0, mapSizeZ},
				{mapSizeX * 0.2, mapSizeZ},
				{mapSizeX * 0.2, 0},
			}},
			startpoints = {{ mapSizeX * 0.1, mapSizeZ * 0.5 }},
			nameLong = "West",
			nameShort = "W",
		},
		[1] = {
			boxes = {{
				{mapSizeX * 0.8, 0},
				{mapSizeX * 0.8, mapSizeZ - 1},
				{mapSizeX, mapSizeZ - 1},
				{mapSizeX, 0},
			}},
			startpoints = {{ mapSizeX * 0.9, mapSizeZ * 0.5 }},
			nameLong = "East",
			nameShort = "E",
		},
	}
end

local function ParseBoxes()
	local numTeams = getActiveAllyTeamCount()

	local modoptions = Spring.GetModOptions()
	local parsedOverride = decodeModoption(modoptions.mapmetadata_startbox_override)
	local parsedSet = decodeModoption(modoptions.mapmetadata_startboxes_set)

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

	return startBoxConfig, configSource
end

return ParseBoxes
