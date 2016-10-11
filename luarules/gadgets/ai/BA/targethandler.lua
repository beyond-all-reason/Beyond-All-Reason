TargetHandler = class(Module)

function TargetHandler:Name()
	return "TargetHandler"
end

function TargetHandler:internalName()
	return "targethandler"
end

local DebugDrawEnabled = false

local mSqrt = math.sqrt
local mFloor = math.floor
local mCeil = math.ceil

local function PlotSquareDebug(x, z, size, color, label, filled)
	if DebugDrawEnabled then
		x = mCeil(x)
		z = mCeil(z)
		size = mCeil(size)
		local halfSize = size / 2
		local pos1, pos2 = api.Position(), api.Position()
		pos1.x, pos1.z = x - halfSize, z - halfSize
		pos2.x, pos2.z = x + halfSize, z + halfSize
		map:DrawRectangle(pos1, pos2, color, label, filled, 8)
	end
end

local function dist2d(x1, z1, x2, z2)
	local xd = x1 - x2
	local yd = z1 - z2
	local dist = mSqrt(xd*xd + yd*yd)
	return dist
end

local cellElmos = 256
local cellElmosHalf = cellElmos / 2
local threatTypes = { "ground", "air", "submerged" }
local threatTypesAsKeys = { ground = true, air = true, submerged = true }
local baseUnitThreat = 0 -- 150
local baseUnitRange = 0 -- 250
local unseenMetalGeoValue = 50
local baseBuildingValue = 150
local bomberExplosionValue = 2000
local vulnerableHealth = 400
local wreckMult = 100
local vulnerableReclaimDistMod = 100
local badCellThreat = 300
local attackDistMult = 0.5 -- between 0 and 1, the lower number, the less distance matters
local reclaimModMult = 0.5 -- how much does the cell's metal & energy modify the distance to the cell for reclaim cells

local factoryValue = 1000
local conValue = 300
local techValue = 50
local energyOutValue = 2
local minNukeValue = factoryValue + techValue + 500

local feintRepeatMod = 25

local unitValue = {}

local function NewCell(px, pz)
	local values = {
	ground = {ground = 0, air = 0, submerged = 0, value = 0},
	air = {ground = 0, air = 0, submerged = 0, value = 0},
	submerged = {ground = 0, air = 0, submerged = 0, value = 0},
	} -- value to our units first to who can be hurt by those things, then to those who have those kinds of weapons
	-- [GAS].value is just everything that doesn't hurt that kind of thing 
	local targets = { ground = {}, air = {}, submerged = {}, } -- just one target for each [GAS][hurtGAS]
	local vulnerables = { ground = {}, air = {}, submerged = {}, } -- just one vulnerable for each [GAS][hurtGAS]
	local threat = { ground = 0, air = 0, submerged = 0 } -- threats (including buildings) by what they hurt
	local response = { ground = 0, air = 0, submerged = 0 } -- count mobile threat by what can hurt it
	local preresponse = { ground = 0, air = 0, submerged = 0 } -- count where mobile threat will probably be by what can hurt it 
	local x = px * cellElmos - cellElmosHalf
	local z = pz * cellElmos - cellElmosHalf
	local position = api.Position()
	position.x, position.z = x, z
	position.y = 0
	if ShardSpringLua then
		position.y = Spring.GetGroundHeight(x, z)
	end
	local newcell = { value = 0, explosionValue = 0, values = values, threat = threat, response = response, buildingIDs = {}, targets = targets, vulnerables = vulnerables, resurrectables = {}, reclaimables = {}, lastDisarmThreat = 0, metal = 0, energy = 0, x = px, z = pz, pos = position }
	return newcell
end

local function Value(unitName)
	local v = unitValue[unitName]
	if v then return v end
	local utable = unitTable[unitName]
	if not utable then return 0 end
	local val = utable.metalCost + (utable.techLevel * techValue)
	if utable.buildOptions ~= nil then
		if utable.isBuilding then
			-- factory
			val = val + factoryValue
		else
			-- construction unit
			val = val + conValue
		end
	end
	if utable.extractsMetal > 0 then
		val = val + 800000 * utable.extractsMetal
	end
	if utable.totalEnergyOut > 0 then
		val = val + (utable.totalEnergyOut * energyOutValue)
	end
	unitValue[unitName] = val
	return val
end

-- need to change because: amphibs can't be hurt by non-submerged threats in water, and can't be hurt by anything but ground on land
local function CellValueThreat(unitName, cell)
	if cell == nil then return 0, 0 end
	local gas, weapons
	if unitName == "ALL" then
		gas = threatTypesAsKeys
		weapons = threatTypes
		unitName = "nothing"
	else
		gas = WhatHurtsUnit(unitName, nil, cell.pos)
		weapons = UnitWeaponLayerList(unitName)
	end
	local threat = 0
	local value = 0
	local notThreat = 0
	for i = 1, #threatTypes do
		local GAS = threatTypes[i]
		local yes = gas[GAS]
		if yes then
			threat = threat + cell.threat[GAS]
			for i, weaponGAS in pairs(weapons) do
				value = value + cell.values[GAS][weaponGAS]
			end
		elseif raiderDisarms[unitName] then
			notThreat = notThreat + cell.threat[GAS]
		end
	end
	if gas.air and raiderList[unitName] and not raiderDisarms[unitName] then
		threat = threat + cell.threat.ground * 0.1
	end
	if raiderDisarms[unitName] then
		value = notThreat
		-- if notThreat == 0 then value = 0 end
	end
	return value, threat, gas
end

local function GetCellPosition(pos)
	local px = mCeil(pos.x / cellElmos)
	local pz = mCeil(pos.z / cellElmos)
	return px, pz
end

function TargetHandler:Init()
	self.DebugEnabled = false

	self.enemyAlreadyCounted = {}
	self.currentEnemyThreatCount = 0
	self.currentEnemyImmobileThreatCount = 0
	self.currentEnemyMobileThreatCount = 0
	self.cells = {}
	self.cellList = {}
	self.badPositions = {}
	self.dangers = {}

	self.ai.enemyMexSpots = {}
	self.ai.totalEnemyThreat = 10000
	self.ai.totalEnemyImmobileThreat = 5000
	self.ai.totalEnemyMobileThreat = 5000
	self.ai.needGroundDefense = true
	self.ai.areLandTargets = true
	self.ai.canNuke = true
	self:InitializeDangers()
	self.lastEnemyThreatUpdateFrame = 0
	self.feints = {}
	self.raiderCounted = {}
	self.lastUpdateFrame = 0
	self.pathModifierFuncs = {}
