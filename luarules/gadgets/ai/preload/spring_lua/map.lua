local map = {}
map.spots = shard_include("spring_lua/metal")
map.geos = shard_include("spring_lua/geo")
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

function map:FindClosestBuildSite(unittype, builderpos, searchradius, minimumdistance, validFunction) -- returns Position
	-- validFunction takes a position and returns a position or nil if the position is not valid
	validFunction = validFunction or function (position) return position end
	searchradius = searchradius or 500
	minimumdistance = minimumdistance or 50
	local twicePi = math.pi * 2
	local angleIncMult = twicePi / minimumdistance
	local bx, bz = builderpos.x, builderpos.z
	local maxX, maxZ = Game.mapSizeX, Game.mapSizeZ
	for radius = 50, searchradius, minimumdistance do
		local angleInc = radius * twicePi * angleIncMult
		local initAngle = math.random() * twicePi
		for angle = initAngle, initAngle+twicePi, angleInc do
			local realAngle = angle+0
			if realAngle > twicePi then realAngle = realAngle - twicePi end
			local dx, dz = radius*math.cos(angle), radius*math.sin(angle)
			local x, z = bx+dx, bz+dz
			if x < 0 then x = 0 elseif x > maxX then x = maxX end
			if z < 0 then z = 0 elseif z > maxZ then z = maxZ end
			local y = Spring.GetGroundHeight(x,z)
			local buildable, position = self:CanBuildHere(unittype, {x=x, y=y, z=z})
			if buildable then
				position = validFunction(position)
				if position then return position end
			end
		end 
	end
	local lastDitch, lastDitchPos = self:CanBuildHere(unittype, builderpos)
	if lastDitch then
		lastDitchPos = validFunction(lastDitchPos)
		if lastDitchPos then return lastDitchPos end
	end
end

function map:CanBuildHere(unittype,position) -- returns boolean
	local newX, newY, newZ = Spring.Pos2BuildPos(unittype:ID(), position.x, position.y, position.z)
	local blocked = Spring.TestBuildOrder(unittype:ID(), newX, newY, newZ, 1) == 0
	-- Spring.Echo(unittype:Name(), newX, newY, newZ, blocked)
	return ( not blocked ), {x=newX, y=newY, z=newZ}
end

function map:GetMapFeatures()
	local fv = Spring.GetAllFeatures()
	if not fv then return {} end
	local f = {}
	for _, fID in pairs(fv) do
		f[#f+1] = Shard:shardify_feature(fID)
	end
	return f
end

function map:GetMapFeaturesAt(position,radius)
	local fv = Spring.GetFeaturesInSphere(position.x, position.y, position.z, radius)
	if not fv then return {} end
	local f = {}
	for _, fID in pairs(fv) do
		f[#f+1] = Shard:shardify_feature(fID)
	end
	return f
end

function map:SpotCount() -- returns the nubmer of metal spots
	return #self.spots
end

function map:GetSpot(idx) -- returns a Position for the given spot
	return self.spots[idx]
end

function map:GetMetalSpots() -- returns a table of spot positions
	local fv = self.spots
	local count = self:SpotCount()
	local f = {}
	local i = 0
	while i  < count do
		table.insert( f, fv[i] )
		i = i + 1
	end
	return f
end

function map:GeoCount() -- returns the nubmer of metal spots
	return #self.geos
end

function map:GetGeo(idx)
	return self.geos[idx]
end

function map:GetGeoSpots() -- returns a table of spot positions
	local fv = self.geos
	local count = self:GeoCount()
	local f = {}
	local i = 0
	while i  < count do
		table.insert( f, fv[i] )
		i = i + 1
	end
	return f
end

function map:GetControlPoints()
	if self.controlPoints then return self.controlPoints end
	self.controlPoints = {}
	if Script.LuaRules('ControlPoints') then
		local rawPoints = Script.LuaRules.ControlPoints() or {}
		for id = 1, #rawPoints do
			local rawPoint = rawPoints[id]
			local cp = ShardSpringControlPoint()
			cp:Init(rawPoint, id)
			self.controlPoints[id] = cp
		end
	end
	return self.controlPoints
end

function map:AreControlPoints()
	local points = self:GetControlPoints()
	return #points > 0
end

function map:MapDimensions() -- returns a Position holding the dimensions of the map
	return {
		x = Game.mapSizeX / 8,
		z = Game.mapSizeZ / 8,
		y = 0
	}
end

function map:MapName() -- returns the name of this map
	return Game.mapName
end

function map:AverageWind() -- returns (minwind+maxwind)/2
	return ( Game.windMin + (Game.windMax - Game.windMin)/2 )
end


function map:MinimumWindSpeed() -- returns minimum windspeed
	return Game.windMin
end

function map:MaximumWindSpeed() -- returns maximum wind speed
	return Game.windMax
end

function map:MaximumHeight() -- returns maximum map height
	local minHeight, maxHeight = Spring.GetGroundExtremes()
	return maxHeight
end

function map:MinimumHeight() -- returns minimum map height
	local minHeight, maxHeight = Spring.GetGroundExtremes()
	return minHeight
end


function map:TidalStrength() -- returns tidal strength
	return Game.tidal
end

-- DRAWING FUNCTIONS

function map:DrawRectangle(pos1, pos2, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	SendToUnsynced('ShardDrawAddRectangle', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:EraseRectangle(pos1, pos2, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	return SendToUnsynced('ShardDrawEraseRectangle', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
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