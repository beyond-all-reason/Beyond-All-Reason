local DebugEnabled = false
local DebugDrawEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("LosHandler: " .. inStr)
	end
end

local mapColors = {
	[1] = { 1, 1, 0 },
	[2] = { 0, 0, 1 },
	[3] = { 1, 0, 0 },
	JAM = { 0, 0, 0 },
	known = { 1, 1, 1 },
}

local function GetColorFromLabel(label)
	local color = mapColors[label] or { 1, 1, 1 }
	color[4] = color[4] or 0.5
	return color
end

local function PlotDebug(x, z, label)
	if DebugDrawEnabled then
		x = math.ceil(x)
		z = math.ceil(z)
		local pos = api.Position()
		pos.x, pos.z = x, z
		map:DrawPoint(pos, GetColorFromLabel(label), label, 3)
	end
end

local function PlotSquareDebug(x, z, size, label)
	if DebugDrawEnabled then
		x = math.ceil(x)
		z = math.ceil(z)
		size = math.ceil(size)
		local pos1 = api.Position()
		local pos2 = api.Position()
		local halfSize = size / 2
		pos1.x = x - halfSize
		pos1.z = z - halfSize
		pos2.x = x + halfSize
		pos2.z = z + halfSize
		map:DrawRectangle(pos1, pos2, GetColorFromLabel(label), label, false, 3)
	end
end

LosHandler = class(Module)

local sqrt = math.sqrt
local losGridElmos = 128
local losGridElmosHalf = losGridElmos / 2
local gridSizeX
local gridSizeZ

local function EmptyLosTable()
	local t = {}
	t[1] = false
	t[2] = false
	t[3] = false
	t[4] = false
	return t
end

function LosHandler:Name()
	return "LosHandler"
end

function LosHandler:internalName()
	return "loshandler"
end

function LosHandler:Init()
	self.losGrid = {}
	self.ai.knownEnemies = {}
	self.ai.knownWrecks = {}
	self.ai.wreckCount = 0
	self.ai.lastLOSUpdate = 0
	self.ai.friendlyTeamID = {}
	self:Update()
end

function LosHandler:Update()
	local f = game:Frame()

	if f % 23 == 0 then
		if ShardSpringLua and self.ai.alliedTeamIds then
			self.ai.friendlyTeamID = {}
			self.ai.friendlyTeamID[self.game:GetTeamID()] = true
			for teamID, _ in pairs(self.ai.alliedTeamIds) do
				self.ai.friendlyTeamID[teamID] = true
			end
		else
			-- game:SendToConsole("updating los")
			self.losGrid = {}
			-- note: this could be more effecient by using a behaviour
			-- if the unit is a building, we know it's LOS contribution forever
			-- if the unit moves, the behaviours can be polled rather than GetFriendlies()
			-- except for allies' units
			local friendlies = game:GetFriendlies()
			self.ai.friendlyTeamID = {}
			self.ai.friendlyTeamID[game:GetTeamID()] = true
			if friendlies ~= nil then
				for _, unit in pairs(friendlies) do
					self.ai.friendlyTeamID[unit:Team()] = true -- because I can't get allies' teamIDs directly
					local uname = unit:Name()
					local utable = unitTable[uname]
					local upos = unit:GetPosition()
					if utable.losRadius > 0 then
						self:FillCircle(upos.x, upos.z, utable.losRadius, 2)
					end
					if utable.airLosRadius > 0 then
						-- 4 will become 2 in IsKnownEnemy
						self:FillCircle(upos.x, upos.z, (utable.losRadius + utable.airLosRadius), 4)
					end
					if utable.radarRadius > 0 then
						self:FillCircle(upos.x, upos.z, utable.radarRadius, 1)
					end
					if utable.sonarRadius > 0 then
						-- 3 will become 2 in IsKnownEnemy
						self:FillCircle(upos.x, upos.z, utable.sonarRadius, 3)
					end
				end
			end
		end
		-- update enemy jamming and populate list of enemies
		local enemies = game:GetEnemies()
		if enemies ~= nil then
			local enemyList = {}
			for i, e in pairs(enemies) do
				local uname = e:Name()
				local upos = e:GetPosition()
				if not ShardSpringLua then
					local utable = unitTable[uname]
					if utable.jammerRadius > 0 then
						self:FillCircle(upos.x, upos.z, utable.jammerRadius, 1, true)
					end
				end
				-- so that we only have to poll GetEnemies() once
				table.insert(enemyList, { unit = e, unitName = uname, position = upos, unitID = e:ID(), cloaked = e:IsCloaked(), beingBuilt = e:IsBeingBuilt(), health = e:GetHealth(), los = 0 })
			end
			-- update known enemies
			self:UpdateEnemies(enemyList)
		end
		-- update known wrecks
		self:UpdateWrecks()
		self.ai.lastLOSUpdate = f
	end
