local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Water Crush and Collision Damage",
		desc = "Creates and handles water collision events, and kills units stuck underwater",
		author = "SethDGamre",
		date = "2024.9.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--use customParams.water_fall_damage_multiplier = 1.0 to change the amount of fall damage taken by specific units.

--required velocity in a frame for a unit to take collision damage from falling into water.
local velocityThreshold = 108 / Game.gameSpeed

--any maxWaterDepth movedef equal to or above this number will not take drowning damage.
-- performance optimisation to avoid checking amphs and hovers
local isDrownableMaxWaterDepth = 5000

--a percentage of health taken as damage per second when stuck below maxWaterDepth.
local drowningDamage = 0.05

--base damage percentage multiplied by velocity upon impact with water.
local fallDamage = 0.18

--this influences the compounding escalation of fall damage from water collisions.
local fallDamageCompoundingFactor = 1.05

--statics
local gameFrame = 0
local gameFrameExpirationThreshold = 3
local gaiaTeamID = Spring.GetGaiaTeamID()
local waterDamageDefID = Game.envDamageTypes.Water
local gameSpeed = Game.gameSpeed

--functions
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID
local spAddUnitDamage = Spring.AddUnitDamage
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local spTestMoveOrder = Spring.TestMoveOrder
local spGetUnitHealth = Spring.GetUnitHealth
local spDestroyUnit = Spring.DestroyUnit

--tables
local unitDefData = {}
local transportDrops = {}
local drowningUnitsWatch = {}
local expiringTransportDrops = {}
local livingTransports = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	local defData = {}
	defData.fallDamageMultiplier = unitDef.customParams.water_fall_damage_multiplier or 1
	defData.drowningDamage = unitDef.health * drowningDamage
	defData.fallDamage = unitDef.health * fallDamage * defData.fallDamageMultiplier
	defData.unitDefID = unitDefID
	if unitDef.moveDef.depth and unitDef.moveDef.smClass ~= Game.speedModClasses.Boat and unitDef.moveDef.smClass ~= Game.speedModClasses.ship then
		if unitDef.moveDef.depth >= isDrownableMaxWaterDepth  then
			if unitDef.moveDef.smClass == Game.speedModClasses.Hover then --units must have "hover" in their movedef name in order to be treated as hovercraft
				defData.isHover = true
			else
				defData.isAmphibious = true
			end
		else
			defData.isDrownable = true
		end
	end
	unitDefData[unitDefID] = defData
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	livingTransports[transportID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportDrops[unitID] = transportID
end

function gadget:UnitLeftAir(unitID, unitDefID, unitTeam)
	if transportDrops[unitID] then
		expiringTransportDrops[unitID] = gameFrame + gameFrameExpirationThreshold
	end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if transportDrops[unitID] and not livingTransports[transportDrops[unitID]] then
		local velX, velY, velZ, velLength = spGetUnitVelocity(unitID)
		local posX, posY, posZ = spGetUnitBasePosition(unitID)
		if velLength > velocityThreshold then
			spSpawnCEG('watersplash_large', posX, posY, posZ)
			spPlaySoundFile('xplodep3', 0.5, posX, posY, posZ, 'sfx')
			if unitDefData[unitDefID] then
				local health, maxHealth = spGetUnitHealth(unitID)
				local damage = (unitDefData[unitDefID].fallDamage * velLength) * (fallDamageCompoundingFactor ^ velLength)
				if damage >= health then
					spDestroyUnit(unitID) --this ensures a wreck is left behind. If damage is too great, it destroys the heap.
				else
					spAddUnitDamage(unitID, damage, 0, gaiaTeamID, waterDamageDefID)
				end
			end
		else
			spSpawnCEG('watersplash_small', posX, posY, posZ)
			spPlaySoundFile('xplodep3', 0.3, posX, posY, posZ, 'sfx')
		end
		transportDrops[unitID] = nil
	else
		transportDrops[unitID] = nil
	end

	if unitDefData[unitDefID] and unitDefData[unitDefID].isDrownable then
		drowningUnitsWatch[unitID] = unitDefData[unitDefID]
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	drowningUnitsWatch[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	transportDrops[unitID] = nil
	expiringTransportDrops[unitID] = nil
	livingTransports[unitID] = nil
	drowningUnitsWatch[unitID] = nil
end

local function getUnitPositionHeight(unitID) -- returns nil for invalid units
	if (spGetUnitIsDead(unitID) ~= false) or (spValidUnitID(unitID) ~= true) then return nil, nil, nil end
	local posX, posY, posZ = spGetUnitPosition(unitID)
	if posX and posY and posZ then
		return posX, posY, posZ
	else
		return nil, nil, nil
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame

	for unitID, expirationFrame in pairs(expiringTransportDrops) do
		if expirationFrame < frame then
			expiringTransportDrops[unitID] = nil
			transportDrops[unitID] = nil
		end
	end

	if frame % gameSpeed == 6 then
		for unitID, data in pairs(drowningUnitsWatch) do
			local posX, posY, posZ = getUnitPositionHeight(unitID)
			if posX then
				local movableSpot = spTestMoveOrder(data.unitDefID, posX, posY, posZ, nil, nil, nil, true, true, true) --somehow, this works. Copied from elsewhere in the code, spring wiki and recoil and game repo didn't have any info on this format.
				if not movableSpot then
					spSpawnCEG('blacksmoke', posX, posY, posZ) --actually looks like tiny bubbles underwater
					spPlaySoundFile('lavarumbleshort1', 0.40, posX, posY, posZ, 'sfx')
					if math.random(1, 6) == 1 then
						spPlaySoundFile('alien_electric', 0.50, posX, posY, posZ, 'sfx')
					end
					spAddUnitDamage(unitID, data.drowningDamage, 0, gaiaTeamID, waterDamageDefID)
				end
			else
				drowningUnitsWatch[unitID] = nil --dead unit
			end
		end
	end
end