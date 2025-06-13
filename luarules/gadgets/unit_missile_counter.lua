local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Burst overkill prevention",
		desc = "Limits a volley to only the shots needed to kill a target",
		author = "EnderRobo",
		date = "May 7, 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local isCommander = {}

local function shotCounter(unitID, unitDefID, team, volleyCount, weaponNum)
	
	local armored, armorMultiplier
	local damage = Spring.GetUnitWeaponDamages(unitID, weaponNum, Game.armorTypes.standard)
	local health, maxHealth
	local counter
	local losState
	local targetType, isUserTarget, targetID = Spring.GetUnitWeaponTarget(unitID, 1) 
	local burstRate = (Spring.GetUnitWeaponState(unitID, weaponNum, "burstRate") * 1000)
	local reaimTime = Spring.GetUnitWeaponState(unitID, weaponNum, "reaimTime")
	local targetDefID
	if targetType == 1 then -- target is a unit
		losState = Spring.GetUnitLosState(targetID, team, true)
		targetDefID = Spring.GetUnitDefID(targetID)
		
		if isCommander[targetDefID] then																					--if its a commander fire a full volley
			counter = volleyCount
			
		elseif losState == 6 and not UnitDefs[targetDefID].isBuilding then													--fire full volley at radar blobs
			counter = volleyCount
			
		elseif losState == 2 then																							--fire full volley at radar blobs
			counter = volleyCount
			
		elseif losState == 15 or losState == 1 then																			--check how many missiles for visible target
			armored, armorMultiplier = Spring.GetUnitArmored(targetID)
			health = Spring.GetUnitHealth(targetID)
			if damage <= 0 or armored and armorMultiplier <= 0 then
				counter = volleyCount
			elseif armored then
				counter = math.floor(health / (damage * armorMultiplier)) + 1												--account for armored state
			else
				counter = math.floor(health / damage) + 1	
			end	
			
		elseif losState == (14) or (losState == 6 and UnitDefs[targetDefID].isBuilding) then								--check how many missiles for radar ghost target at max health
			maxHealth = UnitDefs[targetDefID].health
			if damage <= 0 then
				counter = volleyCount
			else 
				counter = math.floor(maxHealth / damage) + 1
			end
		end
	else																													--fire full volley at ground
		counter = volleyCount
	end
	Spring.CallCOBScript(unitID, "shotCounter", 8, counter, targetID, burstRate, health, losState, damage, armored, reaimTime)
	return 1
end

function gadget:Initialize()
	gadgetHandler:RegisterGlobal("ShotCounter", shotCounter)
	for targetDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander or unitDef.customParams.isdecoycommander then
			isCommander[targetDefID] = true
		end
	end
end