end

function LosHandler:UpdateEnemies(enemyList)
	if enemyList == nil then return end
	if #enemyList == 0 then return end
	-- game:SendToConsole("updating known enemies")
	local known = {}
	local exists = {}
	for i, e  in pairs(enemyList) do
		local id = e.unitID
		local ename = e.unitName
		local pos = e.position
		exists[id] = pos
		if not e.cloaked then
			local lt
			if ShardSpringLua then
				local t = {}
				t[2] = Spring.IsUnitInLos(id, self.ai.allyId)
				if Spring.IsUnitInRadar(id, self.ai.allyId) then
					if pos.y < 0 then -- underwater
						t[3] = true
					else
						t[1] = true
					end
				end
				if Spring.IsUnitInAirLos(id, self.ai.allyId) then
					t[4] = true
				end
				lt = t
			else
				lt = self:AllLos(pos)
			end
			local los = 0
			local persist = false
			local underWater = (unitTable[ename].mtype == "sub")
			if underWater then
				if lt[3] then
					-- sonar
					los = 2
				end
			else 
				if lt[1] and not lt[2] and not unitTable[ename].stealth then
					los = 1
				elseif lt[2] then
					los = 2
				elseif lt[4] and unitTable[ename].mtype == "air" then
					-- air los
					los = 2
				end
			end
			if los == 0 and unitTable[ename].isBuilding then
				-- don't remove from knownenemies if it's a building that was once seen
				persist = true
			elseif los == 1 then
				-- don't remove from knownenemies if it's a now blip
				persist = true
			elseif los == 2 then
				known[id] = los
				self.ai.knownEnemies[id] = e
				e.los = los
			end
			if persist == true then
				if self.ai.knownEnemies[id] ~= nil then
					if self.ai.knownEnemies[id].los == 2 then
						known[id] = self.ai.knownEnemies[id].los
					end
				end
			end
			if los == 1 and not known[id] and self.ai.knownEnemies[id] ~= 2 then
				-- don't overwrite seen with radar-seen unless it was previously not known
				self.ai.knownEnemies[id] = e
				e.los = los
				known[id] = los
			end
			if self.ai.knownEnemies[id] ~= nil and DebugDrawEnabled then
				if known[id] == 2 and self.ai.knownEnemies[id].los == 2 then
					e.unit:EraseHighlight({1,0,0}, 'known', 3)
					e.unit:DrawHighlight({1,0,0}, 'known', 3)
					-- self.map:DrawUnit(id, {1,0,0}, 'known', 3)
					-- PlotDebug(pos.x, pos.z, "known")
				end
			end
		end
	end
	-- remove unit ghosts outside of radar range and building ghosts if they don't exist
	-- this is cheating a little bit, because dead units outside of sight will automatically be removed
	-- also populate moving blips (whether in radar or in sight) for analysis
	local blips = {}
	local f = game:Frame()
	for id, e in pairs(self.ai.knownEnemies) do
		if not exists[id] then
			-- enemy died
			if self.ai.IDsWeAreAttacking[id] then
				self.ai.attackhandler:TargetDied(self.ai.IDsWeAreAttacking[id])
			end
			if self.ai.IDsWeAreRaiding[id] then
				self.ai.raidhandler:TargetDied(self.ai.IDsWeAreRaiding[id])
			end
			EchoDebug("enemy " .. e.unitName .. " died!")	
			local mtypes = UnitWeaponMtypeList(e.unitName)
			for i, mtype in pairs(mtypes) do
				self.ai.raidhandler:NeedMore(mtype)
				self.ai.attackhandler:NeedLess(mtype)
				if mtype == "air" then self.ai.bomberhandler:NeedLess() end
			end
			if DebugDrawEnabled then self.map:ErasePoint(nil, nil, id, 3) end
			self.ai.knownEnemies[id] = nil
		elseif not known[id] then
			if e.ghost then
				local gpos = e.ghost.position
				if gpos then
					if self:IsInLos(gpos) or self:IsInRadar(gpos) then
						-- the ghost is not where it was last seen, but it's still somewhere
						e.ghost.position = nil
						if DebugDrawEnabled then self.map:ErasePoint(nil, nil, id, 3) end
					end
				end
				-- expire ghost
				-- if f > e.ghost.frame + 600 then
					-- self.ai.knownEnemies[id] = nil
				-- end
			else
				if DebugDrawEnabled then
					self.map:ErasePoint(nil, nil, id, 3)
					self.map:DrawPoint(e.position, {0.5,0.5,0.5,1}, id, 3)
				end
				e.ghost = { frame = f, position = e.position }
			end
		else
			if not unitTable[e.unitName].isBuilding then
				local count = true
				if e.los == 2 then
					-- if we know what kind of unit it is, only count as a potential threat blip if it's a hurty unit
					-- air doesn't count because there are no buildings in the air
					local threatLayers = UnitThreatRangeLayers(e.unitName)
					if threatLayers.ground.threat == 0 and threatLayers.submerged.threat == 0 then
						count = false
					end
				end
				if count then table.insert(blips, e) end
			end
			if DebugDrawEnabled then self.map:ErasePoint(nil, nil, id, 3) end
			e.ghost = nil
		end
	end
	-- send blips off for analysis
	self.ai.tacticalhandler:NewEnemyPositions(blips)
