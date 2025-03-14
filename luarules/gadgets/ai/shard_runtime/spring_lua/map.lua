local map = {}
map.metalSpots = shard_include("spring_lua/metal")
map.geoSpots = shard_include("spring_lua/geo")
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
	local fCount = 0
	for i=1,#fv do
		fCount = fCount + 1
		f[fCount] = Shard:shardify_feature(fv[i])
	end
	return f
end

function map:GetMapFeaturesAt(position,radius)
	local fv = Spring.GetFeaturesInSphere(position.x, position.y, position.z, radius)
	if not fv then return {} end
	local f = {}
	local fCount = 0
	for i=1,#fv do
		fCount = fCount + 1
		f[fCount] = Shard:shardify_feature(fv[i])
	end
	return f
end

function map:SpotCount() -- returns the nubmer of metal spots
	return #self.metalSpots
end

function map:GetSpot(idx) -- returns a Position for the given spot
	return self.metalSpots[idx]
end

function map:GetMetalSpots() -- returns a table of spot positions
	local fv = self.metalSpots
	local f = {}
	local fCount = 0
	for i=1,#fv do
		fCount = fCount + 1
		f[fCount] = fv[i]
	end
	return f
end

function map:GeoCount() -- returns the nubmer of metal spots
	return #self.geoSpots
end

function map:GetGeo(idx)
	return self.geoSpots[idx]
end

function map:GetGeoSpots() -- returns a table of spot positions
	local fv = self.geoSpots
	local f = {}
	local fCount = 0
	for i=1,#fv do
		fCount = fCount + 1
		f[fCount] = fv[i]
	end
	return f
end

function map:MapDimensions() -- returns a Position holding the dimensions of the map
	return {
		x = Game.mapSizeX / 8,
		z = Game.mapSizeZ / 8,
		y = 0
	}
end

function map:MapElmo() -- returns a Position holding the dimensions of the map
	return {
		x = Game.mapSizeX ,
		z = Game.mapSizeZ ,
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

function map:GetGroundHeight(x,z)
	return Spring.GetGroundHeight(x,z)
end

function map:TidalStrength() -- returns tidal strength
	return Game.tidal
end

-- DRAWING FUNCTIONS

function map:DrawRectangle(pos1, pos2, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawAddRectangle')) then
		Script.LuaUI.ShardDrawAddRectangle(pos1.x, pos1.z, pos2.x, pos2.z, {color[1], color[2], color[3], color[4]}, label, filled, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawAddRectangle', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:EraseRectangle(pos1, pos2, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawEraseRectangle')) then
		Script.LuaUI.ShardDrawEraseRectangle(pos1.x, pos1.z, pos2.x, pos2.z, {color[1], color[2], color[3], color[4]}, label, filled, self.ai.game:GetTeamID(), channel)
	end
	--return SendToUnsynced('ShardDrawEraseRectangle', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:DrawCircle(pos, radius, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawAddCircle')) then
		Script.LuaUI.ShardDrawAddCircle(pos.x, pos.z, radius, {color[1], color[2], color[3], color[4]}, label, filled, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawAddCircle', pos.x, pos.z, radius, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:EraseCircle(pos, radius, color, label, filled, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawEraseCircle')) then
		Script.LuaUI.ShardDrawEraseCircle(pos.x, pos.z, radius, {color[1], color[2], color[3], color[4]}, label, filled, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawEraseCircle', pos.x, pos.z, radius, color[1], color[2], color[3], color[4], label, filled, self.ai.game:GetTeamID(), channel)
end

function map:DrawLine(pos1, pos2, color, label, arrow, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawAddLine')) then
		Script.LuaUI.ShardDrawAddLine(pos1.x, pos1.z, pos2.x, pos2.z, {color[1], color[2], color[3], color[4]}, label, arrow, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawAddLine', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, arrow, self.ai.game:GetTeamID(), channel)
end

function map:EraseLine(pos1, pos2, color, label, arrow, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawEraseLine')) then
		Script.LuaUI.ShardDrawEraseLine(pos1.x, pos1.z, pos2.x, pos2.z, {color[1], color[2], color[3], color[4]}, label, arrow, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawEraseLine', pos1.x, pos1.z, pos2.x, pos2.z, color[1], color[2], color[3], color[4], label, arrow, self.ai.game:GetTeamID(), channel)
end

function map:DrawPoint(pos, color, label, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawAddPoint')) then
		Script.LuaUI.ShardDrawAddPoint(pos.x, pos.z, {color[1], color[2], color[3], color[4]}, label, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawAddPoint', pos.x, pos.z, color[1], color[2], color[3], color[4], label, self.ai.game:GetTeamID(), channel)
end

function map:ErasePoint(pos, color, label, channel)
	channel = channel or 1
	color = color or {}
	if (Script.LuaUI('ShardDrawErasePoint')) then
		Script.LuaUI.ShardDrawErasePoint(pos.x, pos.z, {color[1], color[2], color[3], color[4]}, label, self.ai.game:GetTeamID(), channel)
	end
	--SendToUnsynced('ShardDrawErasePoint', pos.x, pos.z, color[1], color[2], color[3], color[4], label, self.ai.game:GetTeamID(), channel)
end

function map:EraseAll(channel)
	channel = channel or 1
	if (Script.LuaUI('ShardDrawClearShapes')) then
		Script.LuaUI.ShardDrawClearShapes(self.ai.game:GetTeamID(), channel)
	end
	--Script.LuaUI.ShardDrawClearShapes(self.ai.game:GetTeamID(), channel)
	--SendToUnsynced('ShardDrawClearShapes', self.ai.game:GetTeamID(), channel)
end

function map:DisplayDrawings(onOff)
	if (Script.LuaUI('ShardDrawDisplay')) then
		Script.LuaUI.ShardDrawDisplay(onOff)
	end
	--SendToUnsynced('ShardDrawDisplay', onOff)
end

function map:SaveTable(tableinput, tablename, filename)
	if (Script.LuaUI('ShardSaveTable')) then
		Script.LuaUI.ShardSaveTable(tableinput, tablename, filename)
	end
	--SendToUnsynced('ShardSaveTable',tableinput, tablename, filename)
end

-- END DRAWING FUNCTIONS

	-- game.map = map
return map
