-- Maps camelCase method names used by ZK-style mapside configs to the
-- PascalCase names in BAR's Spring.Utilities.Gametype, plus ZK-specific
-- names (e.g. isChickens) to their BAR equivalents.
local camelToPascal = {
	isFFA = 'IsFFA',
	isTeams = 'IsTeams',
	is1v1 = 'Is1v1',
	isBigTeams = 'IsBigTeams',
	isSmallTeams = 'IsSmallTeams',
	isRaptors = 'IsRaptors',
	isScavengers = 'IsScavengers',
	isPvE = 'IsPvE',
	isCoop = 'IsCoop',
	isSinglePlayer = 'IsSinglePlayer',
	isSandbox = 'IsSandbox',
	isChickens = 'IsRaptors',
}

-- Bare-global shim for configs that use `gametype.isFFA()` without going
-- through Spring.Utilities.Gametype.
local gametypeShim = setmetatable({}, {
	__index = function(_, k)
		if Spring.Utilities and Spring.Utilities.Gametype then
			local mapped = camelToPascal[k]
			if mapped then
				local fn = Spring.Utilities.Gametype[mapped]
				if fn then return fn end
			end
		end
		return function() return false end
	end
})

-- Metatable applied temporarily to Spring.Utilities.Gametype during
-- WrappedInclude so that configs doing
--   `local gametype = Spring.Utilities.Gametype; gametype.isFFA()`
-- find the correct PascalCase method (or a safe stub for unknown names).
local gametypeCompatMT = {
	__index = function(t, k)
		local mapped = camelToPascal[k]
		if mapped then
			local fn = rawget(t, mapped)
			if fn then return fn end
		end
		return function() return false end
	end
}

local function NormalizeConfigKeys(config)
	if not config or config[0] ~= nil then
		return config
	end
	if config[1] == nil then
		return config
	end
	local normalized = {}
	for k, v in pairs(config) do
		if type(k) == 'number' then
			normalized[k - 1] = v
		else
			normalized[k] = v
		end
	end
	return normalized
end

local function WrappedInclude(x)
	local env = getfenv()
	local prevGTC = env.GetTeamCount -- typically nil but also works otherwise
	local prevGT = env.gametype
	local prevGametypeMT
	env.GetTeamCount = Spring.Utilities.GetAllyTeamCount -- for legacy mapside boxes
	if not env.gametype then
		env.gametype = gametypeShim
	end
	if Spring.Utilities and Spring.Utilities.Gametype then
		prevGametypeMT = getmetatable(Spring.Utilities.Gametype)
		setmetatable(Spring.Utilities.Gametype, gametypeCompatMT)
	end
	local ok, ret = pcall(VFS.Include, x, env)
	env.GetTeamCount = prevGTC
	env.gametype = prevGT
	if Spring.Utilities and Spring.Utilities.Gametype then
		setmetatable(Spring.Utilities.Gametype, prevGametypeMT)
	end
	if not ok then
		error(ret, 2)
	end
	return ret
end

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

local function ParseBoxes ()
	local mapsideBoxes = "mapconfig/map_startboxes.lua"

	local startBoxConfig
	local configSource -- "mapside", "autohost_polygon", "autohost_rect", "fallback"

	if VFS.FileExists (mapsideBoxes) then
		startBoxConfig = NormalizeConfigKeys(WrappedInclude(mapsideBoxes))
		configSource = "mapside"
	else
		startBoxConfig = { }
		local startboxString = Spring.GetModOptions().startboxes
		local startboxStringLoadedBoxes = false
		if startboxString then
			local springieBoxes = loadstring(startboxString)()
			for id, box in pairs(springieBoxes) do
				startboxStringLoadedBoxes = true -- Autohost always sends a table. Often it is empty.

				if box.boxes then
					-- polygon format: autohost sent full polygon config
					if not box.nameLong and not box.nameShort then
						local bounds = box.boxes[1] or {}
						local sumX, sumZ, count = 0, 0, 0
						for _, v in ipairs(bounds) do
							sumX = sumX + v[1]
							sumZ = sumZ + v[2]
							count = count + 1
						end
						if count > 0 then
							local midX = sumX / (count * Game.mapSizeX)
							local midZ = sumZ / (count * Game.mapSizeZ)
							box.nameLong, box.nameShort = GetStartboxName(midX, midZ)
						end
					end
					startBoxConfig[id] = box
					configSource = configSource or "autohost_polygon"
				else
					-- legacy rectangle format: {xmin, zmin, xmax, zmax} in normalized 0-1 coords
					local midX = (box[1]+box[3]) / 2
					local midZ = (box[2]+box[4]) / 2

					box[1] = box[1]*Game.mapSizeX
					box[2] = box[2]*Game.mapSizeZ
					box[3] = box[3]*Game.mapSizeX
					box[4] = box[4]*Game.mapSizeZ

					local longName, shortName = GetStartboxName(midX, midZ)

					startBoxConfig[id] = {
						boxes = {{
							{box[1], box[2]},
							{box[1], box[4]},
							{box[3], box[4]},
							{box[3], box[2]},
						}},
						startpoints = {
							{(box[1]+box[3]) / 2, (box[2]+box[4]) / 2}
						},
						nameLong = longName,
						nameShort = shortName
					}
					configSource = configSource or "autohost_rect"
				end
			end
		end

		if not startboxStringLoadedBoxes then
			configSource = "fallback"
		end
	end

	-- fix rendering z-fighting
	local maxZ = Game.mapSizeZ - 1
	for boxid, box in pairs(startBoxConfig) do
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
