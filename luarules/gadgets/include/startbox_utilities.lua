local SplineLib = VFS.Include("common/lib_spline.lua")

local function WrappedInclude(x)
	local ok, ret = pcall(VFS.Include, x, getfenv())
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
		startBoxConfig = WrappedInclude(mapsideBoxes)
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

	-- Run every polygon through the spline tessellator. Anchors without a
	-- per-anchor strength are treated as sharp corners (strength 0), so plain
	-- polygons emerge with vertex-identical output. The original anchor table
	-- is preserved on `polygon.anchors` for future editor/handle work; this
	-- non-numeric field doesn't affect ipairs/# iteration over the vertices.
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