end

function LosHandler:UpdateWrecks()
	local wrecks = game.map:GetMapFeatures()
	if wrecks == nil then
		self.ai.knownWrecks = {}
		return
	end
	if #wrecks == 0 then
		self.ai.knownWrecks = {}
		return
	end
	-- game:SendToConsole("updating known wrecks")
	local known = {}
	for i, feature  in pairs(wrecks) do
		if feature ~= nil then
			local featureName = feature:Name()
			-- only count features that aren't geovents and that are known to be reclaimable or guessed to be so
			local okay = false
			if featureName ~= "geovent" then -- don't get geo spots
				if featureTable[featureName] then
					if featureTable[featureName].reclaimable then
						okay = true
					end
				else
					for findString, metalValue in pairs(baseFeatureMetal) do
						if string.find(featureName, findString) then
							okay = true
							break
						end
					end
				end
			end
			if okay then
				local position = feature:GetPosition()
				local los = self:GroundLos(position)
				local id = feature:ID()
				local persist = false
				local wreck = { feature = feature, los = los, featureName = featureName, position = position}
				if los == 0 or los == 1 then
					-- don't remove from knownenemies if it was once seen
					persist = true
				elseif los == 2 then
					known[id] = true
					self.ai.knownWrecks[id] = wreck
				end
				if persist == true then
					if self.ai.knownWrecks[id] ~= nil then
						if self.ai.knownWrecks[id].los == 2 then
							known[id] = true
						end
					end
				end
			end
		end
	end
	self.ai.wreckCount = 0
	-- remove wreck ghosts that aren't there anymore
	for id, los in pairs(self.ai.knownWrecks) do
		-- game:SendToConsole("known enemy " .. id .. " " .. los)
		if known[id] == nil then
			-- game:SendToConsole("removed")
			self.ai.knownWrecks[id] = nil
		else
			self.ai.wreckCount = self.ai.wreckCount + 1
		end
	end
	-- cleanup
	known = {}
end

function LosHandler:HorizontalLine(x, z, tx, val, jam)
	-- EchoDebug("horizontal line from " .. x .. " to " .. tx .. " along z " .. z .. " with value " .. val)
	for ix = x, tx do
		if jam then
			if self.losGrid[ix] == nil then return end
			if self.losGrid[ix][z] == nil then return end
			if DebugDrawEnabled then
				if self.losGrid[ix][z][val] == true then PlotSquareDebug(ix * losGridElmos, z * losGridElmos, losGridElmos, "JAM") end
			end
			if self.losGrid[ix][z][val] then self.losGrid[ix][z][val] = false end
		else
			if self.losGrid[ix] == nil then self.losGrid[ix] = {} end
			if self.losGrid[ix][z] == nil then
				self.losGrid[ix][z] = EmptyLosTable()
			end
			if self.losGrid[ix][z][val] == false and DebugDrawEnabled then PlotSquareDebug(ix * losGridElmos, z * losGridElmos, losGridElmos, val) end
			self.losGrid[ix][z][val] = true
		end
	end
end

function LosHandler:Plot4(cx, cz, x, z, val, jam)
	self:HorizontalLine(cx - x, cz + z, cx + x, val, jam)
	if x ~= 0 and z ~= 0 then
        self:HorizontalLine(cx - x, cz - z, cx + x, val, jam)
    end
