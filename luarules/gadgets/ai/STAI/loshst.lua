
local DebugDrawEnabled = false


LosHST = class(Module)

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

function LosHST:Name()
	return "LosHST"
end

function LosHST:internalName()
	return "loshst"
end

LosHST.DebugEnabled = false

function LosHST:Init()
	self.losGrid = {}
	self.ai.knownEnemies = {}
	self.ai.knownWrecks = {}
	self.ai.wreckCount = 0
	self.ai.lastLOSUpdate = 0
	self.ai.friendlyTeamID = {}
	self.immobileE = {}
	self.mobileE = {}
	self.draw = {}
	self:Update()
end

function LosHST:Update()
	local f = self.game:Frame()
	if f % 23 == 0 then
		--self.RADAR = scanEnemies2()
        self.ai.friendlyTeamID = {}
        self.ai.friendlyTeamID[self.game:GetTeamID()] = true
        for teamID, _ in pairs(self.ai.alliedTeamIds) do
            self.ai.friendlyTeamID[teamID] = true
        end
		-- update enemy jamming and populate list of enemies
		local enemies = self.game:GetEnemies()

		if enemies ~= nil then
			local enemyList = {}
			for i, e in pairs(enemies) do
				--self:unitLosState(e:ID())
				local uname = e:Name()
				local upos = e:GetPosition()
				-- so that we only have to poll GetEnemies() once
				--enemyList[e:ID()] = { unit = e, unitName = uname, position = upos, unitID = e:ID(), cloaked = e:IsCloaked(), beingBuilt = e:IsBeingBuilt(), health = e:GetHealth(), los = 0 , blip = 0})
 				table.insert(enemyList, { unit = e, unitName = uname, position = upos, unitID = e:ID(), cloaked = e:IsCloaked(), beingBuilt = e:IsBeingBuilt(), health = e:GetHealth(), los = 0 , blip = 0})
			end
			-- update known enemies
			self:UpdateEnemies(enemyList)
		end
		-- update known wrecks
		self:UpdateWrecks()
		self.ai.lastLOSUpdate = f
	end
end

function LosHST:unitLosState(id)
	local guls = Spring.GetUnitLosState(id ,0,true)
--[[int LuaSyncedRead::GetUnitLosState(lua_State* L)
{
    const CUnit* unit = ParseUnit(L, __func__, 1);
    if (unit == nullptr)
        return 0;

    const int allyTeamID = GetEffectiveLosAllyTeam(L, 2);
    unsigned short losStatus;
    if (allyTeamID < 0) {
        losStatus = (allyTeamID == CEventClient::AllAccessTeam) ? (LOS_ALL_MASK_BITS | LOS_ALL_BITS) : 0;
    } else {
        losStatus = unit->losStatus[allyTeamID];
    }

    constexpr int currMask = LOS_INLOS   | LOS_INRADAR;
    constexpr int prevMask = LOS_PREVLOS | LOS_CONTRADAR;

    const bool isTyped = ((losStatus & prevMask) == prevMask);

    if (luaL_optboolean(L, 3, false)) {
        // return a numeric value
        if (!CLuaHandle::GetHandleFullRead(L))
            losStatus &= ((prevMask * isTyped) | currMask);

        lua_pushnumber(L, losStatus);
        return 1;
    }

    lua_createtable(L, 0, 3);
    if (losStatus & LOS_INLOS) {
        HSTR_PUSH_BOOL(L, "los", true);
    }
    if (losStatus & LOS_INRADAR) {
        HSTR_PUSH_BOOL(L, "radar", true);
    }
    if ((losStatus & LOS_INLOS) || isTyped) {
        HSTR_PUSH_BOOL(L, "typed", true);
    }
    return 1;
}
ugh this is nasty
ok raw means it returns number instead of table
so the numeric integer of the mask bits
and I dont think you can get wether a unit is seen in airlos or regular los
its either seen or not
raw is generally preferred, as is much faster in than creating a table
isnt 'typed' meaning that its a radar dot that has been revealed or not?
I definately think so
so if you use raw = true
then result = 15 ( 1 1 1 1 ) means in radar, in los, known unittype
also, if result is > 2, that means that the unitdefID is known
cause the unitdefID of a unit is 'forgotten' if the unit leaves radar
so the key info here is these 4 bits:
I think the bits might be:
bit 0 : LOS_INLOS, unit is in LOS right now,
bit 1 : LOS_INRADAR unit is in radar right now,
bit 2: LOS_PREVLOS unit was in los at least once already, so the unitDefID can be queried
bit 3: LOS_CONTRADAR: unit has had continous radar coverage since it was spotted in LOS]]--

