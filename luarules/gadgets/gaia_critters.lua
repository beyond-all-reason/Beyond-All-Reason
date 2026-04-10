local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
    	name      = "gaia critter units",
    	desc      = "units spawn and wander around the map",
    	author    = "Floris (original: knorke, 2013)",
    	date      = "2016",
		license   = "GNU GPL, v2 or later",
    	layer     = -100, --negative, otherwise critters spawned by gadget do not disappear on death (spawned with /give they always die)
    	enabled   = true,
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then
	return false
end

local isCritter = {}
local isCommander = {}
local isFlyingCritter = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if string.sub(unitDef.name, 1, 7) == "critter" then
		isCritter[unitDefID] = true
		if unitDef.canFly then
			isFlyingCritter[unitDefID] = true
		end
	elseif unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local removeCritters		= true		-- gradually remove critters when unitcont gets higher
local addCrittersAgain		= true		-- re-add the removed critters again

local minTotalUnits			= 3000					-- starting removing critters at this total unit count
local maxTotalunits			= 6000				-- finished removing critters at this total unit count
local minimumCritters		= 0.2					-- dont remove further than (0.1 == 10%) of critters
local minCritters				-- dont remove below this amount
local companionRadiusStart		= 140					-- if mapcritter is spawned this close it will be converted to companion critter
local companionRadiusAfterStart = 13
local companionPatrolRadius = 200

local amountMultiplier = SpringShared.GetModOptions().critters
local minMulti = 0.2
local maxMulti = 5

local GaiaTeamID  = SpringShared.GetGaiaTeamID()

local critterConfig = include("LuaRules/configs/critters.lua")
local critterUnits = {}	--critter units that are currently alive
local critterBackup = {} --critter units to restore
local companionCritters = {}
local sceduledOrders = {}
local commanders = {}

local GetGroundHeight = SpringShared.GetGroundHeight
local GetUnitPosition = SpringShared.GetUnitPosition
local GetUnitDefID = SpringShared.GetUnitDefID
local GiveOrderToUnit = SpringSynced.GiveOrderToUnit
local CreateUnit = SpringSynced.CreateUnit
local GetUnitTeam = SpringShared.GetUnitTeam
local ValidUnitID = SpringShared.ValidUnitID

local random = math.random
local floor = math.floor
local ceil = math.ceil
local sin, cos, abs, rad = math.sin, math.cos, math.abs, math.rad
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
local CMD_PATROL = CMD.PATROL
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_ATTACK = CMD.ATTACK

minCritters = ceil((Game.mapSizeX*Game.mapSizeZ)/6000000)

local totalCritters = 0
local aliveCritters = 0
local companionRadius = companionRadiusStart
local processOrders = true
local addedInitialCritters

local ownCritterDestroy = false

