if not gadgetHandler:IsSyncedCode() then
	return
end

-- NOTE: Remember to turn off engine xp bonuses

function gadget:GetInfo()
	return {
		name = "Unit XP Gadget",
		desc = "Gadget based XP implementation that gives way more flexibility than engine one",
		author = "Damgam",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = Spring.GetModOptions and Spring.GetModOptions().experimentalxpsystem and Spring.GetModOptions().experimentalxpsystem == "enabled",
	}
end

local XPLevel = {}
local unitsDefID = {}

-- Generate levels table
local levelsScale = 10 -- xp for each level
local levelsCurrentExponent = 1 -- initial exponent multiplier
local levelsExponent = 0.5 -- how much does the exponent multiplier increase with each level
local levelsCount = 20
local levelsTable = {}
for i = 1, levelsCount do
	--local level = i*levelsScale
	if i > 1 then
		local level = (math.ceil((math.ceil((i - 1) * levelsScale * levelsCurrentExponent)) / 5)) * 5
		levelsCurrentExponent = levelsCurrentExponent + levelsExponent
		table.insert(levelsTable, level)
	elseif i == 1 then
		table.insert(levelsTable, 0)
	end
end

-- Levels check
for i = 1, #levelsTable do
	local level = levelsTable[i]
	if i == 1 then
		Spring.Echo("Gadget XP Level table")
	end
	Spring.Echo("Level " .. i .. ": " .. level .. " xp.")
end

-- cache
local unitWeapons = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	if #weapons > 0 then
		unitWeapons[unitDefID] = {}
		for id, _ in pairs(weapons) do
			unitWeapons[unitDefID][id] = true    -- no need to store weapondefid
		end
	end
end

local spGetUnitExperience = Spring.GetUnitExperience
local spSpawnCEG = Spring.SpawnCEG

-- numbers mean % bonus from previous level. negative number = nerf, positive number = buff,
local defaultConfig = {
	health = 10, -- done
	reloadTime = 10, -- done
	weaponDamage = 0, -- not implemented yet
	weaponRange = 0, -- not implemented yet
	maxSpeed = 0, -- not implemented yet
	acceleration = 0, -- not implemented yet (also affects braking)
	turnRate = 0, -- not implemented yet
}

local unitConfigs = { -- missing values default to 0
	-- example:
	-- UnitDefNames.armpw.id = {maxSpeed = 10, turnRate = 10,}
}

local function ApplyBonuses(unitID)
	local unitDefID = unitsDefID[unitID]
	if unitConfigs[unitDefID] then

		if unitConfigs[unitDefID].health then
			local curhealth, curmaxhealth = Spring.GetUnitHealth(unitID)
			Spring.SetUnitMaxHealth(unitID, curmaxhealth * (1 + (unitConfigs[unitDefID].health * 0.01)))
			Spring.SetUnitHealth(unitID, curhealth * (1 + (unitConfigs[unitDefID].health * 0.01)))
		end

		local weapons = unitWeapons[unitDefID]
		if weapons then
			for i = 1, #weapons do
				if unitConfigs[unitDefID].reloadTime then
					local weaponReloadTime = Spring.GetUnitWeaponState(unitID, i, "reloadTime")
					Spring.SetUnitWeaponState(unitID, i, "reloadTime", weaponReloadTime * (1 - (unitConfigs[unitDefID].reloadTime * 0.01)))
				end
			end
		end

	else

		if defaultConfig.health ~= 0 then
			local curhealth, curmaxhealth = Spring.GetUnitHealth(unitID)
			Spring.SetUnitMaxHealth(unitID, curmaxhealth * (1 + (defaultConfig.health * 0.01)))
			Spring.SetUnitHealth(unitID, curhealth * (1 + (defaultConfig.health * 0.01)))
		end
		local weapons = unitWeapons[unitDefID]
		if weapons then
			for i = 1, #weapons do
				if defaultConfig.reloadTime ~= 0 then
					local weaponReloadTime = Spring.GetUnitWeaponState(unitID, i, "reloadTime")
					Spring.SetUnitWeaponState(unitID, i, "reloadTime", weaponReloadTime * (1 - (defaultConfig.reloadTime * 0.01)))
				end
			end
		end
	end

	local posx, posy, posz = Spring.GetUnitPosition(unitID)
	local footprintx = UnitDefs[unitDefID].footprintx
	local footprintz = UnitDefs[unitDefID].footprintz
	if footprintx and footprintz then
		if footprintx >= footprintz then
			if footprintx == 0 then
				spSpawnCEG("levelup_fp3", posx, posy, posz, 0, 0, 0)
			elseif footprintx == 1 then
				spSpawnCEG("levelup_fp1", posx, posy, posz, 0, 0, 0)
			elseif footprintx == 2 then
				spSpawnCEG("levelup_fp2", posx, posy, posz, 0, 0, 0)
			elseif footprintx == 3 then
				spSpawnCEG("levelup_fp3", posx, posy, posz, 0, 0, 0)
			elseif footprintx == 4 then
				spSpawnCEG("levelup_fp4", posx, posy, posz, 0, 0, 0)
			elseif footprintx >= 5 then
				spSpawnCEG("levelup_fp5", posx, posy, posz, 0, 0, 0)
			end

		elseif footprintx < footprintz then
			if footprintz == 0 then
				spSpawnCEG("levelup_fp3", posx, posy, posz, 0, 0, 0)
			elseif footprintz == 1 then
				spSpawnCEG("levelup_fp1", posx, posy, posz, 0, 0, 0)
			elseif footprintz == 2 then
				spSpawnCEG("levelup_fp2", posx, posy, posz, 0, 0, 0)
			elseif footprintz == 3 then
				spSpawnCEG("levelup_fp3", posx, posy, posz, 0, 0, 0)
			elseif footprintz == 4 then
				spSpawnCEG("levelup_fp4", posx, posy, posz, 0, 0, 0)
			elseif footprintz >= 5 then
				spSpawnCEG("levelup_fp5", posx, posy, posz, 0, 0, 0)
			end
		end
	else
		spSpawnCEG("levelup_fp3", posx, posy, posz, 0, 0, 0)
	end
	XPLevel[unitID] = XPLevel[unitID] + 1
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitWeapons[unitDefID] then
		XPLevel[unitID] = 1
		unitsDefID[unitID] = unitDefID
	end
end
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	XPLevel[unitID] = nil
	unitsDefID[unitID] = nil
end

function gadget:GameFrame(n)
	for unitID, level in pairs(XPLevel) do
		if unitID % 30 == n % 30 then
			if spGetUnitExperience(unitID) > levelsTable[level + 1] then
				ApplyBonuses(unitID)
			end
		end
	end
end
