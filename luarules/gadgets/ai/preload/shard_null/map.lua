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
	return false
end

function map:CanBuildHere(unittype,position) -- returns boolean
	return false
end

function map:GetMapFeatures()
	
	return {}
end

function map:GetMapFeaturesAt(position,radius)
	return {}
end

function map:SpotCount() -- returns the nubmer of metal spots
	return 0
end

function map:GetSpot(idx) -- returns a Position for the given spot
	return nil
end

function map:GetMetalSpots() -- returns a table of spot positions
	--
	return {}
end

function map:GeoCount() -- returns the nubmer of metal spots
	return 0
end

function map:GetGeo(idx) -- returns a Position for the given spot
	return nil
end

function map:GetGeoSpots() -- returns a table of spot positions
	--
	return {}
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
	return "None"
end

function map:AverageWind() -- returns (minwind+maxwind)/2
	return 1
end


function map:MinimumWindSpeed() -- returns minimum windspeed
	return 0
end

function map:MaximumWindSpeed() -- returns maximum wind speed
	return 1
end

function map:MaximumHeight() -- returns maximum map height
	return 1
end

function map:MinimumHeight() -- returns minimum map height
	return 0
end

function map:TidalStrength() -- returns tidal strength
	return 0
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
	--
end

function map:DrawRectangle(pos1, pos2, color, label, filled, channel)
	--
end

function map:EraseRectangle(pos1, pos2, color, label, filled, channel)
	--
end

function map:DrawCircle(pos, radius, color, label, filled, channel)
	--
end

function map:EraseCircle(pos, radius, color, label, filled, channel)
	--
end

function map:DrawLine(pos1, pos2, color, label, arrow, channel)
	--
end

function map:EraseLine(pos1, pos2, color, label, arrow, channel)
	--
end

function map:DrawPoint(pos, color, label, channel)
	--
end

function map:ErasePoint(pos, color, label, channel)
	--
end

function map:EraseAll(channel)
	--
end

function map:DisplayDrawings(onOff)
	--
end

-- END DRAWING FUNCTIONS

	-- game.map = map

return map