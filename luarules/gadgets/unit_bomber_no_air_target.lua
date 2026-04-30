local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Bomber No Air Target",
		desc = "Prevents bombers from targeting air units",
		author = "Floris",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- air bombers can still attack air units cause their onlytargetcategory doesnt exclude them (notsub)

local isBomber = {}
local isAir = {}

for udid, unitDef in pairs(UnitDefs) do
	if unitDef.modCategories and unitDef.modCategories["vtol"] then
		isAir[udid] = true
	end
	if unitDef.canFly and not unitDef.hoverAttack and unitDef.weapons and unitDef.weapons[1] then
		for i = 1, #unitDef.weapons do
			local wDef = WeaponDefs[unitDef.weapons[i].weaponDef]
			if wDef.type == "AircraftBomb" or wDef.type == "TorpedoLauncher" then
				isBomber[udid] = true
				break
			end
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.ATTACK
	-- Block bombers from attacking air units (single-target only, not ground attack)
	if isBomber[unitDefID] and cmdParams[2] == nil and type(cmdParams[1]) == "number" then
		local targetDefID = SpringShared.GetUnitDefID(cmdParams[1])
		if targetDefID and isAir[targetDefID] then
			return false
		end
	end
	return true
end