end
function LosHST:scanEnemies2()
	local enemies = self.game:GetEnemies()
	if enemies ~= nil then
		local enemyList = {}
		for i, e in pairs(enemies) do
			local uname = e:Name()
			local upos = e:GetPosition()
			local _,_,_, jammed = Spring.GetPositionLosState(upos.x, upos.y, upos.z, self.ai.allyId) --TEST i think is the reverse thing
			local _inLos, _inAirLos, _inRadar = self:LAR(id)
			-- so that we only have to poll GetEnemies() once
			local specs = self.ai.armyhst.unitTable[uname]
			enemyList[e:ID()] = { 	unit = e,
									unitName = uname,
									position = upos,
									unitID = e:ID(),
									cloaked = e:IsCloaked(),
			                        inJam = jammed,
									beingBuilt = e:IsBeingBuilt(),
									health = e:GetHealth(),
									sighting = 0,
									inAirLos = _inAirLos and specs.mtype == "air" and not cloaked,
									inSurfaceLos = _inLos and pos.y > 0 and not cloaked,
									inSubmergedLos = _inLos and specs.mtype == "sub"and not cloaked,
									inRadar = _inRadar and (not jammed or not cloaked),
			                      }
			local enemy = enemyList[e:ID()]
			enemy.inLos = (_inAirLos or _inLos) and not enemy.cloaked
			enemy.isMobile = (enemy.inLos and specs.speed > 0) or (enemy.inRadar and Spring.GetUnitVelocity(e:ID()))
			enemy.isImmobile = specs.isImmobile
			if (not enemy.inJam and not enemy.cloaked) and enemy.inLos then
				--set last sighting time
				enemy.sighting  =  self.game:Frame()
			end
			if (jammed or cloaked and inRadar) and ( not enemy.inLos  and not enemy.isImmobile) and self.game:Frame() - enemy.sighting > 600 then
				--remove old mobile units dont sight from much time
				enemy = nil
			end
			if enemy.inSurfaceLos then
				e.unit:Internal():DrawHighlight( {100,0,0,100}, 'surf', 9 )
			elseif enemy.inSubmergedLos then
				e.unit:Internal():DrawHighlight( {100,0,0,100}, 'sub', 9 )
			elseif enemy.inRadar then
				e.unit:Internal():DrawHighlight( {0,100,0,100}, 'radar', 9 )
			elseif enemy.inAirLos then
				e.unit:Internal():DrawHighlight( {0,0,100,100}, 'air', 9 )
			elseif enemy.isMobile then
				e.unit:Internal():DrawHighlight( {100,100,100,100}, 'mobile', 9 )
			elseif enemy.isImmobile then
				e.unit:Internal():DrawHighlight( {0,0,0,100}, 'immobile', 9 )
			end
		end
	end
end
function LosHST:LAR(id)
	local inLos = Spring.IsUnitInLos(id, self.ai.allyId)
	local inAirLos = Spring.IsUnitInAirLos(id, self.ai.allyId)
	local inRadar = Spring.IsUnitInRadar(id, self.ai.allyId)
	return inLos , inAirLos, inRadar
end

function LosHST:ScanEnemy(enemies)
	if enemyList == nil then return end
	if #enemyList == 0 then return end
	self.cloaked = {}
	self.jammed = {}

	for id, enemy  in ipairs(enemies) do
		local id = e.unitID
		local ename = e.unitName
		local pos = e.position
		local inLos, inAirLos, inRadar = self:LAR(id)
		local specs = self.ai.armyhst.unitTable[ename]
		if e.cloaked then
			self.enemyCloaked[id] = enemy
		end
		if inJam then
			self.enemyJammed[id] = enemy
		end
		if inAirLos and specs.mtype == "air"  then
			self.enemyAir[id] = enemy
		end
		if inLos then
			if specs.mtype == "sub" or pos.y < 0 then
				enemySub[id] = enemy
			else
				enemyGround[id] = enemy
			end
		end
		if inRadar and not (inLos or inAirLos) then
			if pos.y < 0 then
				self.enemySubRadar[id] = enemy
			else
				self.enemyGroundRadar[id] = enemy
			end
		end
		if specs.speed > 0 then
			self.enemyMobile[id] = enemy
		else
			self.enemyImmobile[id] = enemy
		end

	end
end


function LosHST:UpdateEnemies(enemyList)
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
			local t = {}
			t[2] = Spring.IsUnitInLos(id, self.ai.allyId)
			if Spring.IsUnitInRadar(id, self.ai.allyId) then
				if pos.y < 0 then -- underwater
					t[3] = true
