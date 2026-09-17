---@class StartExport the editor's two exports of the drawn starts: the startbox arrangement the old mod options carry (SHIM, the inverse of RegionLayout.FromStartboxArrangement), and a local start script for playtesting
local Export = {}

local SPACE = 200

---@param v number elmos
---@param size number the map's extent on that axis
---@return integer 0..200
local function toNorm(v, size)
	return math.max(0, math.min(SPACE, math.floor(v * SPACE / math.max(1, size) + 0.5)))
end

---@param areas StartRegion[] in team order; each with vertices, or controls and kind "spline" when curved, or kind "box" for an axis-aligned rect
---@param mapSizeX number
---@param mapSizeZ number
---@return { poly: { x: integer, y: integer, strength: number|nil }[] }[] one entry per area, the anchors normalised to 0..200; a rect as its two corners; strength snapped to 0.025 and omitted at zero, as maps-metadata reads it
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

---@class StartScriptOptions
---@field mapName string
---@field playerName string|nil
---@field aiShortName string|nil
---@field aiVersion string|nil
---@field startPosType integer|nil
---@field modOptions table<string, any>|nil

---@param areas StartRegion[] with vertices; one ally team per distinct team, its start rect the areas' bounding box
---@param mapSizeX number
---@param mapSizeZ number
---@param opts StartScriptOptions
---@return string|nil script nil when there are no areas
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
	for idx, team in ipairs(teams) do
		local minX, minZ, maxX, maxZ = mapSizeX, mapSizeZ, 0, 0
		for _, area in ipairs(areas) do
			if area.team == team then
				for _, v in ipairs(area.vertices or {}) do
					minX, maxX = math.min(minX, v.x), math.max(maxX, v.x)
					minZ, maxZ = math.min(minZ, v.z), math.max(maxZ, v.z)
				end
			end
		end
		L(string.format("\t[allyTeam%d]", idx - 1))
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
