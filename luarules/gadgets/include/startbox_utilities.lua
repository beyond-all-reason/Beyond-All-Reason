local function WrappedInclude(x)
	local env = getfenv()
	local prevGTC = env.GetTeamCount -- typically nil but also works otherwise
	env.GetTeamCount = Spring.Utilities.GetTeamCount -- for legacy mapside boxes
	local ret = VFS.Include(x, env)
	env.GetTeamCount = prevGTC
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
	local modsideBoxes = "LuaRules/Configs/StartBoxes/" .. (Game.mapName or "") .. ".lua"

	local startBoxConfig

	if VFS.FileExists (modsideBoxes) then
		startBoxConfig = WrappedInclude (modsideBoxes)
	elseif VFS.FileExists (mapsideBoxes) then
		startBoxConfig = WrappedInclude (mapsideBoxes)
	else
		startBoxConfig = { }
		local startboxString = Spring.GetModOptions().startboxes
		local startboxStringLoadedBoxes = false
		if startboxString then
			local springieBoxes = loadstring(startboxString)()
			for id, box in pairs(springieBoxes) do
				startboxStringLoadedBoxes = true -- Autohost always sends a table. Often it is empty.
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
			end
		end
		
		if not startboxStringLoadedBoxes then
			if Game.mapSizeZ > Game.mapSizeX then
				startBoxConfig[0] = {
					boxes = {{
						{0, 0},
						{0, Game.mapSizeZ * 0.2},
						{Game.mapSizeX, Game.mapSizeZ * 0.2},
						{Game.mapSizeX, 0}
					}},
					startpoints = {
						{Game.mapSizeX * 0.5, Game.mapSizeZ * 0.1}
					},
					nameLong = "North",
					nameShort = "N"
				}
				startBoxConfig[1] = {
					boxes = {{
						{0, Game.mapSizeZ * 0.8},
						{0, Game.mapSizeZ},
						{Game.mapSizeX, Game.mapSizeZ},
						{Game.mapSizeX, Game.mapSizeZ * 0.8}
					}},
					startpoints = {
						{Game.mapSizeX * 0.5, Game.mapSizeZ * 0.9}
					},
					nameLong = "South",
					nameShort = "S"
				}
			else
				startBoxConfig[0] = {
					boxes = {{
						{0, 0},
						{0, Game.mapSizeZ},
						{Game.mapSizeX * 0.2, Game.mapSizeZ},
						{Game.mapSizeX * 0.2, 0},
					}},
					startpoints = {
						{Game.mapSizeX * 0.1, Game.mapSizeZ * 0.5}
					},
					nameLong = "West",
					nameShort = "W"
				}
				startBoxConfig[1] = {
					boxes = {{
						{Game.mapSizeX * 0.8, 0},
						{Game.mapSizeX * 0.8, Game.mapSizeZ - 1},
						{Game.mapSizeX, Game.mapSizeZ - 1},
						{Game.mapSizeX, 0},
					}},
					startpoints = {
						{Game.mapSizeX * 0.9, Game.mapSizeZ * 0.5}
					},
					nameLong = "East",
					nameShort = "E"
				}
			end
		end
	end

	-- fix rendering z-fighting
	for boxid, box in pairs(startBoxConfig) do
		for i = 1, #box.boxes do
			for j = 1, #box.boxes[i] do
				if box.boxes[i][j][2] > Game.mapSizeZ - 1 then
					box.boxes[i][j][2] = Game.mapSizeZ - 1
				end
			end
		end
	end

	return startBoxConfig
end

return ParseBoxes