end

function TargetHandler:GetCellHere(pos)
	local px, pz = GetCellPosition(pos)
	if self.cells[px] then
		return self.cells[px][pz], px, pz
	end
end

function TargetHandler:GetOrCreateCellHere(pos)
	local px, pz = GetCellPosition(pos)
	if self.cells[px] == nil then self.cells[px] = {} end
	if self.cells[px][pz] == nil then
		local cell = NewCell(px, pz)
		cell.pos = pos
		self.cells[px][pz] = cell
		table.insert(self.cellList, cell)
		return cell
	end
	return self.cells[px][pz]
end

function TargetHandler:HorizontalLine(x, z, tx, threatResponse, groundAirSubmerged, val)
	-- self:EchoDebug("horizontal line from " .. x .. " to " .. tx .. " along z " .. z .. " with value " .. val .. " in " .. groundAirSubmerged)
	for ix = x, tx do
		if self.cells[ix] == nil then self.cells[ix] = {} end
		if self.cells[ix][z] == nil then
			-- self:EchoDebug("new cell" .. ix .. "," .. z)
			self.cells[ix][z] = NewCell(ix, z)
		end
		self.cells[ix][z][threatResponse][groundAirSubmerged] = self.cells[ix][z][threatResponse][groundAirSubmerged] + val
	end
end

function TargetHandler:Plot4(cx, cz, x, z, threatResponse, groundAirSubmerged, val)
	self:HorizontalLine(cx - x, cz + z, cx + x, threatResponse, groundAirSubmerged, val)
	if x ~= 0 and z ~= 0 then
        self:HorizontalLine(cx - x, cz - z, cx + x, threatResponse, groundAirSubmerged, val)
    end
end 

function TargetHandler:FillCircle(cx, cz, radius, threatResponse, groundAirSubmerged, val)
	local radius = mCeil(radius / cellElmos)
	if radius > 0 then
		local err = -radius
		local x = radius
		local z = 0
		while x >= z do
	        local lastZ = z
	        err = err + z
	        z = z + 1
	        err = err + z
	        self:Plot4(cx, cz, x, lastZ, threatResponse, groundAirSubmerged, val)
	        if err >= 0 then
	            if x ~= lastZ then self:Plot4(cx, cz, lastZ, x, threatResponse, groundAirSubmerged, val) end
	            err = err - x
	            x = x - 1
	            err = err - x
	        end
	    end
	end
end

function TargetHandler:CheckHorizontalLine(x, z, tx, threatResponse, groundAirSubmerged)
	-- self:EchoDebug("horizontal line from " .. x .. " to " .. tx .. " along z " .. z .. " in " .. groundAirSubmerged)
	local value = 0
	local threat = 0
	for ix = x, tx do
		if self.cells[ix] ~= nil then
			if self.cells[ix][z] ~= nil then
				local cell = self.cells[ix][z]
				local value = cell.values[groundAirSubmerged].value -- can't hurt it
				local threat = cell[threatResponse][groundAirSubmerged]
				return value, threat
			end
		end
	end
	return value, threat
end

function TargetHandler:Check4(cx, cz, x, z, threatResponse, groundAirSubmerged)
	local value = 0
	local threat = 0
	local v, t = self:CheckHorizontalLine(cx - x, cz + z, cx + x, threatResponse, groundAirSubmerged)
	value = value + v
	threat = threat + t
	if x ~= 0 and z ~= 0 then
        local v, t = self:CheckHorizontalLine(cx - x, cz - z, cx + x, threatResponse, groundAirSubmerged)
        value = value + v
        threat = threat + t
    end
    return value, threat
end 

function TargetHandler:CheckInRadius(cx, cz, radius, threatResponse, groundAirSubmerged)
	local radius = mCeil(radius / cellElmos)
	local value = 0
	local threat = 0
	if radius > 0 then
		local err = -radius
		local x = radius
		local z = 0
		while x >= z do
	        local lastZ = z
	        err = err + z
	        z = z + 1
	        err = err + z
	        local v, t = self:Check4(cx, cz, x, lastZ, threatResponse, groundAirSubmerged)
	        value = value + v
	        threat = threat + t
	        if err >= 0 then
	            if x ~= lastZ then
	            	local v, t = self:Check4(cx, cz, lastZ, x, threatResponse, groundAirSubmerged)
	            	value = value + v
	       			threat = threat + t
	            end
	            err = err - x
	            x = x - 1
	            err = err - x
	        end
	    end
	end
	return value, threat
end

function TargetHandler:CountEnemyThreat(unitID, unitName, threat)
	if not self.enemyAlreadyCounted[unitID] then
		self.currentEnemyThreatCount = self.currentEnemyThreatCount + threat
		if unitTable[unitName].isBuilding then
			self.currentEnemyImmobileThreatCount = self.currentEnemyImmobileThreatCount + threat
		else
			self.currentEnemyMobileThreatCount = self.currentEnemyMobileThreatCount + threat
		end
		self.enemyAlreadyCounted[unitID] = true
	end
end

function TargetHandler:CountDanger(layer, id)
	local danger = self.dangers[layer]
	if not danger.alreadyCounted[id] then
		danger.count = danger.count + 1
		self:EchoDebug("spotted " .. layer .. " threat")
		danger.alreadyCounted[id] = true
	end
end

function TargetHandler:DangerCheck(unitName, unitID)
	local un = unitName
	local ut = unitTable[un]
	local id = unitID
	if ut.isBuilding then
		if ut.needsWater then
			self:CountDanger("watertarget", id)
		else
			self:CountDanger("landtarget", id)
		end
	end
	if not ut.isBuilding and not commanderList[un] and ut.mtype ~= "air" and ut.mtype ~= "sub" and ut.groundRange > 0 then
		self:CountDanger("ground", id)
	elseif groundFacList[un] then
		self:CountDanger("ground", id)
	end
	if ut.mtype == "air" and ut.groundRange > 0 then
		self:CountDanger("air", id)
	elseif airFacList[un] then
		self:CountDanger("air", id)
	end
	if (ut.mtype == "sub" or ut.mtype == "shp") and ut.isWeapon and not ut.isBuilding then
		self:CountDanger("submerged", id)
	elseif subFacList[un] then
		self:CountDanger("submerged", id)
	end
	if bigPlasmaList[un] then
		self:CountDanger("plasma", id)
	end
	if nukeList[un] then
		self:CountDanger("nuke", id)
	end
	if antinukeList[un] then
		self:CountDanger("antinuke", id)
	end
	if ut.mtype ~= "air" and ut.mtype ~= "sub" and ut.groundRange > 1000 then
		self:CountDanger("longrange", id)
	end
