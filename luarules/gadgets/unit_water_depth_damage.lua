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
local velocityThreshold = 75 / Game.gameSpeed
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
local fallingUnits = {}
local drowningUnitsWatch = {}
local expiringFallingUnits = {}
local livingTransports = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitDefData[unitDefID] = {}
	unitDefData[unitDefID].fallDamageMultiplier = unitDef.customParams.water_fall_damage_multiplier or 1
	unitDefData[unitDefID].drowningDamage = unitDef.health * drowningDamage
	unitDefData[unitDefID].fallDamage = unitDef.health * fallDamage * unitDefData[unitDefID].fallDamageMultiplier
	unitDefData[unitDefID].unitDefID = unitDefID
	if unitDef.moveDef.depth then
		if unitDef.moveDef.depth and unitDef.moveDef.depth >= isDrownableMaxWaterDepth then
			if unitDef.moveDef.name and string.find(unitDef.moveDef.name, "hover") and not string.find(unitDef.moveDef.name, "raptor") then
				unitDefData[unitDefID].isHover = true
			else
				unitDefData[unitDefID].isAmphibious = true
			end
		else
			unitDefData[unitDefID].isDrownable = true
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	livingTransports[transportID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	fallingUnits[unitID] = fallingUnits[unitID] or {}
	fallingUnits[unitID].transportID = transportID
end

function gadget:UnitLeftAir(unitID, unitDefID, unitTeam)
	if fallingUnits[unitID] then
		expiringFallingUnits[unitID] = gameFrame + gameFrameExpirationThreshold
	end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if fallingUnits[unitID] and not livingTransports[fallingUnits[unitID].transportID] then
		local velX, velY, velZ, velLength = spGetUnitVelocity(unitID)
		local posX, posY, posZ = spGetUnitBasePosition(unitID)
		if velLength > velocityThreshold then
			spSpawnCEG('watersplash_large', posX, posY, posZ)
			spPlaySoundFile('xplodep3', 0.5, posX, posY, posZ, 'sfx')
			if unitDefData[unitDefID] then
				local health, maxHealth = spGetUnitHealth(unitID)
				local damage = (unitDefData[unitDefID].fallDamage * velLength) *
					(fallDamageCompoundingFactor ^ velLength)
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
		fallingUnits[unitID] = nil
	else
		fallingUnits[unitID] = nil
	end

	if unitDefData[unitDefID] and unitDefData[unitDefID].isDrownable then
		drowningUnitsWatch[unitID] = unitDefData[unitDefID]
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	drowningUnitsWatch[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	fallingUnits[unitID] = nil
	expiringFallingUnits[unitID] = nil
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

	for unitID, expirationFrame in pairs(expiringFallingUnits) do
		if expirationFrame < frame then
			expiringFallingUnits[unitID] = nil
			fallingUnits[unitID] = nil
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