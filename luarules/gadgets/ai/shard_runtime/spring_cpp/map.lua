local map = {}

	-- function map:FindClosestBuildSite(unittype,builderpos, searchradius, minimumdistance)
	-- function map:CanBuildHere(unittype,position)
	-- function map:GetMapFeatures()
	-- function map:GetMapFeaturesAt(position,radius)
	-- function map:SpotCount()
	-- function map:GetSpot(idx)
	-- function map:GetMetalSpots()
	-- function map:MapDimensions()
	-- function map:MapName()
	-- function map:AverageWind()
	-- function map:MinimumWindSpeed()
	-- function map:MaximumWindSpeed()
	-- function map:TidalStrength()
	-- function map:MaximumHeight()
	-- function map:MinimumHeight()

-- ###################

function map:FindClosestBuildSite(unittype,builderpos, searchradius, minimumdistance) -- returns Position
	--
	return game_engine:Map():FindClosestBuildSite(unittype,builderpos, searchradius, minimumdistance)
end

function map:CanBuildHere(unittype,position) -- returns boolean
	--
	return game_engine:Map():CanBuildHere(unittype,position)
end

function map:GetMapFeatures()
	local fv = game_engine:Map():GetMapFeatures()
	local f = {}
	local i = 0
	while i  < fv:size() do
		table.insert(f,fv[i])
		i = i + 1
	end
	fv = nil
	return f
end

function map:GetMapFeaturesAt(position,radius)
	local m = game_engine:Map()
	local fv = m:GetMapFeaturesAt(position,radius)
	local f = {}
	local i = 0
	while i  < fv:size() do
		table.insert(f,fv[i])
		i = i + 1
	end
	fv = nil
	return f
end

function map:SpotCount() -- returns the nubmer of metal spots
	local m = game_engine:Map()
	return m:SpotCount()
end

function map:GetSpot(idx) -- returns a Position for the given spot
	local m = game_engine:Map()
	return m:GetSpot(idx)
end

function map:GetMetalSpots() -- returns a table of spot positions
	--
	local m = game_engine:Map()
	local fv = game_engine:Map():GetMetalSpots()
	local count = m:SpotCount()
	local f = {}
	local i = 0
	while i  < count do
		table.insert( f, m:GetSpot(i) )
		i = i + 1
	end
	--fv = nil
	return f
end

function map:GeoCount() -- returns the nubmer of metal spots
	local m = game_engine:Map()
	return m:GeoCount()
end

function map:GetGeo(idx) -- returns a Position for the given spot
	local m = game_engine:Map()
	return m:GetGeo(idx)
end

function map:GetMetalSpots() -- returns a table of spot positions
	--
	local m = game_engine:Map()
	local fv = game_engine:Map():GetGeoSpots()
	local count = m:GeoCount()
	local f = {}
	local i = 0
	while i  < count do
		table.insert( f, m:GetGeo(i) )
		i = i + 1
	end
	--fv = nil
	return f
end

function map:GetControlPoints()
	-- not sure this can be implemented in the Spring C++ AI interface
	return {}
end

function map:AreControlPoints()
	-- not sure this can be implemented in the Spring C++ AI interface
	return false
end

function map:MapDimensions() -- returns a Position holding the dimensions of the map
	local m = game_engine:Map()
	return m:MapDimensions()
end

function map:MapName() -- returns the name of this map
	local m = game_engine:Map()
	return m:MapName()
end

function map:AverageWind() -- returns (minwind+maxwind)/2
	local m = game_engine:Map()
	return m:AverageWind()
end


function map:MinimumWindSpeed() -- returns minimum windspeed
	local m = game_engine:Map()
	return m:MinimumWindSpeed()
end

function map:MaximumWindSpeed() -- returns maximum wind speed
	local m = game_engine:Map()
	return m:MaximumWindSpeed()
end

function map:MaximumHeight() -- returns maximum map height
	local m = game_engine:Map()
	return m:MaximumHeight()
end

function map:MinimumHeight() -- returns minimum map height
	local m = game_engine:Map()
	return m:MinimumHeight()
end

function map:TidalStrength() -- returns tidal strength
	local m = game_engine:Map()
	return m:TidalStrength()
end

-- DRAWING FUNCTIONS

local function dataToString(...)
	local data = {...}
	local str = ''
	for i = 1, #data do
		local d = data[i]
		str = str .. '|' .. tostring(d)
	end
	return str
end

local function SendToUnsynced(command, ...)
	-- game_engine:SendToContent(command .. dataToString(...))
	local buff = io.open('sharddrawbuffer', 'a')
	if buff then
		buff:write(command .. dataToString(...) .. "\n")
		buff:close()
	end
end

function map:DrawRectangle(pos1, pos2, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	-- game:SendToContent('ShardDrawAddRectangle' .. dataToString(pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel))
	SendToUnsynced('ShardDrawAddRectangle', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:EraseRectangle(pos1, pos2, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawEraseRectangle', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:DrawCircle(pos, radius, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawAddCircle', pos.x, pos.z, radius, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:EraseCircle(pos, radius, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawEraseCircle', pos.x, pos.z, radius, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:DrawLine(pos1, pos2, color, label, arrow, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawAddLine', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, arrow, self.ai.game:GetTeamID(), channel)
end

function map:EraseLine(pos1, pos2, color, label, arrow, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawEraseLine', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, arrow, self.ai.game:GetTeamID(), channel)
end

function map:DrawPoint(pos, color, label, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawAddPoint', pos.x, pos.z, color[1], color[2], color[3], color[4], label, self.ai.game:GetTeamID(), channel)
end

function map:ErasePoint(pos, color, label, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawErasePoint', pos.x, pos.z, color[1], color[2], color[3], color[4], label, self.ai.game:GetTeamID(), channel)
end

function map:EraseAll(channel)
	channel = channel or 1
	SendToUnsynced('ShardDrawClearShapes', self.ai.game:GetTeamID(), channel)
end

function map:DisplayDrawings(onOff)
	SendToUnsynced('ShardDrawDisplay', onOff)
end

-- END DRAWING FUNCTIONS

	-- game.map = map

return map