end

local function NewDangerLayer()
	return { count = 0, alreadyCounted = {}, present = false, obsolesce = 0, threshold = 1, duration = 1800, }
end

function TargetHandler:InitializeDangers()
	self.dangers = {}
	self.dangers["watertarget"] = NewDangerLayer()
	self.dangers["landtarget"] = NewDangerLayer()
	self.dangers["landtarget"].duration = 2400
	self.dangers["landtarget"].present = true
	self.dangers["landtarget"].obsolesce = game:Frame() + 5400
	self.dangers["ground"] = NewDangerLayer()
	self.dangers["ground"].duration = 2400 -- keep ground threat alive for one and a half minutes
	-- assume there are ground threats for the first three minutes
	self.dangers["ground"].present = true
	self.dangers["ground"].obsolesce = game:Frame() + 5400
	self.dangers["air"] = NewDangerLayer()
	self.dangers["submerged"] = NewDangerLayer()
	self.dangers["plasma"] = NewDangerLayer()
	self.dangers["nuke"] = NewDangerLayer()
	self.dangers["antinuke"] = NewDangerLayer()
	self.dangers["longrange"] = NewDangerLayer()
end

function TargetHandler:UpdateDangers()
	local f = game:Frame()

	for layer, danger in pairs(self.dangers) do
		if danger.count >= danger.threshold then
			danger.present = true
			danger.obsolesce = f + danger.duration
			danger.count = 0
			danger.alreadyCounted = {}
			self:EchoDebug(layer .. " danger present")
		elseif danger.present and f >= danger.obsolesce then
			self:EchoDebug(layer .. " obsolete")
			danger.present = false
		end
	end

	self.ai.areWaterTargets = self.dangers.watertarget.present
	self.ai.areLandTargets = self.dangers.landtarget.present or not self.dangers.watertarget.present
	self.ai.needGroundDefense = self.dangers.ground.present or (not self.dangers.air.present and not self.dangers.submerged.present) -- don't turn off ground defense if there aren't air or submerged self.dangers
	self.ai.needAirDefense = self.dangers.air.present
	self.ai.needSubmergedDefense = self.dangers.submerged.present
	self.ai.needShields = self.dangers.plasma.present
	self.ai.needAntinuke = self.dangers.nuke.present
	self.ai.canNuke = not self.dangers.antinuke.present
	self.ai.needJammers = self.dangers.longrange.present or self.dangers.air.present or self.dangers.nuke.present or self.dangers.plasma.present
end

function TargetHandler:UpdateEnemies()
	self.ai.enemyMexSpots = {}
	-- where is/are the party/parties tonight?
	local highestValue = minNukeValue
	local highestValueCell
	for unitID, e in pairs(self.ai.knownEnemies) do
		local los = e.los
		local ghost = e.ghost
		local name = e.unitName
		local ut = unitTable[name]
		if ghost and not ghost.position and not e.beingBuilt then
			-- count ghosts with unknown positions as non-positioned threats
			self:DangerCheck(name, e.unitID)
			local threatLayers = UnitThreatRangeLayers(name)
			for groundAirSubmerged, layer in pairs(threatLayers) do
				self:CountEnemyThreat(e.unitID, name, layer.threat)
			end
		elseif (los ~= 0 or (ghost and ghost.position)) and not e.beingBuilt then
			-- count those we know about and that aren't being built
			local pos
			if ghost then pos = ghost.position else pos = e.position end
			local px, pz = GetCellPosition(pos)
			if self.cells[px] == nil then
				self.cells[px] = {}
			end
			if self.cells[px][pz] == nil then
				self.cells[px][pz] = NewCell(px, pz)
				table.insert(self.cellList, self.cells[px][pz])
			end
			cell = self.cells[px][pz]
			if los == 1 then
				if ut.isBuilding then
					cell.value = cell.value + baseBuildingValue
				else
					-- if it moves, assume it's out to get you
					self:FillCircle(px, pz, baseUnitRange, "threat", "ground", baseUnitThreat)
					self:FillCircle(px, pz, baseUnitRange, "threat", "air", baseUnitThreat)
					self:FillCircle(px, pz, baseUnitRange, "threat", "submerged", baseUnitThreat)
				end
			elseif los == 2 then
				local mtype = ut.mtype
				self:DangerCheck(name, e.unitID)
				local value = Value(name)
				if unitTable[name].extractsMetal ~= 0 then
					table.insert(self.ai.enemyMexSpots, { position = pos, unit = e })
				end
				if unitTable[name].isBuilding then
					table.insert(cell.buildingIDs, e.unitID)
				end
				local hurtBy = WhatHurtsUnit(name)
				local threatLayers = UnitThreatRangeLayers(name)
				local threatToTurtles = threatLayers.ground.threat + threatLayers.submerged.threat
				local maxRange = max(threatLayers.ground.range, threatLayers.submerged.range)
				for groundAirSubmerged, layer in pairs(threatLayers) do
					if threatToTurtles ~= 0 and hurtBy[groundAirSubmerged] then
						self:FillCircle(px, pz, maxRange, "response", groundAirSubmerged, threatToTurtles)
					end
					local threat, range = layer.threat, layer.range
					if mtype == "air" and groundAirSubmerged == "ground" or groundAirSubmerged == "submerged" then threat = 0 end -- because air units are pointless to run from
					if threat ~= 0 then
						self:FillCircle(px, pz, range, "threat", groundAirSubmerged, threat)
						self:CountEnemyThreat(e.unitID, name, threat)
					elseif mtype ~= "air" then -- air units are too hard to attack
						local health = e.health
						for hurtGAS, hit in pairs(hurtBy) do
							cell.values[groundAirSubmerged][hurtGAS] = cell.values[groundAirSubmerged][hurtGAS] + value
							if cell.targets[groundAirSubmerged][hurtGAS] == nil then
								cell.targets[groundAirSubmerged][hurtGAS] = e
							else
								if value > Value(cell.targets[groundAirSubmerged][hurtGAS].unitName) then
									cell.targets[groundAirSubmerged][hurtGAS] = e
								end
							end
							if health < vulnerableHealth then
								cell.vulnerables[groundAirSubmerged][hurtGAS] = e
							end
							if groundAirSubmerged == "air" and hurtGAS == "ground" and threatLayers.ground.threat > cell.lastDisarmThreat then
								cell.disarmTarget = e
								cell.lastDisarmThreat = threatLayers.ground.threat
							end
						end
						if ut.bigExplosion then
							cell.explosionValue = cell.explosionValue + bomberExplosionValue
							if cell.explosiveTarget == nil then
								cell.explosiveTarget = e
							else
								if value > Value(cell.explosiveTarget.unitName) then
									cell.explosiveTarget = e
								end
							end
						end
					end
				end
				cell.value = cell.value + value
				if cell.value > highestValue then
					highestValue = cell.value
					highestValueCell = cell
				end
		end
			-- we dont want to target the center of the cell encase its a ledge with nothing
			-- on it etc so target this units position instead
			cell.pos = pos
		end
	end
	if highestValueCell then
		self.enemyBaseCell = highestValueCell
		self.ai.enemyBasePosition = highestValueCell.pos
	else
		self.enemyBaseCell = nil
		self.ai.enemyBasePosition = nil
	end