local function randomPatrolInBox(unitID, box, minWaterDepth)	-- only define minWaterDepth if unit is a submarine
	local ux,_,uz = GetUnitPosition(unitID,true,true)
	local orders = 6
	local attempts = orders
	local ordersGiven = 0

	local x,z
	local modifiers = {}
	local box_x1, box_x2, box_z1, box_z2 = box.x1, box.x2, box.z1, box.z2
	if minWaterDepth ~= nil then
		attempts = 150
		local waterRadius = 1000		-- max distance a submarine unit will travel
		local x1 = ux - waterRadius
		if x1 < box_x1 then x1 = box_x1 end
		local x2 = ux + waterRadius
		if x2 > box_x2 then x2 = box_x2 end
		local z1 = uz - waterRadius
		if z1 < box_z1 then z1 = box_z1 end
		local z2 = uz + waterRadius
		if z2 > box_z2 then z2 = box_z2 end
		box_x1, box_x2, box_z1, box_z2 = x1, x2, z1, z2
	end
	for i=1,attempts do
		x = random(box_x1, box_x2)
		z = random(box_z1, box_z2)
		if x > 0 and z > 0 and x < mapSizeX and z < mapSizeZ then
			local y = GetGroundHeight(x, z)
			if minWaterDepth == nil or y < minWaterDepth then
				if sceduledOrders[unitID] == nil then
					sceduledOrders[unitID] = {}
				end
				processOrders = true
				sceduledOrders[unitID][#sceduledOrders[unitID]+1] = {unitID=unitID, type=CMD_PATROL, location={x, y, z}, modifiers=modifiers}
				--table.insert(sceduledOrders[unitID], {unitID=unitID, type=CMD_PATROL, location={x, y, z}, modifiers=modifiers})
				modifiers = {"shift"}
				ordersGiven = ordersGiven + 1
			end
		end
		if ordersGiven == orders then break end
	end
end

local function in_circle(center_x, center_y, radius, x, y)
	local square_dist = ((center_x - x) * (center_x - x)) + ((center_y - y) * (center_y - y))
	return square_dist <= radius * radius
end

-- doing multiple orders per unit gives errors, so doing 1 per gameframe is best
local function processSceduledOrders()
	processOrders = false
	local orders = 0
	local removeUnits
	local removeUnitsCount = 0
	for unitID, UnitOrders in pairs(sceduledOrders) do
		if not ValidUnitID(unitID) then
			if not removeUnits then removeUnits = {} end
			removeUnitsCount = removeUnitsCount + 1
			removeUnits[removeUnitsCount] = unitID
		else
			orders = 0
			local removeOrder
			for oid, order in pairs(UnitOrders) do
				GiveOrderToUnit(unitID, order.type, order.location, order.modifiers)
				removeOrder = oid
				orders = orders + 1
				processOrders = true
				break
			end
			if removeOrder then
				sceduledOrders[unitID][removeOrder] = nil
			elseif orders == 0 then
				if not removeUnits then removeUnits = {} end
				removeUnitsCount = removeUnitsCount + 1
				removeUnits[removeUnitsCount] = unitID
			end
		end
	end
	for i = 1, removeUnitsCount do
		sceduledOrders[removeUnits[i]] = nil
	end
end

local function randomPatrolInCircle(unitID, ux, uz, ur, minWaterDepth)	-- only define minWaterDepth if unit is a submarine
	local orders = 6
	local attempts = orders
	local ordersGiven = 0
	local modifiers = {}
	if minWaterDepth ~= nil then
		local waterRadius = 1000		-- max distance a submarine unit will travel
		attempts = 150
		if waterRadius <= ur then
			ux, _, uz = GetUnitPosition(unitID, true, true)
			ur = waterRadius
		end
	end
	for i=1,attempts do
		local a = rad(random(0, 360))
		local r = random(0, ur)
		local x = ux + r*sin(a)
		local z = uz + r*cos(a)
		if x > 0 and z > 0 and x < mapSizeX and z < mapSizeZ then
			local y = GetGroundHeight(x, z)
			if minWaterDepth == nil or y < minWaterDepth then
				if sceduledOrders[unitID] == nil then
					sceduledOrders[unitID] = {}
				end
				sceduledOrders[unitID][#sceduledOrders[unitID]+1] = {unitID=unitID, type=CMD_PATROL, location={x, y, z}, modifiers=modifiers}
				modifiers = {"shift"}
				processOrders = true
				ordersGiven = ordersGiven + 1
			end
		end
		if ordersGiven == orders then break end
	end
end

local function setGaiaUnitSpecifics(unitID)
	SpringSynced.SetUnitNeutral(unitID, true)
	SpringUnsynced.SetUnitNoSelect(unitID, true)
	SpringSynced.SetUnitStealth(unitID, true)
	SpringUnsynced.SetUnitNoMinimap(unitID, true)
	SpringSynced.SetUnitMaxHealth(unitID, 2)
	SpringSynced.SetUnitBlocking(unitID, false)
	SpringSynced.SetUnitSensorRadius(unitID, 'los', 0)
	SpringSynced.SetUnitSensorRadius(unitID, 'airLos', 0)
	SpringSynced.SetUnitSensorRadius(unitID, 'radar', 0)
	SpringSynced.SetUnitSensorRadius(unitID, 'sonar', 0)
	for weaponID, _ in pairs(UnitDefs[GetUnitDefID(unitID)].weapons) do
		GiveOrderToUnit(unitID, CMD_FIRE_STATE, {0}, 0)
		--Spring.UnitWeaponHoldFire(unitID, weaponID)		-- doesnt seem to work :S (maybe because they still patrol)
	end
end

local function makeUnitCritter(unitID)
	setGaiaUnitSpecifics(unitID)
	critterUnits[unitID] = {}
	totalCritters = totalCritters + 1
	aliveCritters = aliveCritters + 1
end


local mapConfig

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
	local allUnits = SpringShared.GetAllUnits()
	for _, unitID in pairs(allUnits) do
		local unitDefID = GetUnitDefID(unitID)
		if unitDefID and isCommander[unitDefID] then
			local x,_,z = GetUnitPosition(unitID)
			commanders[unitID] = {x,z}
		end
	end

	local mapname = Game.mapName:lower()
	for name, config in pairs(critterConfig) do
		if string.find(mapname, name, 1, true) then
			mapConfig = config
			break
		end
	end

	if amountMultiplier == 0 then
		SpringShared.Echo("[Gaia Critters] Critters disabled via ModOption")
		gadgetHandler:RemoveGadget(self)
	end

	SpringShared.Echo("[Gaia Critters] gadget:Initialize() Game.mapName=" .. Game.mapName)
	if mapConfig then
		SpringShared.Echo("[Gaia Critters] No critter config for this map")
		--gadgetHandler:RemoveGadget(self)		-- disabled so if you /give critters they still will be auto patrolled
	end

	if amountMultiplier < minMulti then amountMultiplier = minMulti end
	if amountMultiplier > maxMulti then amountMultiplier = maxMulti end
end

local unitDefNameToID = {}
for udid, unitDef in pairs(UnitDefs) do
	unitDefNameToID[unitDef.name] = udid
end

local function getUnitDefIdbyName(unitName)
	return unitDefNameToID[unitName]
end

-- excluding gaia units
local function getTotalUnits()
	local totalUnits = 0
	local teamList = SpringShared.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= GaiaTeamID then
			totalUnits = totalUnits + SpringShared.GetTeamUnitCount(teamID)
		end
	end
	return totalUnits
end

local function adjustCritters(newAliveCritters)
	if newAliveCritters == aliveCritters then return end

	local critterDifference = newAliveCritters - aliveCritters
	local add = false
	local critterArrayFrom = critterUnits
	if critterDifference > 0 then
		add = true
		critterArrayFrom = critterBackup
		if not addCrittersAgain then return end
	end

	local changed = false
	for unitID, critter in pairs(critterArrayFrom) do
		if add then
			if critter.x ~= nil and critter.y ~= nil and critter.z ~= nil then	-- had nil error once so yeah...
				CreateUnit(critter.unitName, critter.x, critter.y, critter.z, 0, GaiaTeamID)
				critterDifference = critterDifference - 1
				critterArrayFrom[unitID] = nil
				totalCritters = totalCritters - 1 -- CreateUnit adds 1 here but we want to keep it constant
				changed = true
			end
		else
			local x,y,z = GetUnitPosition(unitID,true,true)
			critterDifference = critterDifference + 1

			critterBackup[unitID] = critter
			critterBackup[unitID].x = x
			critterBackup[unitID].y = y
			critterBackup[unitID].z = z

			SpringSynced.DestroyUnit(unitID, false, true)	-- reclaimed
			totalCritters = totalCritters + 1 -- DestroyUnit callin substracts 1 here but we want to keep it constant, so re-adding

			changed = true
			if aliveCritters <= minCritters then break end
		end
		if critterDifference > -1 and critterDifference < 1  then break end
	end
	if changed then
		--if totalCritters > 800 then		-- occasional cleanup (leaving this in will make ´critterDifference´ useless)
		local newCritterUnits = {}
		for unitID, critter in pairs(critterArrayFrom) do
			if critter ~= nil then
				newCritterUnits[unitID] = critter
			end
		end
		if add then
			critterBackup = newCritterUnits
		else
			critterUnits = newCritterUnits
		end
		--end
	end
end

local function nearUnits(x, z, radius, units)
	for unitID, pos in pairs(units) do
		if pos[1] and pos[2] then	-- had nil error once so yeah...
			if abs(x-pos[1]) < radius and abs(z-pos[2]) < radius then
				return unitID
			end
		end
	end
	return false
end

local function pairCompanionToUnit(companionID,unitID)
	local companions = companionCritters[unitID] or {}
	companions[#companions+1] = companionID
	companionCritters[unitID] = companions
	if critterUnits[unitID] ~= nil then
		critterUnits[unitID] = nil
		totalCritters = totalCritters - 1
	end
end

local function critterToCompanion(unitID)
	local x,y,z = GetUnitPosition(unitID)
	if x ~= nil and y ~= nil and z ~= nil then	-- had nil error once so yeah...
		local commanderID = nearUnits(x, z, companionRadius, commanders)
		if commanderID ~= false then
			pairCompanionToUnit(unitID,commanderID)
		end
	end
end

local function convertMapCrittersToCompanion()
	for unitID, critter in pairs(critterUnits) do
		if critter and not companionCritters[unitID] then
			critterToCompanion(unitID)
		end
	end
end

-- add map dependent critters
local function addMapCritters()
	if mapConfig == nil then
		return
	end

	for key, cC in pairs(mapConfig) do
		if cC.spawnBox then
			for unitName, unitAmount in pairs(cC.unitNames) do
				local unitDefID = getUnitDefIdbyName(unitName)
				if not UnitDefs[unitDefID] then
					break
				end
				local minWaterDepth = 0 - UnitDefs[unitDefID].minWaterDepth
				local waterunit = false
				if minWaterDepth < 0 then waterunit = true end

				-- to make sure at least 1 critter is placed  (to prevent when the multiplier is small, that a small critter-amount always gets diminished to zero)
				local amount = unitAmount * amountMultiplier
				if amount > 0 and amount < 1 then amount = 1 end
				amount = round(amount)

				for i=1, amount do
					local unitID = nil
					local x = random(cC.spawnBox.x1, cC.spawnBox.x2)
					local z = random(cC.spawnBox.z1, cC.spawnBox.z2)
					local y = GetGroundHeight(x, z)
					if not waterunit or cC.nowatercheck ~= nil or y < minWaterDepth then
						local supplyMinWaterDepth = nil
						if waterunit and not cC.nowatercheck then
							supplyMinWaterDepth = minWaterDepth
						end
						unitID = CreateUnit(unitName, x, y, z, 0, GaiaTeamID)
						if unitID then
							randomPatrolInBox(unitID, cC.spawnBox, supplyMinWaterDepth)
							--makeUnitCritter(unitID)
							critterUnits[unitID].unitName = unitName
						else
							SpringShared.Echo("[Gaia Critters] Failed to create " .. unitName)
						end
					end
				end
			end
		elseif cC.spawnCircle then
			local spawnCircle = cC.spawnCircle
			for unitName, unitAmount in pairs(cC.unitNames) do
				local unitDefID = getUnitDefIdbyName(unitName)
				if not UnitDefs[unitDefID] then
					break
				end
				local minWaterDepth = 0 - UnitDefs[unitDefID].minWaterDepth
				local waterunit = false
				if minWaterDepth < 0 then waterunit = true end

				-- to make sure at least 1 critter is placed  (to prevent when the multiplier is small, that a small critter-amount always gets diminished to zero)
				local amount = unitAmount * amountMultiplier
				if amount > 0 and amount < 1 then amount = 1 end
				amount = round(amount)

				local unitID = nil
				for i=1, amount do
					local a = rad(random(0, 360))
					local r = random(0, spawnCircle.r)
					local x = spawnCircle.x + r*sin(a)
					local z = spawnCircle.z + r*cos(a)
					local y = GetGroundHeight(x, z)
					if not waterunit or cC.nowatercheck ~= nil or y < minWaterDepth then
						local supplyMinWaterDepth = nil
						if waterunit and not cC.nowatercheck then
							supplyMinWaterDepth = minWaterDepth
						end
						unitID = CreateUnit(unitName, x, y, z, 0, GaiaTeamID)
						if unitID then
							randomPatrolInCircle(unitID, spawnCircle.x, spawnCircle.z, spawnCircle.r, supplyMinWaterDepth)
							--makeUnitCritter(unitID)
							critterUnits[unitID].unitName = unitName
						else
							SpringShared.Echo("[Gaia Critters] Failed to create " .. unitName)
						end
					end
				end
			end
		end
	end
	convertMapCrittersToCompanion()
	companionRadius = companionRadiusAfterStart
end


-- increase/decrease critters according to unitcount
function gadget:GameFrame(gameFrame)
	if gameFrame == 1 and addedInitialCritters == nil then	-- using gameframe 1 cause at GameStart commanders arent spawn yet
		addedInitialCritters = true
		addMapCritters()
	end

	-- update companion critters
	if totalCritters > 0 then
		if gameFrame%77==1 then
			local removeOwners
			local removeOwnersCount = 0
			for unitID, critters in pairs(companionCritters) do
				local x,y,z = GetUnitPosition(unitID)
				local radius = companionPatrolRadius
				if not ValidUnitID(unitID) then
					if not removeOwners then removeOwners = {} end
					removeOwnersCount = removeOwnersCount + 1
					removeOwners[removeOwnersCount] = unitID
				else
					local removeCritterIDs
					local removeCritterCount = 0
					for _, critterID in pairs(critters) do
						if not ValidUnitID(critterID) then
							if not removeCritterIDs then removeCritterIDs = {} end
							removeCritterCount = removeCritterCount + 1
							removeCritterIDs[removeCritterCount] = critterID
						else
							local cx,cy,cz = GetUnitPosition(critterID)
							if abs(x-cx) > radius*1.1 or abs(z-cz) > radius*1.1 then
								randomPatrolInCircle(critterID, x, z, radius)
							end
						end
					end
					for i = 1, removeCritterCount do
						companionCritters[unitID][removeCritterIDs[i]] = nil
					end
				end
			end
			for i = 1, removeOwnersCount do
				companionCritters[removeOwners[i]] = nil
			end
			if companionRadius > 0 then
				convertMapCrittersToCompanion()
			end
		end

		if removeCritters == false then return end

		if processOrders then
			processSceduledOrders()
		end

		if gameFrame%202==0 then
			local totalUnits = getTotalUnits() -- is without critters
			local multiplier = 1 - ((totalUnits-minTotalUnits) / (maxTotalunits-minTotalUnits))
			if multiplier < minimumCritters then multiplier = minimumCritters end
			if multiplier > 1 then multiplier = 1 end
			local newAliveCritters = ceil(totalCritters * multiplier)
			if newAliveCritters < minCritters then
				local mc = minCritters
				if totalCritters < minCritters then
					mc = totalCritters
				end
				newAliveCritters = mc
			end
			adjustCritters(newAliveCritters)
		end
	end
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return floor(num * mult + 0.5) / mult
end

function gadget:UnitIdle(unitID, unitDefID, unitTeam)
	if isCritter[unitDefID] and not sceduledOrders[unitID] then
		local x,y,z = GetUnitPosition(unitID,true,true)
		local radius = 220
		if isFlyingCritter[unitDefID] then
			radius = 750
		end
		randomPatrolInCircle(unitID, x, z, radius)
	end
end

local function getTeamCommanderUnitID(teamID)
	local teamUnits = SpringShared.GetTeamUnits(teamID)
	if teamUnits then
		for i = 1, #teamUnits do
			local unitID = teamUnits[i]
			local unitDefID = GetUnitDefID(unitID)
			if unitDefID and isCommander[unitDefID] then
				return unitID
			end
		end
	end
	return false
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		local x,_,z = GetUnitPosition(unitID,true,true)
		commanders[unitID] = {x,z}
	elseif isCritter[unitDefID] then
		local x,_,z = GetUnitPosition(unitID,true,true)
		local radius = 300
		if isFlyingCritter[unitDefID] then
			radius = 1500
		end
		randomPatrolInCircle(unitID, x, z, radius)

		-- make it a companion if close to a commander
		companionRadius = companionRadiusStart
		if unitTeam == GaiaTeamID then
			--if critterUnits[unitID] == nil then
				makeUnitCritter(unitID)
				critterUnits[unitID].unitName = UnitDefs[unitDefID].name
		--end
			critterToCompanion(unitID)
		else
			local commanderID = getTeamCommanderUnitID(unitTeam)
			if commanderID then
				local cx,cy,cz = GetUnitPosition(commanderID,true,true)
				local comlist = {}
				comlist[commanderID] = {cx,cz}
				commanderID = nearUnits(x, z, companionRadius, comlist)
				if commanderID ~= false then
					pairCompanionToUnit(unitID,commanderID)
				end
			end
		end
		companionRadius = companionRadiusAfterStart
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if commanders[unitID] then
		commanders[unitID] = nil
	elseif critterUnits[unitID] then
		critterUnits[unitID] = nil
		totalCritters = totalCritters - 1
		aliveCritters = aliveCritters - 1
	end
end

--http://springrts.com/phpbb/viewtopic.php?f=23&t=30109
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.ATTACK
	if cmdParams and #cmdParams == 1 then
		local critter = critterUnits[cmdParams[1]]
		if critter then
			return false
		end
	end
	return true
end