-- 					self.unit:Internal():DrawHighlight( {0,100,0}, id, 9 )--Spring.GetUnitLosState
				else
					t[1] = true
-- 					self.unit:Internal():DrawHighlight( {0,0,0}, id, 9 )
				end
			end
			if Spring.IsUnitInAirLos(id, self.ai.allyId) then
				t[4] = true
			end
			lt = t

			local los = 0
			local persist = false
			local underWater = (self.ai.armyhst.unitTable[ename].mtype == "sub")
			if underWater then
				if lt[3] then
					-- sonar
					los = 2
				end
			else
				if lt[1] and not lt[2] and not self.ai.armyhst.unitTable[ename].stealth then
					los = 1
				elseif lt[2] then
					los = 2
				elseif lt[4] and self.ai.armyhst.unitTable[ename].mtype == "air" then
					self.ai.needAntiAir = true
					-- air los
					los = 2
				end
			end
			if los == 0 and self.ai.armyhst.unitTable[ename].isBuilding then
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
			if self.ai.knownEnemies[id] ~= nil  then
				if known[id] == 2 and self.ai.knownEnemies[id].los == 2 then
				end
			end
		end
	end
	-- remove unit ghosts outside of radar range and building ghosts if they don't exist
	-- this is cheating a little bit, because dead units outside of sight will automatically be removed
	-- also populate moving blips (whether in radar or in sight) for analysis
	local blips = {}
	local f = self.game:Frame()
	for id, e in pairs(self.ai.knownEnemies) do
		if not exists[id] then
			-- enemy died
			if self.ai.IDsWeAreAttacking[id] then
				self.ai.attackhst:TargetDied(self.ai.IDsWeAreAttacking[id])
			end
			if self.ai.IDsWeAreRaiding[id] then
				self.ai.raidhst:TargetDied(self.ai.IDsWeAreRaiding[id])
			end
			self:EchoDebug("enemy " .. e.unitName .. " died!")
			local mtypes = self.ai.tool:UnitWeaponMtypeList(e.unitName)
			for i, mtype in pairs(mtypes) do
				self.ai.raidhst:NeedMore(mtype)
				self.ai.attackhst:NeedLess(mtype)
				if mtype == "air" then self.ai.bomberhst:NeedLess() end
			end
			if DebugDrawEnabled then
				self.map:ErasePoint(nil, nil, id, 3)
			end
			self.ai.knownEnemies[id] = nil
		elseif not known[id] then
			if e.ghost then
				local gpos = e.ghost.position
				if gpos then
					if self:IsInLos(gpos) or self:IsInRadar(gpos) then
						-- the ghost is not where it was last seen, but it's still somewhere
						e.ghost.position = nil
					end
				end
				-- expire ghost
				-- if f > e.ghost.frame + 600 then
					-- self.ai.knownEnemies[id] = nil
				-- end
			else
				e.ghost = { frame = f, position = e.position }
			end
		else
			if not self.ai.armyhst.unitTable[e.unitName].isBuilding then
				local count = true
				if e.los == 2 then
					-- if we know what kind of unit it is, only count as a potential threat blip if it's a hurty unit
					-- air doesn't count because there are no buildings in the air
					local threatLayers = self.ai.tool:UnitThreatRangeLayers(e.unitName)
					if threatLayers.ground.threat == 0 and threatLayers.submerged.threat == 0 then
						count = false
					end
				end
				if count then table.insert(blips, e) end
			end
			e.ghost = nil
		end
	end
	-- send blips off for analysis
	self.ai.tacticalhst:NewEnemyPositions(blips)
end

function LosHST:UpdateWrecks()
	local wrecks = self.map:GetMapFeatures()
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
				if self.ai.armyhst.featureTable[featureName] then
					if self.ai.armyhst.featureTable[featureName].reclaimable then
						okay = true
					end
				else
					for findString, metalValue in pairs(self.ai.armyhst.baseFeatureMetal) do
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



function LosHST:IsInLos(pos)
	return self:GroundLos(pos) == 2
end

function LosHST:IsInRadar(pos)
	return self:GroundLos(pos) == 1
end

function LosHST:IsInSonar(pos)
	return self:GroundLos(pos) == 3
end

function LosHST:IsInAirLos(pos)
	return self:GroundLos(pos) == 4
end

function LosHST:GroundLos(upos)
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
	local gx = math.ceil(upos.x / losGridElmos)
	local gz = math.ceil(upos.z / losGridElmos)
	if self.losGrid[gx] == nil then
		return 0
	elseif self.losGrid[gx][gz] == nil then
		return 0
	else
		if self.ai.maphst:IsUnderWater(upos) then
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

