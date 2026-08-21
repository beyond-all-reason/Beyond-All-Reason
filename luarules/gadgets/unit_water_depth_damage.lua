local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Water Crush and Collision Damage",
		desc = "Creates and handles water collision events, and kills units stuck underwater",
		author = "SethDGamre",
		date = "2024.9.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

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

--slack (elmos) between a unit's depth and its movedef depth limit before we run the expensive
--TestMoveOrder check; covers pos-vs-square-center height differences on sloped seafloor
local drownDepthSlack = 8

--check for modoption everyoneisparatrooper
local everyoneIsParatrooper = Spring.GetModOptions().everyoneisparatrooper

-- for units that would normally drown; hover/amphibious units take some damage since water is their normal environment
local everyoneIsParatrooperWaterFallDamageMultiplier = 0.25

local gameFrame = 0
local gameFrameExpirationThreshold = 3
local gaiaTeamID = Spring.GetGaiaTeamID()
local waterDamageDefID = Game.envDamageTypes.Water
local gameSpeed = Game.gameSpeed

local spGetUnitIsDead = Spring.GetUnitIsDead
local spAddUnitDamage = Spring.AddUnitDamage
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local spTestMoveOrder = Spring.TestMoveOrder
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spDestroyUnit = Spring.DestroyUnit

local waterIsLava = Spring.GetModOptions().map_waterislava
local largeSplashCEG = waterIsLava and "lavasplash_large" or "watersplash_large"
local smallSplashCEG = waterIsLava and "lavasplash_small" or "watersplash_small"

local unitDefData = {}
local transportDrops = {}
local drowningUnitsWatch = {}
local expiringTransportDrops = {}
local livingTransports = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	local defData = {}
	defData.unitDefID = unitDefID

	if
		unitDef.moveDef.depth
		and unitDef.moveDef.smClass ~= Game.speedModClasses.Boat
		and unitDef.moveDef.smClass ~= Game.speedModClasses.ship
	then
		if unitDef.moveDef.depth >= isDrownableMaxWaterDepth then
			if unitDef.moveDef.smClass == Game.speedModClasses.Hover then --units must have "hover" in their movedef name in order to be treated as hovercraft
				defData.isHover = true
			else
				defData.isAmphibious = true
			end
		else
			defData.isDrownable = true
			-- pos.y below this means the unit may be beyond its movedef depth limit;
			-- only then is the authoritative (and expensive) TestMoveOrder check needed
			defData.drownCandidateY = drownDepthSlack - unitDef.moveDef.depth
		end
	end
	if unitDef.customParams.decoration then
		defData.isAmphibious = true
		defData.isDrownable = false
	end

	--check if everyoneIsParatrooper, use reduced damage, else, standard fall damage
    if everyoneIsParatrooper then
        defData.fallDamageMultiplier = (defData.isAmphibious or defData.isHover) and 0 or everyoneIsParatrooperWaterFallDamageMultiplier
    else
        defData.fallDamageMultiplier = unitDef.customParams.water_fall_damage_multiplier or 1
    end
	
	--damage moved to end to allow amphib / hover checks to survive water
	defData.drowningDamage = unitDef.health * drowningDamage
	defData.fallDamage = unitDef.health * fallDamage * defData.fallDamageMultiplier

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
	local defData = unitDefData[unitDefID]
	if transportDrops[unitID] then
		if not livingTransports[transportDrops[unitID]] then
			local velX, velY, velZ, velLength = spGetUnitVelocity(unitID)
			local posX, posY, posZ = spGetUnitBasePosition(unitID)
			if velLength > velocityThreshold then
				spSpawnCEG(largeSplashCEG, posX, posY, posZ)
				spPlaySoundFile("xplodep3", 0.5, posX, posY, posZ, "sfx")
				if defData then
					local health, maxHealth = spGetUnitHealth(unitID)
					local damage = (defData.fallDamage * velLength) * (fallDamageCompoundingFactor ^ velLength)
					if damage >= health then
						if spGetUnitRulesParam(unitID, "unit_effigy") then
							spAddUnitDamage(unitID, damage, 0, nil, waterDamageDefID)
						else
							spDestroyUnit(unitID) --this ensures a wreck is left behind. If damage is too great, it destroys the heap.
						end
					else
						spAddUnitDamage(unitID, damage, 0, nil, waterDamageDefID)
					end
				end
			else
				spSpawnCEG(smallSplashCEG, posX, posY, posZ)
				spPlaySoundFile("xplodep3", 0.3, posX, posY, posZ, "sfx")
			end
		end
		transportDrops[unitID] = nil
	end

	if defData and defData.isDrownable then
		drowningUnitsWatch[unitID] = defData
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
			local posX, posY, posZ = spGetUnitPosition(unitID)
			if not posX then
				drowningUnitsWatch[unitID] = nil --unit no longer exists
			elseif posY < data.drownCandidateY and spGetUnitIsDead(unitID) == false then
				--deep enough that the movedef depth limit may be exceeded: ask the engine
				local movableSpot = spTestMoveOrder(data.unitDefID, posX, posY, posZ, nil, nil, nil, true, true, true) --somehow, this works. Copied from elsewhere in the code, spring wiki and recoil and game repo didn't have any info on this format.
				if not movableSpot then
					spSpawnCEG("blacksmoke", posX, posY, posZ) --actually looks like tiny bubbles underwater
					spPlaySoundFile("lavarumbleshort1", 0.40, posX, posY, posZ, "sfx")
					if math.random(1, 6) == 1 then
						spPlaySoundFile("alien_electric", 0.50, posX, posY, posZ, "sfx")
					end
					spAddUnitDamage(unitID, data.drowningDamage, 0, nil, waterDamageDefID)
				end
			end
		end
	end
end