end

function LosHandler:FillCircle(cx, cz, radius, val, jam)
	-- convert to grid coordinates
	cx = math.ceil(cx / losGridElmos)
	cz = math.ceil(cz / losGridElmos)
	radius = math.floor(radius / losGridElmos)
	if radius > 0 then
		local err = -radius
		local x = radius
		local z = 0
		while x >= z do
	        local lastZ = z
	        err = err + z
	        z = z + 1
	        err = err + z
	        self:Plot4(cx, cz, x, lastZ, val, jam)
	        if err >= 0 then
	            if x ~= lastZ then self:Plot4(cx, cz, lastZ, x, val, jam) end
	            err = err - x
	            x = x - 1
	            err = err - x
	        end
	    end
	end
end

function LosHandler:IsInLos(pos)
	return self:GroundLos(pos) == 2
end

function LosHandler:IsInRadar(pos)
	return self:GroundLos(pos) == 1
end

function LosHandler:IsInSonar(pos)
	return self:GroundLos(pos) == 3
end

function LosHandler:IsInAirLos(pos)
	return self:GroundLos(pos) == 4
end

function LosHandler:GroundLos(upos)
	if ShardSpringLua then
		local LosOrRadar, inLos, inRadar, jammed = Spring.GetPositionLosState(upos.x, upos.y, upos.z, self.ai.allyId)
		if inLos then return 2 end
		if upos.y < 0 then -- underwater
			if inRadar then return 3 end
		end
		if inRadar then return 1 end
		if Spring.IsPosInAirLos(upos.x, upos.y, upos.z, self.ai.allyId) then
			return 4
		else
			return 0
		end
	end
	local gx = math.ceil(upos.x / losGridElmos)
	local gz = math.ceil(upos.z / losGridElmos)
	if self.losGrid[gx] == nil then
		return 0
	elseif self.losGrid[gx][gz] == nil then
		return 0
	else
		if self.ai.maphandler:IsUnderWater(upos) then
			if self.losGrid[gx][gz][3] then
				return 3
			else
				return 0
			end
		elseif self.losGrid[gx][gz][1] and not self.losGrid[gx][gz][2] then
			return 1
		elseif self.losGrid[gx][gz][2] then
			return 2
		else
			return 0
		end
	end
end

function LosHandler:AllLos(upos)
	if ShardSpringLua then
		local t = {}
		local LosOrRadar, inLos, inRadar, jammed = Spring.GetPositionLosState(upos.x, upos.y, upos.z, self.ai.allyId)
		if inLos then t[2] = true end
		if inRadar then
			if upos.y < 0 then -- underwater
				t[3] = true
			else
				t[1] = true
			end
		end
		if Spring.IsPosInAirLos(upos.x, upos.y, upos.z, self.ai.allyId) then
			t[4] = true
		end
		return t
	end
	local gx = math.ceil(upos.x / losGridElmos)
	local gz = math.ceil(upos.z / losGridElmos)
	if self.losGrid[gx] == nil then
		return EmptyLosTable()
	elseif self.losGrid[gx][gz] == nil then
		return EmptyLosTable()
	else
		return self.losGrid[gx][gz]
	end
end

function LosHandler:IsKnownEnemy(unit)
	local id = unit:ID()
	if self.ai.knownEnemies[id] then
		return self.ai.knownEnemies[id].los
	else
		return 0
	end
end

function LosHandler:IsKnownWreck(feature)
	local id = feature:ID()
	if self.ai.knownWrecks[id] then
		return self.ai.knownWrecks[id]
	else
		return 0
	end
end

function LosHandler:GhostPosition(unit)
	local id = unit:ID()
	if self.ai.knownEnemies[id] then
		if self.ai.knownEnemies[id].ghost then
			return self.ai.knownEnemies[id].position
		end
	end
	return nil
end

function LosHandler:KnowEnemy(unit, los)
	los = los or 2
	local knownEnemy = self.ai.knownEnemies[unit:ID()]
	if knownEnemy and knownEnemy.los >= los then
		return
	end
	local upos = unit:GetPosition()
	if not upos or not upos.x then
		return
	end
	local enemy = { unit = unit, unitName = unit:Name(), position = upos, unitID = unit:ID(), cloaked = unit:IsCloaked(), beingBuilt = unit:IsBeingBuilt(), health = unit:GetHealth(), los = los }
	self.ai.knownEnemies[unit:ID()] = enemy
end