end

function TargetHandler:UpdateDamagedUnits()
	for unitID, engineUnit in pairs(self.ai.damagehandler:GetDamagedUnits()) do
		local cell = self:GetOrCreateCellHere(engineUnit:GetPosition())
		cell.damagedUnits = cell.damagedUnits or {}
		cell.damagedUnits[#cell.damagedUnits+1] = engineUnit
	end
end

function TargetHandler:UpdateMetalGeoSpots()
	local spots = self.ai.scoutSpots.air[1]
	local fromGAS = {"ground", "air", "submerged"}
	local toGAS = {"ground", "submerged"}
	for i = 1, #spots do
		local spot = spots[i]
		if not self.ai.loshandler:IsInLos(spot) then
			local cell = self:GetOrCreateCellHere(spot)
			-- cell.value = cell.value + unseenMetalGeoValue
			local underwater = self.ai.maphandler:IsUnderWater(spot)
			for i = 1, #fromGAS do
				local fgas = fromGAS[i]
				if not underwater or fgas ~= 'submerged' then
					cell.values[fgas] = cell.values[fgas] or {}
					for ii = 1, #toGAS do
						local tgas = toGAS[ii]
						if not underwater or tgas == 'submerged' then
							cell.values[fgas][tgas] = (cell.values[fgas][tgas] or 0) + unseenMetalGeoValue
						end
					end
				end
			end
		end
	end
end

function TargetHandler:UpdateBadPositions()
	local f = game:Frame()
	for i = #self.badPositions, 1, -1 do
		local r = self.badPositions[i]
		if self.cells[r.px] then
			cell = self.cells[r.px][r.pz]
			if cell then
				cell.threat[r.groundAirSubmerged] = cell.threat[r.groundAirSubmerged] + r.threat
			end
		end
		if f > r.frame + r.duration then
			-- remove bad positions after 1 minute
			table.remove(self.badPositions, i)
		end
	end
end

function TargetHandler:UpdateWrecks()
	-- figure out where all the wrecks are
	for id, w in pairs(self.ai.knownWrecks) do
		-- will need to check if reclaimer can get to wreck later
		local pos = w.position
		local cell = self:GetOrCreateCellHere(pos)
		local wname = w.featureName
		local ftable = featureTable[wname]
		if ftable ~= nil then
			cell.metal = cell.metal + ftable.metal
			cell.energy = cell.energy + ftable.energy
			local unitName = ftable.unitName
			if unitName ~= nil then
				w.unitName = unitName
				local rut = unitTable[unitName]
				if not commanderList[unitName] and rut.speed > 0 and rut.metalCost < 2000 then
					table.insert(cell.resurrectables, w)
				end
			end
			if ftable.metal > 0 then
				table.insert(cell.reclaimables, w)
			end
		else
			for findString, metalValue in pairs(baseFeatureMetal) do
				if string.find(wname, findString) then
					cell.metal = cell.metal + metalValue
					break
				end
			end
			if metalValue > 0 then
				table.insert(cell.reclaimables, w)
			end
		end
	end
end

function TargetHandler:UpdateFronts(number)
	local highestCells = {}
	local highestResponses = {}
	for n = 1, number do
		local highestCell = {}
		local highestResponse = { ground = 0, air = 0, submerged = 0 }
		for i = 1, #self.cellList do
			local cell = self.cellList[i]
			for groundAirSubmerged, response in pairs(cell.response) do
				local okay = true
				if n > 1 then
					local highCell = highestCells[n-1][groundAirSubmerged]
					if highCell ~= nil then
						if cell == highCell then
							okay = false
						elseif response >= highestResponses[n-1][groundAirSubmerged] then
							okay = false
						else
							local dist = DistanceXZ(highCell.x, highCell.z, cell.x, cell.z)
							if dist < 2 then okay = false end
						end
					end
				end
				if okay and response > highestResponse[groundAirSubmerged] then
					highestResponse[groundAirSubmerged] = response
					highestCell[groundAirSubmerged] = cell
				end
			end
		end
		highestResponses[n] = highestResponse
		highestCells[n] = highestCell
	end
	self.ai.defendhandler:FindFronts(highestCells)
end

function TargetHandler:UpdateDebug()
	if DebugDrawEnabled then
		map:EraseRectangle(nil, nil, nil, nil, true, 8)
		map:EraseRectangle(nil, nil, nil, nil, false, 8)
		local maxThreat = 0
		local maxValue = 0
		for cx, czz in pairs(self.cells) do
			for cz, cell in pairs(czz) do
				local value, threat = CellValueThreat("ALL", cell)
				if threat > maxThreat then maxThreat = threat end
				if value > maxValue then maxValue = value end
			end
		end
		for cx, czz in pairs(self.cells) do
			for cz, cell in pairs(czz) do
				local x = cell.x * cellElmos - cellElmosHalf
				local z = cell.z * cellElmos - cellElmosHalf
				local value, threat = CellValueThreat("ALL", cell)
				if value > 0 then
					local g = value / maxValue
					local b = 1 - g
					PlotSquareDebug(x, z, cellElmos, {0,g,b}, tostring(value), false)
				end
				if threat > 0 then
					local g = 1 - (threat / maxThreat)
					PlotSquareDebug(x, z, cellElmos, {1,g,0}, tostring(threat), true)
				end
			end
		end
	end
end

function TargetHandler:UnitDamaged(unit, attacker, damage)
	-- even if the attacker can't be seen, human players know what weapons look like
	-- in non-lua shard, the attacker is nil if it's an enemy unit, so this becomes useless
	if attacker ~= nil and self.ai.loshandler:IsKnownEnemy(attacker) ~= 2 then
		self:DangerCheck(attacker:Name(), attacker:ID())
		local mtype
		local ut = unitTable[unit:Name()]
		if ut then
			local threat = damage
			local aut = unitTable[attacker:Name()]
			if aut then
				if aut.isBuilding then
					self.ai.loshandler:KnowEnemy(attacker)
					return
				end
				threat = aut.metalCost
			end
			self:AddBadPosition(unit:GetPosition(), ut.mtype, threat, 900)
		end
	end
end

function TargetHandler:Update()
	local f = game:Frame()
	if f > self.lastEnemyThreatUpdateFrame + 1800 or self.lastEnemyThreatUpdateFrame == 0 then
		-- store and reset the threat count
		-- self:EchoDebug(self.currentEnemyThreatCount .. " enemy threat last 2000 frames")
		self:EchoDebug(self.currentEnemyThreatCount)
		self.ai.totalEnemyThreat = self.currentEnemyThreatCount
		self.ai.totalEnemyImmobileThreat = self.currentEnemyImmobileThreatCount
		self.ai.totalEnemyMobileThreat = self.currentEnemyMobileThreatCount
		self.currentEnemyThreatCount = 0
		self.currentEnemyImmobileThreatCount = 0
		self.currentEnemyMobileThreatCount = 0
		self.enemyAlreadyCounted = {}
		self.lastEnemyThreatUpdateFrame = f
	end
end

function TargetHandler:AddBadPosition(position, mtype, threat, duration)
	threat = threat or badCellThreat
	duration = duration or 1800
	local px, pz = GetCellPosition(position)
	local gas = WhatHurtsUnit(nil, mtype, position)
	local f = game:Frame()
	for groundAirSubmerged, yes in pairs(gas) do
		if yes then
			local newRecord =
			{
				px = px,
				pz = pz,
				groundAirSubmerged = groundAirSubmerged,
				frame = f,
				threat = threat,
				duration = duration,
			}
			table.insert(self.badPositions, newRecord)
		end
	end
end

function TargetHandler:UpdateMap()
	if self.ai.lastLOSUpdate > self.lastUpdateFrame then
		-- game:SendToConsole("before target update", collectgarbage("count")/1024)
		self.raiderCounted = {}
		self.cells = {}
		self.cellList = {}
		self:UpdateEnemies()
		self:UpdateDangers()
		self:UpdateBadPositions()
		self:UpdateWrecks()
		self:UpdateDamagedUnits()
		-- self:UpdateMetalGeoSpots()
		self:UpdateFronts(3)
		self:UpdateDebug()
		self.lastUpdateFrame = game:Frame()
		-- game:SendToConsole("after target update", collectgarbage("count")/1024)
		-- collectgarbage()
		-- game:SendToConsole("after collectgarbage", collectgarbage("count")/1024)
	end
end

local function CellVulnerable(cell, hurtByGAS, weaponsGAS)
	hurtByGAS = hurtByGAS or threatTypesAsKeys
	weaponsGAS = weaponsGAS or threatTypes
	if cell == nil then return end
	for GAS, yes in pairs(hurtByGAS) do
		for i, wGAS in pairs(weaponsGAS) do
			local vulnerable = cell.vulnerables[GAS][wGAS]
			if vulnerable ~= nil then return vulnerable end
		end
	end
end

function TargetHandler:NearbyVulnerable(unit)
	if unit == nil then return end
	self:UpdateMap()
	local position = unit:GetPosition()
	local px, pz = GetCellPosition(position)
	local unitName = unit:Name()
	local gas = WhatHurtsUnit(unitName, nil, position)
	local weapons = UnitWeaponLayerList(unitName)
	-- check this cell
	local vulnerable = nil
	if self.cells[px] ~= nil then
		if self.cells[px][pz] ~= nil then
			vulnerable = CellVulnerable(self.cells[px][pz], gas, weapons)
		end
	end
	-- check adjacent self.cells
	if vulnerable == nil then
		for ix = px - 1, px + 1 do
			for iz = pz - 1, pz + 1 do
				if self.cells[ix] ~= nil then
					if self.cells[ix][iz] ~= nil then
						vulnerable = CellVulnerable(self.cells[ix][iz], gas, weapons)
						if vulnerable then break end
					end
				end
			end
			if vulnerable then break end
		end
	end
	return vulnerable
end

function TargetHandler:GetBestRaidCell(representative)
	if not representative then return end
	self:UpdateMap()
	local rpos = representative:GetPosition()
	local inCell = self:GetCellHere(rpos)
	local threatReduction = 0
	if inCell ~= nil then
		-- if we're near more raiders, these raiders can target more threatening targets together
		if inCell.raiderHere then threatReduction = threatReduction + inCell.raiderHere end
		if inCell.raiderAdjacent then threatReduction = threatReduction + inCell.raiderAdjacent end
	end
	local rname = representative:Name()
	local maxThreat = baseUnitThreat
	local rthreat, rrange = ThreatRange(rname)
	self:EchoDebug(rname .. ": " .. rthreat .. " " .. rrange)
	if rthreat > maxThreat then maxThreat = rthreat end
	local best
	local bestDist = 99999
	local cells
	for i, cell in pairs(self.cellList) do
		local value, threat, gas = CellValueThreat(rname, cell)
		-- cells with other raiders in or nearby are better places to go for raiders
		if cell.raiderHere then threat = threat - cell.raiderHere end
		if cell.raiderAdjacent then threat = threat - cell.raiderAdjacent end
		threat = threat - threatReduction
		if value > 0 and threat <= maxThreat then
			if self.ai.maphandler:UnitCanGoHere(representative, cell.pos) then
				local mod = value - (threat * 3)
				local dist = Distance(rpos, cell.pos) - mod
				if dist < bestDist then
					best = cell
					bestDist = dist
				end
			end
		end
	end
	return best
end

function TargetHandler:RaidableCell(representative, position)
	position = position or representative:GetPosition()
	local cell = self:GetCellHere(position)
	if not cell or cell.value == 0 then return end
	local value, threat, gas = CellValueThreat(rname, cell)
	-- cells with other raiders in or nearby are better places to go for raiders
	if cell.raiderHere then threat = threat - cell.raiderHere end
	if cell.raiderAdjacent then threat = threat - cell.raiderAdjacent end
	local rname = representative:Name()
	local maxThreat = baseUnitThreat
	local rthreat, rrange = ThreatRange(rname)
	self:EchoDebug(rname .. ": " .. rthreat .. " " .. rrange)
	if rthreat > maxThreat then maxThreat = rthreat end
	-- self:EchoDebug(value .. " " .. threat)
	if threat <= maxThreat then
		return cell
	end
end

function TargetHandler:GetBestAttackCell(representative, position, ourThreat)
	if not representative then return end
	position = position or representative:GetPosition()
	self:UpdateMap()
	local bestValueCell
	local bestValue = -999999
	local bestAnyValueCell
	local bestAnyValue = -999999
	local bestThreatCell
	local bestThreat = 0
	local name = representative:Name()
	local longrange = unitTable[name].groundRange > 1000
	local mtype = unitTable[name].mtype
	ourThreat = ourThreat or unitTable[name].metalCost * self.ai.attackhandler:GetCounter(mtype)
	if mtype ~= "sub" and longrange then longrange = true end
	local possibilities = {}
	local highestDist = 0
	local lowestDist = 100000
	for i, cell in pairs(self.cellList) do
		if cell.pos then
			if self.ai.maphandler:UnitCanGoHere(representative, cell.pos) or longrange then
				local value, threat = CellValueThreat(name, cell)
				local dist = Distance(position, cell.pos)
				if dist > highestDist then highestDist = dist end
				if dist < lowestDist then lowestDist = dist end
				table.insert(possibilities, { cell = cell, value = value, threat = threat, dist = dist })
			end
		end
	end
	local distRange = highestDist - lowestDist
	for i, pb in pairs(possibilities) do
		local fraction = 1.5 - ((pb.dist - lowestDist) / distRange)
		local value = pb.value * fraction
		local threat = pb.threat * fraction
		if pb.value > 750 then
			value = value - (threat * 0.5)
			if value > bestValue then
				bestValueCell = pb.cell
				bestValue = value
			end
		elseif pb.value > 0 then
			value = value - (threat * 0.5)
			if value > bestAnyValue then
				bestAnyValueCell = pb.cell
				bestAnyValue = value
			end
		else
			if threat > bestThreat then
				bestThreatCell = pb.cell
				bestThreat = threat
			end
		end
	end
	local best
	if bestValueCell then
		best = bestValueCell
	elseif self.enemyBaseCell then
		best = self.enemyBaseCell
	elseif bestAnyValueCell then
		best = bestAnyValueCell
	elseif bestThreatCell then
		best = bestThreatCell
	elseif self.lastAttackCell then
		best = self.lastAttackCell
	end
	self.lastAttackCell = best
	return best
end

function TargetHandler:GetNearestAttackCell(representative, position, ourThreat)
	if not representative then return end
	position = position or representative:GetPosition()
	self:UpdateMap()
	local name = representative:Name()
	local longrange = unitTable[name].groundRange > 1000
	local mtype = unitTable[name].mtype
	ourThreat = ourThreat or unitTable[name].metalCost * self.ai.attackhandler:GetCounter(mtype)
	if mtype ~= "sub" and longrange then longrange = true end
	local lowestDistValueable
	local lowestDistThreatening
	local closestValuableCell
	local closestThreateningCell
	for i, cell in pairs(self.cellList) do
		if cell.pos then
			if self.ai.maphandler:UnitCanGoHere(representative, cell.pos) or longrange then
				local value, threat = CellValueThreat(name, cell)
				if threat <= ourThreat * 0.67 then
					if value > 0 then
						local dist = Distance(position, cell.pos)
						if not lowestDistValueable or dist < lowestDistValueable then
							lowestDistValueable = dist
							closestValuableCell = cell
						end
					elseif threat > 0 then
						local dist = Distance(position, cell.pos)
						if not lowestDistThreatening or dist < lowestDistThreatening then
							lowestDistThreatening = dist
							closestThreateningCell = cell
						end
					end
				end
			end
		end
	end
	return closestValuableCell or closestThreateningCell
end

function TargetHandler:GetBestNukeCell()
	self:UpdateMap()
	if self.enemyBaseCell then return self.enemyBaseCell end
	local best
	local bestValueThreat = 0
	for i, cell in pairs(self.cellList) do
		if cell.pos then
			local value, threat = CellValueThreat("ALL", cell)
			if value > minNukeValue then
				local valuethreat = value + threat
				if valuethreat > bestValueThreat then
					best = cell
					bestValueThreat = valuethreat
				end
			end
		end
	end
	return best, bestValueThreat
end

function TargetHandler:GetBestBombardCell(position, range, minValueThreat, ignoreValue, ignoreThreat)
	if ignoreValue and ignoreThreat then
		game:SendToConsole("trying to find a place to bombard but ignoring both value and threat doesn't work")
		return
	end
	self:UpdateMap()
	if self.enemyBaseCell and not ignoreValue then
		local dist = Distance(position, self.enemyBaseCell.pos)
		if dist < range then
			local value = self.enemyBaseCell.values.ground.ground + self.enemyBaseCell.values.air.ground + self.enemyBaseCell.values.submerged.ground
			return self.enemyBaseCell, value + self.enemyBaseCell.response.ground
		end
	end
	local best
	local bestValueThreat = 0
	if minValueThreat then bestValueThreat = minValueThreat end
	for i, cell in pairs(self.cellList) do
		if #cell.buildingIDs > 0 then
			local dist = Distance(position, cell.pos)
			if dist < range then
				local value = cell.values.ground.ground + cell.values.air.ground + cell.values.submerged.ground
				local valuethreat = 0
				if not ignoreValue then valuethreat = valuethreat + value end
				if not ignoreThreat then valuethreat = valuethreat + cell.response.ground end
				if valuethreat > bestValueThreat then
					best = cell
					bestValueThreat = valuethreat
				end
			end
		end
	end
	if best then
		local bestBuildingID, bestBuildingVT
		for i, buildingID in pairs(best.buildingIDs) do
			local building = game:GetUnitByID(buildingID)
			if building then
				local uname = building:Name()
				local value = Value(uname)
				local threat = ThreatRange(uname, "ground") + ThreatRange(uname, "air")
				local valueThreat = value + threat
				if not bestBuildingVT or valueThreat > bestBuildingVT then
					bestBuildingVT = valueThreat
					bestBuildingID = buildingID
				end
			end
		end
	end
	return best, bestValueThreat, bestBuildingID
end

function TargetHandler:GetBestBomberTarget(torpedo)
	self:UpdateMap()
	local best
	local bestValue = 0
	for i, cell in pairs(self.cellList) do
		local value = cell.explosionValue
		if torpedo then
			value = value + cell.values.air.submerged
		else
			value = value + cell.values.air.ground
		end
		if value > 0 then
			value = value - cell.threat.air
			if value > bestValue then
				best = cell
				bestValue = value
			end
		end
	end
	if best then
		local bestTarget
		bestValue = 0
		local target = best.explosiveTarget
		if target == nil then
			if torpedo then
				target = best.targets.air.submerged.unit
			else
				target = best.targets.air.ground.unit
			end
		end
		return target
	end
end

function TargetHandler:GetBestReclaimCell(representative, lookForEnergy)
	self:UpdateMap()
	local rpos = representative:GetPosition()
	local rname = representative:Name()
	local best
	local bestDist = 99999
	local bestVulnerable
	for i, cell in pairs(self.cellList) do
		local value, threat, gas = CellValueThreat(rname, cell)
		if threat == 0 and cell.pos then
			local canGo = self.ai.maphandler:UnitCanGoHere(representative, cell.pos)
			if not canGo then
				self:EchoDebug("can't get to reclaim cell, trying nearby")
				-- check nearby positions, because sometimes the commander is underwater in a crater but can still be reclaimed
				for angle = halfPi, twicePi, halfPi do
					local nearPos = RandomAway(cell.pos, 110, nil, angle)
					canGo = self.ai.maphandler:UnitCanGoHere(representative, nearPos)
					if canGo then
						self:EchoDebug("found accessible position near reclaim cell")
						break
					end
				end
			end
			if canGo then
				local mod = 0
				if #cell.reclaimables > 0 then
					if lookForEnergy then
						mod = cell.energy
					else
						mod = cell.metal
					end
				end
				local vulnerable = CellVulnerable(cell, gas, representative.canReclaimGAS)
				if vulnerable then mod = mod + vulnerableReclaimDistMod end
				if mod > 0 then
					local dist = Distance(rpos, cell.pos) - (mod * reclaimModMult)
					if dist < bestDist then
						best = cell
						bestDist = dist
						bestVulnerable = vulnerable
					end
				end
			end
		end
	end
	return best, bestVulnerable
end

function TargetHandler:WreckToResurrect(representative, alsoDamagedUnits)
	if not representative then return end
	self:UpdateMap()
	local rpos = representative:GetPosition()
	local rname = representative:Name()
	local best
	local bestDist = 99999
	for i, cell in pairs(self.cellList) do
		if #cell.resurrectables ~= 0 or (alsoDamagedUnits and cell.damagedUnits and #cell.damagedUnits > 0) then
			local value, threat, gas = CellValueThreat(rname, cell)
			if threat == 0 and cell.pos then
				if self.ai.maphandler:UnitCanGoHere(representative, cell.pos) then
					local dist = Distance(rpos, cell.pos)
					if dist < bestDist then
						best = cell
						bestDist = dist
					end
				end
			end
		end
	end
	if best then
		self:EchoDebug("got wreck to resurrect")
		if alsoDamagedUnits and best.damagedUnits and #best.damagedUnits > 0 then
			local bestUnit
			local bestHealth
			local damaged = best.damagedUnits
			for i = 1, #damaged do
				local engUnit = damaged[i]
				local health = engUnit:GetHealth() / engUnit:GetMaxHealth()
				if not bestHealth or health < bestHealth then
					bestHealth = health
					bestUnit = engUnit
				end
			end
			if bestUnit then
				return bestUnit, best
			end
		end
		local bestWreck
		local bestMetalCost = 0
		for i, w in pairs(best.resurrectables) do
			if w ~= nil then
				local wname = w.featureName
				if wname ~= nil then
					local ft = featureTable[wname]
					if ft ~= nil then
						local ut = unitTable[ft.unitName]
						if ut ~= nil then
							local metalCost = ut.metalCost
							if metalCost > bestMetalCost then
								bestWreck = w
								bestMetalCost = metalCost
							end
						end
					end
				end
			end
		end
		return bestWreck, best
	else
		return nil, self:NearestVulnerableCell(representative)
	end
end

function TargetHandler:NearestVulnerableCell(representative)
	if representative == nil then return end
	self:UpdateMap()
	local rpos = representative:GetPosition()
	local rname = representative:Name()
	local best
	local bestDist = 99999
	local weapons = UnitWeaponLayerList(rname)
	for i, cell in pairs(self.cellList) do
		local value, threat, gas = CellValueThreat(rname, cell)
		if threat == 0 and cell.pos then
			if self.ai.maphandler:UnitCanGoHere(representative, cell.pos) then
				if CellVulnerable(cell, gas, weapons) ~= nil then
					local dist = Distance(rpos, cell.pos)
					if dist < bestDist then
						best = cell
						bestDist = dist
					end
				end
			end
		end
	end
	return best
end

function TargetHandler:IsBombardPosition(position, unitName)
	self:UpdateMap()
	local px, pz = GetCellPosition(position)
	local radius = unitTable[unitName].groundRange
	local groundValue, groundThreat = self:CheckInRadius(px, pz, radius, "threat", "ground")
	if groundValue + groundThreat > Value(unitName) * 1.5 then
		return true
	else
		return false
	end
end

function TargetHandler:ValueHere(position, unitOrName)
	self:UpdateMap()
	if unitOrName == nil then
		game:SendToConsole("nil unit or name given to ThreatHere")
		return
	end
	local uname
	if type(unitOrName) == 'string' then
		uname = unitOrName
	else
		uname = unitOrName:Name()
	end
	if uname == nil then
		game:SendToConsole("nil unit name give nto ThreatHere")
		return
	end
	local cell, px, pz = self:GetCellHere(position)
	if cell == nil then return 0, nil, uname end
	local value, _ = CellValueThreat(uname, cell)
	return value, cell, uname
end

function TargetHandler:ThreatHere(position, unitOrName, adjacent)
	self:UpdateMap()
	if unitOrName == nil then
		game:SendToConsole("nil unit or name given to ThreatHere")
		return
	end
	local uname
	if type(unitOrName) == 'string' then
		uname = unitOrName
	else
		uname = unitOrName:Name()
	end
	if uname == nil then
		game:SendToConsole("nil unit name give nto ThreatHere")
		return
	end
	local cell, px, pz = self:GetCellHere(position)
	if cell == nil then return 0, nil, uname end
	local value, threat = CellValueThreat(uname, cell)
	if adjacent then
		for cx = px-1, px+1 do
			if self.cells[cx] then
				for cz = pz-1, pz+1 do
					if not (cx == px and cz == pz) then
						local c = self.cells[cx][cz]
						if c then
							local cvalue, cthreat = CellValueThreat(uname, c)
							threat = threat + cthreat
						end
					end
				end
			end
		end
	end
	return threat, cell, uname
end


function TargetHandler:IsSafePosition(position, unit, threshold, adjacent)
	local threat, cell, uname = self:ThreatHere(position, unit, adjacent)
	if not cell then
		return true
	end
	if threshold then
		return threat < unitTable[uname].metalCost * threshold, cell.response
	else
		return threat == 0, cell.response
	end
end

function TargetHandler:GetPathModifierFunc(unitName, adjacent)
	if self.pathModifierFuncs[unitName] then
		return self.pathModifierFuncs[unitName]
	end
	local divisor = unitTable[unitName].metalCost / 40
	local modifier_node_func = function ( node, distanceToGoal, distanceStartToGoal )
		local threatMod = self:ThreatHere(node.position, unitName, adjacent) / divisor
		if distanceToGoal then
			if distanceToGoal <= 500 then
				return 0
			else
				return threatMod * ((distanceToGoal  - 500) / 1000)
			end
		else
			return threatMod
		end
	end
	self.pathModifierFuncs[unitName] = modifier_node_func
	return modifier_node_func
end

-- for on-the-fly enemy evasion
function TargetHandler:BestAdjacentPosition(unit, targetPosition)
	local position = unit:GetPosition()
	local px, pz = GetCellPosition(position)
	local tx, tz = GetCellPosition(targetPosition)
	if px >= tx - 1 and px <= tx + 1 and pz >= tz - 1 and pz <= tz + 1 then
		-- if we're already in the target cell or adjacent to it, keep moving
		return nil, true
	end
	self:UpdateMap()
	local bestDist = 20000
	local best
	local notsafe = false
	local uname = unit:Name()
	local f = game:Frame()
	local maxThreat = baseUnitThreat
	local uthreat, urange = ThreatRange(uname)
	self:EchoDebug(uname .. ": " .. uthreat .. " " .. urange)
	if uthreat > maxThreat then maxThreat = uthreat end
	local doubleUnitRange = urange * 2
	for x = px - 1, px + 1 do
		for z = pz - 1, pz + 1 do
			if x == px and z == pz then
				-- don't move to the cell you're already in
			else
				local dist = dist2d(tx, tz, x, z) * cellElmos
				if self.cells[x] ~= nil then
					if self.cells[x][z] ~= nil then
						local value, threat = CellValueThreat(uname, self.cells[x][z])
						if raiderList[uname] then
							-- self.cells with other raiders in or nearby are better places to go for raiders
							if self.cells[x][z].raiderHere then threat = threat - self.cells[x][z].raiderHere end
							if self.cells[x][z].raiderAdjacent then threat = threat - self.cells[x][z].raiderAdjacent end
						end
						if threat > maxThreat then
							-- if it's below baseUnitThreat, it's probably a lone construction unit
							dist = dist + threat
							notsafe = true
						end
					end
				end
				-- if we just went to the same place, probably not a great place
				for i = #self.feints, 1, -1 do
					local feint = self.feints[i]
					if f > feint.frame + 900 then
						-- expire stored after 30 seconds
						table.remove(self.feints, i)
					elseif feint.x == x and feint.z == z and feint.px == px and feint.pz == pz and feint.tx == tx and feint.tz == tz then
						dist = dist + feintRepeatMod
					end
				end
				if dist < bestDist then
					bestDist = dist
					if self.cells[x] == nil then self.cells[x] = {} end
					if self.cells[x][z] == nil then
						self.cells[x][z] = NewCell(x, z)
					end
					if self.cells[x][z].pos == nil then
						self.cells[x][z].pos = api.Position()
						self.cells[x][z].pos.x = x * cellElmos - cellElmosHalf
						self.cells[x][z].pos.z = z * cellElmos - cellElmosHalf
						self.cells[x][z].pos.y = 0
					end
					if self.ai.maphandler:UnitCanGoHere(unit, self.cells[x][z].pos) then
						best = self.cells[x][z]
					end
				end
			end
		end
	end
	if best and notsafe then
		local mtype = unitTable[uname].mtype
		self:AddBadPosition(targetPosition, mtype, 16, 1200) -- every thing to avoid on the way to the target increases its threat a tiny bit
		table.insert(self.feints, {x = best.x, z = best.z, px = px, pz = pz, tx = tx, tz = tz, frame = f})
		return best.pos
	end
end

function TargetHandler:RaiderHere(raidbehaviour)
	if raidbehaviour == nil then return end
	if raidbehaviour.unit == nil then return end
	if self.raiderCounted[raidbehaviour.id] then return end
	local unit = raidbehaviour.unit:Internal()
	if unit == nil then return end
	local uthreat, urange = ThreatRange(unit:Name())
	local position = unit:GetPosition()
	local px, pz = GetCellPosition(position)
	local inCell
	if self.cells[px] then
		inCell = self.cells[px][pz]
	end
	if inCell ~= nil then
		if inCell.raiderHere == nil then inCell.raiderHere = 0 end
		inCell.raiderHere = inCell.raiderHere + (uthreat * 0.67)
	end
	local adjacentThreatReduction = uthreat * 0.33
	for x = px - 1, px + 1 do
		if self.cells[x] ~= nil then
			for z = pz - 1, pz + 1 do
				if x == px and z == pz then
					-- ignore center cell
				else
					local cell = self.cells[x][z]
					if cell ~= nil then
						if cell.raiderAdjacent == nil then cell.raiderAdjacent = 0 end
						cell.raiderAdjacent = cell.raiderAdjacent + adjacentThreatReduction
					end
				end
			end
		end
	end
	self.raiderCounted[raidbehaviour.id] = true -- reset with UpdateMap()
end

-- so that reclaimers don't try to reclaim a cell with nothing in it
function TargetHandler:RemoveFeature(feature, position)
	local px, pz = GetCellPosition(position)
	local cell
	if self.cells[px] then
		cell = self.cells[px][pz]
	end
	if not cell then
		return
	end
	for i = #cell.reclaimables, 1, -1 do
		local recFeature = cell.reclaimables[i].feature
		if recFeature == feature then
			table.remove(cell.reclaimables, i)
			return true
		end
	end
	for i = #cell.resurrectables, 1, -1 do
		local resFeature = cell.resurrectables[i].feature
		if resFeature == feature then
			table.remove(cell.resurrectables, i)
			return true
		end
	end
end