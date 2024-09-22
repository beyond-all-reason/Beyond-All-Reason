function gadget:GetInfo()
	return {
		name = "Collision Damage Behavior",
		desc = "Magnifies the default engine ground and object collision damage and handles max impulse limits",
		author = "SethDGamre",
		date = "2024.8.29",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--any maxWaterDepth movedef equal to or above this number will not take drowning damage.
local ignoredMaxWaterDepthThreshold = 5000

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
local velocityThreshold = 2.5
local waterDamageDefID = -5

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

--tables
local unitDefData = {}
local fallingUnits = {}
local drowningUnitsWatch = {}
local expiringFallingUnits = {}
local livingTransports = {}

for unitDefID, unitDef in ipairs(UnitDefs) do

	unitDefData[unitDefID] = {}

	unitDefData[unitDefID].fallDamageMultiplier = unitDef.customParams.fall_damage_multiplier or 1

	if unitDef.health then
		unitDefData[unitDefID].drowningDamage = unitDef.health * drowningDamage
		unitDefData[unitDefID].fallDamage = unitDef.health * fallDamage * unitDefData[unitDefID].fallDamageMultiplier
		unitDefData[unitDefID].unitDefID = unitDefID
	end
	if unitDef.moveDef.depth then
		if unitDef.moveDef.depth >= ignoredMaxWaterDepthThreshold then
			if string.find(unitDef.moveDef.name, "hover") and not string.find(unitDef.moveDef.name, "raptor") then
				unitDefData[unitDefID].isHover = true
			else
				unitDefData[unitDefID].isAmphibious = true
			end
		else 
			unitDefData[unitDefID].isDrownable = true
		end
	end

end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
	livingTransports[transportID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
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
		if velLength > velocityThreshold then
			local posX, posY, posZ = spGetUnitBasePosition(unitID)
			spSpawnCEG('watersplash_large', posX, posY, posZ)
			spPlaySoundFile('xplodep3', 0.5, posX, posY, posZ, 'sfx')
			if unitDefData[unitDefID].isHover then
				local damage = (unitDefData[unitDefID].fallDamage * velLength) * (fallDamageCompoundingFactor ^ velLength)
				spAddUnitDamage(unitID, damage, 0, gaiaTeamID, waterDamageDefID)
			end
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
	if posX and posY and posZ  then
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

	if frame % Game.gameSpeed == 6 then
		for unitID, data in pairs(drowningUnitsWatch) do
			local posX, posY, posZ = getUnitPositionHeight(unitID)
			if posX then
				local movableSpot = spTestMoveOrder(data.unitDefID, posX, posY, posZ, nil, nil, nil, true, true, true) --somehow, this works. Copied from elsewhere in the code, spring wiki and recoil and game repo didn't have any info on this format.
				if not movableSpot then
					spSpawnCEG('blacksmoke', posX, posY, posZ) --actually looks like tiny bubbles underwater
					spPlaySoundFile('xplodep3', 0.15, posX, posY, posZ, 'sfx')
					spAddUnitDamage(unitID, data.drowningDamage, 0, gaiaTeamID, waterDamageDefID)
				end
			else
				drowningUnitsWatch[unitID] = nil --dead unit
			end
		end
	end
end



