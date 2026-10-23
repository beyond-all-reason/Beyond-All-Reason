---@class StartExport
local Export = {}

local SPACE = 200

---@param v number
---@param size number
---@return integer
local function toNorm(v, size)
	return math.max(0, math.min(SPACE, math.floor(v * SPACE / math.max(1, size) + 0.5)))
end

---@param areas StartRegion[]
---@param mapSizeX number
---@param mapSizeZ number
---@return { poly: { x: integer, y: integer, strength: number|nil }[] }[]
function Export.Arrangement(areas, mapSizeX, mapSizeZ)
	local out = {}
	for _, area in ipairs(areas) do
		local anchors = area.kind == "spline" and area.controls or area.vertices or {}
		local poly = {}
		if area.kind == "box" and #anchors >= 3 then
			local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
			for _, a in ipairs(anchors) do
				minX, maxX = math.min(minX, a.x), math.max(maxX, a.x)
				minZ, maxZ = math.min(minZ, a.z), math.max(maxZ, a.z)
			end
			poly[1] = { x = toNorm(minX, mapSizeX), y = toNorm(minZ, mapSizeZ) }
			poly[2] = { x = toNorm(maxX, mapSizeX), y = toNorm(maxZ, mapSizeZ) }
		else
			for k, a in ipairs(anchors) do
				local pt = { x = toNorm(a.x, mapSizeX), y = toNorm(a.z, mapSizeZ) }
				local strength = a.strength and (math.floor(a.strength * 40 + 0.5) / 40)
				if strength and strength > 0 then
					pt.strength = strength
				end
				poly[k] = pt
			end
		end
		if #poly >= 2 then
			out[#out + 1] = { poly = poly }
		end
	end
	return out
end

---@class StartSuggestions what a map ships as mapmetadata_startpos: the spawn points, and per layout the ally
---teams' starts on them
---@field positions table<string, { x: integer, y: integer }>
---@field team { teamCount: integer, playersPerTeam: integer, sides: { starts: { spawnPoint: string, role: string|nil }[] }[] }[]

-- The starts' positions as the map's start position suggestions, one layout of every team that has a position: a
-- team's starts in the order of its positions, each with its role. Points are in elmos, named P1.. in the order the
-- starts hold them.
---@param starts StartRegion[]
---@return StartSuggestions|nil
function Export.Suggestions(starts)
	local seated = {} ---@type StartRegion[]
	for _, start in ipairs(starts) do
		if start.positions and #start.positions > 0 then
			seated[#seated + 1] = start
		end
	end
	if #seated == 0 then
		return nil
	end
	local positions, sideOf = {}, {} ---@type table<string, { x: integer, y: integer }>, table<integer, table>
	local count = 0
	for _, start in ipairs(seated) do
		sideOf[start.team] = sideOf[start.team] or { starts = {} }
		for _, p in ipairs(start.positions) do
			count = count + 1
			local id = "P" .. count
			positions[id] = { x = math.floor(p.x), y = math.floor(p.z) }
			table.insert(sideOf[start.team].starts, { spawnPoint = id, role = p.role })
		end
	end
	local teams = {} ---@type integer[]
	for team in pairs(sideOf) do
		teams[#teams + 1] = team
	end
	table.sort(teams)
	local sides, playersPerTeam = {}, 1
	for _, team in ipairs(teams) do
		sides[#sides + 1] = sideOf[team]
		playersPerTeam = math.max(playersPerTeam, #sideOf[team].starts)
	end
	return {
		positions = positions,
		team = { { teamCount = #teams, playersPerTeam = playersPerTeam, sides = sides } },
	}
end

---@class StartScriptOptions
---@field mapName string
---@field playerName string|nil
---@field aiShortName string|nil
---@field aiVersion string|nil
---@field startPosType integer|nil
---@field modOptions table<string, any>|nil

---@param areas StartRegion[]
---@param mapSizeX number
---@param mapSizeZ number
---@param opts StartScriptOptions
---@return string|nil
function Export.StartScript(areas, mapSizeX, mapSizeZ, opts)
	if #areas == 0 then
		return nil
	end
	local teams = {}
	local seen = {}
	for _, area in ipairs(areas) do
		if area.team and not seen[area.team] then
			seen[area.team] = true
			teams[#teams + 1] = area.team
		end
	end
	table.sort(teams)
	local lines = {}
	local function L(s)
		lines[#lines + 1] = s
	end
	L("[Game]")
	L("{")
	for _, team in ipairs(teams) do
		local minX, minZ, maxX, maxZ = mapSizeX, mapSizeZ, 0, 0 ---@type number, number, number, number
		for _, area in ipairs(areas) do
			if area.team == team then
				for _, v in ipairs(area.vertices or {}) do
					minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
					minZ, maxZ = math.min(minZ, v.z), math.max(maxZ, v.z)
				end
			end
		end
		L(string.format("\t[allyTeam%d]", team))
		L("\t{")
		L(string.format("\t\tstartrectleft = %.8f;", minX / mapSizeX))
		L(string.format("\t\tstartrectright = %.8f;", maxX / mapSizeX))
		L(string.format("\t\tstartrecttop = %.8f;", minZ / mapSizeZ))
		L(string.format("\t\tstartrectbottom = %.8f;", maxZ / mapSizeZ))
		L("\t\tnumallies = 0;")
		L("\t}")
		L("")
	end
	local sides = { "Armada", "Cortex" }
	for idx = 1, #teams do
		L(string.format("\t[team%d]", idx - 1))
		L("\t{")
		L(string.format("\t\tSide = %s;", sides[((idx - 1) % 2) + 1]))
		L("\t\tHandicap = 0;")
		L("\t\tRgbColor = 0.99609375 0.546875 0;")
		L(string.format("\t\tAllyTeam = %d;", idx - 1))
		L("\t\tTeamLeader = 0;")
		L("\t}")
		L("")
	end
	L("\t[player0]")
	L("\t{")
	L("\t\tIsFromDemo = 0;")
	L(string.format("\t\tName = %s;", opts.playerName or "Player"))
	L("\t\tTeam = 0;")
	L("\t\trank = 0;")
	L("\t}")
	L("")
	local aiShort, aiVersion = opts.aiShortName or "NullAI", opts.aiVersion or "0.1"
	for idx = 2, #teams do
		L(string.format("\t[ai%d]", idx - 2))
		L("\t{")
		L("\t\tHost = 0;")
		L("\t\tIsFromDemo = 0;")
		L(string.format("\t\tName = %s(%d);", aiShort, idx - 1))
		L(string.format("\t\tShortName = %s;", aiShort))
		L(string.format("\t\tTeam = %d;", idx - 1))
		L(string.format("\t\tVersion = %s;", aiVersion))
		L("\t}")
		L("")
	end
	L("\t[modoptions]")
	L("\t{")
	for k, v in pairs(opts.modOptions or {}) do
		L(string.format("\t\t%s = %s;", tostring(k), tostring(v)))
	end
	L("\t}")
	L("")
	L("\thostip = 127.0.0.1;")
	L("\thostport = 0;")
	L("\tishost = 1;")
	L("\tGameStartDelay = 5;")
	L("\tnumplayers = 1;")
	L(string.format("\tnumusers = %d;", #teams))
	L(string.format("\tstartpostype = %d;", opts.startPosType or 2))
	L(string.format("\tmapname = %s;", opts.mapName))
	L(string.format("\tmyplayername = %s;", opts.playerName or "Player"))
	L("\tgametype = Beyond All Reason $VERSION;")
	L("\tnohelperais = 0;")
	L("}")
	return table.concat(lines, "\n")
end

return Export