function LosHST:AllLos(upos)
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

function LosHST:IsKnownEnemy(unit)
	local id = unit:ID()
	if self.ai.knownEnemies[id] then
		return self.ai.knownEnemies[id].los
	else
		return 0
	end
end

function LosHST:IsKnownWreck(feature)
	local id = feature:ID()
	if self.ai.knownWrecks[id] then
		return self.ai.knownWrecks[id]
	else
		return 0
	end
end

function LosHST:GhostPosition(unit)
	local id = unit:ID()
	if self.ai.knownEnemies[id] then
		if self.ai.knownEnemies[id].ghost then
			return self.ai.knownEnemies[id].position
		end
	end
	return nil
end

function LosHST:KnowEnemy(unit, los)
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


-- local mapColors = {
-- 	[1] = { 1, 1, 0 },
-- 	[2] = { 0, 0, 1 },
-- 	[3] = { 1, 0, 0 },
-- 	JAM = { 0, 0, 0 },
-- 	known = { 1, 1, 1 },
-- }

-- local function GetColorFromLabel(label)
-- 	local color = mapColors[label] or { 1, 1, 1 }
-- 	color[4] = color[4] or 0.5
-- 	return color
-- end

-- local function PlotDebug(x, z, label)
-- 	if DebugDrawEnabled then
-- 		x = math.ceil(x)
-- 		z = math.ceil(z)
-- 		local pos = api.Position()
-- 		pos.x, pos.z = x, z
-- 		map:DrawPoint(pos, GetColorFromLabel(label), label, 3)
-- 	end
-- end

-- local function PlotSquareDebug(x, z, size, label)
-- 	if DebugDrawEnabled then
-- 		x = math.ceil(x)
-- 		z = math.ceil(z)
-- 		size = math.ceil(size)
-- 		local pos1 = api.Position()
-- 		local pos2 = api.Position()
-- 		local halfSize = size / 2
-- 		pos1.x = x - halfSize
-- 		pos1.z = z - halfSize
-- 		pos2.x = x + halfSize
-- 		pos2.z = z + halfSize
-- 		map:DrawRectangle(pos1, pos2, GetColorFromLabel(label), label, false, 3)
-- 	end
-- end

-- function LosHST:HorizontalLine(x, z, tx, val, jam)
-- 	-- self:EchoDebug("horizontal line from " .. x .. " to " .. tx .. " along z " .. z .. " with value " .. val)
-- 	for ix = x, tx do
-- 		if jam then
-- 			if self.losGrid[ix] == nil then return end
-- 			if self.losGrid[ix][z] == nil then return end
-- 			if DebugDrawEnabled then
-- 				if self.losGrid[ix][z][val] == true then PlotSquareDebug(ix * losGridElmos, z * losGridElmos, losGridElmos, "JAM") end
-- 			end
-- 			if self.losGrid[ix][z][val] then self.losGrid[ix][z][val] = false end
-- 		else
-- 			if self.losGrid[ix] == nil then self.losGrid[ix] = {} end
-- 			if self.losGrid[ix][z] == nil then
-- 				self.losGrid[ix][z] = EmptyLosTable()
-- 			end
-- 			if self.losGrid[ix][z][val] == false and DebugDrawEnabled then PlotSquareDebug(ix * losGridElmos, z * losGridElmos, losGridElmos, val) end
-- 			self.losGrid[ix][z][val] = true
-- 		end
-- 	end
-- end

-- function LosHST:Plot4(cx, cz, x, z, val, jam)
-- 	self:HorizontalLine(cx - x, cz + z, cx + x, val, jam)
-- 	if x ~= 0 and z ~= 0 then
--         self:HorizontalLine(cx - x, cz - z, cx + x, val, jam)
--     end
-- end

-- function LosHST:FillCircle(cx, cz, radius, val, jam)
-- 	-- convert to grid coordinates
-- 	cx = math.ceil(cx / losGridElmos)
-- 	cz = math.ceil(cz / losGridElmos)
-- 	radius = math.floor(radius / losGridElmos)
-- 	if radius > 0 then
-- 		local err = -radius
-- 		local x = radius
-- 		local z = 0
-- 		while x >= z do
-- 	        local lastZ = z
-- 	        err = err + z
-- 	        z = z + 1
-- 	        err = err + z
-- 	        self:Plot4(cx, cz, x, lastZ, val, jam)
-- 	        if err >= 0 then
-- 	            if x ~= lastZ then self:Plot4(cx, cz, lastZ, x, val, jam) end
-- 	            err = err - x
-- 	            x = x - 1
-- 	            err = err - x
-- 	        end
-- 	    end
-- 	end
-- end
