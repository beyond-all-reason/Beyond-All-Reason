local function WrappedInclude(x)
	local env = getfenv()
	local prevGTC = env.GetTeamCount -- typically nil but also works otherwise
	env.GetTeamCount = Spring.Utilities.GetAllyTeamCount -- for legacy mapside boxes
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

	local startBoxConfig

	if VFS.FileExists (mapsideBoxes) then
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
			local mapSizeX = Game.mapSizeX
			local mapSizeZ = Game.mapSizeZ
			if mapSizeZ > mapSizeX then
				startBoxConfig[0] = {
					boxes = {{
						{0, 0},
						{0, mapSizeZ * 0.2},
						{mapSizeX, mapSizeZ * 0.2},
						{mapSizeX, 0}
					}},
					startpoints = {
						{mapSizeX * 0.5, mapSizeZ * 0.1}
					},
					nameLong = "North",
					nameShort = "N"
				}
				startBoxConfig[1] = {
					boxes = {{
						{0, mapSizeZ * 0.8},
						{0, mapSizeZ},
						{mapSizeX, mapSizeZ},
						{mapSizeX, mapSizeZ * 0.8}
					}},
					startpoints = {
						{mapSizeX * 0.5, mapSizeZ * 0.9}
					},
					nameLong = "South",
					nameShort = "S"
				}
			else
				startBoxConfig[0] = {
					boxes = {{
						{0, 0},
						{0, mapSizeZ},
						{mapSizeX * 0.2, mapSizeZ},
						{mapSizeX * 0.2, 0},
					}},
					startpoints = {
						{mapSizeX * 0.1, mapSizeZ * 0.5}
					},
					nameLong = "West",
					nameShort = "W"
				}
				startBoxConfig[1] = {
					boxes = {{
						{mapSizeX * 0.8, 0},
						{mapSizeX * 0.8, mapSizeZ - 1},
						{mapSizeX, mapSizeZ - 1},
						{mapSizeX, 0},
					}},
					startpoints = {
						{mapSizeX * 0.9, mapSizeZ * 0.5}
					},
					nameLong = "East",
					nameShort = "E"
				}
			end
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

	return startBoxConfig
end

return ParseBoxes
