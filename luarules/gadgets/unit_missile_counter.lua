local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Missile counter",
		desc = "Checks how many missiles are needed to kill a target (used on Legion Medusa)",
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

local function missile_counter(unitID, unitDefID, team)
	
	local damage = Spring.GetUnitWeaponDamages (unitID, 2, Game.armorTypes.standard)
	local health, maxHealth
	local counter
	local losstate
	local works, isUserTarget, targetID = Spring.GetUnitWeaponTarget (unitID, 1) 
	local burstrate = (Spring.GetUnitWeaponState (unitID, 2, "burstRate") * 1000)
	local targetDefID
	if type(targetID) == "number" then
		losstate = Spring.GetUnitLosState(targetID, team, true)
		targetDefID = Spring.GetUnitDefID(targetID)
		
		if isCommander[targetDefID] then																					--if its a commander fire a full volley
			counter = 6
			
		elseif losstate == 6 and not UnitDefs[targetDefID].isBuilding then													--fire full volley at radar blobs
			counter = 6
			
		elseif losstate == 2 then																							--fire full volley at radar blobs
			counter = 6
			
		elseif losstate == (15 or 1) then																					--check how many missiles for visible target
			health, maxHealth = Spring.GetUnitHealth(targetID)
			counter = math.floor(health  / damage) + 1	
			
		elseif losstate == (14) or (losstate == 6 and UnitDefs[targetDefID].isBuilding) then								--check how many missiles for radar ghost target at max health
			maxHealth = UnitDefs[targetDefID].health
			counter = math.floor(maxHealth  / damage) + 1
			
		end
	else																													--fire full volley at ground
		counter = 6
	end
	Spring.CallCOBScript(unitID, "missile_counter", 6, 1, counter, targetID, burstrate, health, losstate, damage)
	return 1
end

function gadget:Initialize()
	gadgetHandler:RegisterGlobal("missile_counter", missile_counter)
	for targetDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander or (Spring.GetModOptions().deathmode == "builders" and ((unitDef.buildOptions and #unitDef.buildOptions > 0) or unitDef.canResurrect == true)) then
			isCommander[targetDefID] = true
		end
	end
end
