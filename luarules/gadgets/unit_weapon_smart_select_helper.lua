function gadget:GetInfo()
	return {
		name = "Weapon Smart Select Helper",
		desc = "Prevents auto-target units from blocking manual command fire orders for lower priority weapons.",
		author = "SethDGamre",
		date = "2024.11.16",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

function gadget:CommandNotify(cmdID, params, options)
	Spring.Echo("CommandNotify", cmdID)
 end

if not gadgetHandler:IsSyncedCode() then return end

--use customparams.smart_weapon_select_priority to define which weapon number is preferred over the other(s) and enable auto-targetting override.

--tables
local smartWeaponsWatch = {}
local unitDefsWithSmartWeapons = {}
local cmdSuspensionTable = { 
		[CMD.ATTACK] = true, 
		[CMD.AREA_ATTACK] = true,
		[CMD.CMD_UNIT_SET_TARGET] = true
}

for unitDefID, def in ipairs(UnitDefs) do
	if def.customParams.smart_weapon_select_priority then
		smartWeaponsWatch[unitDefID] = def.customParams.smart_weapon_select_priority
		for weaponNumber, weaponData in ipairs(def.weapons) do
			Spring.Echo("smart_weapon_select_priority", weaponData.name, weaponNumber, weaponData)
			Script.SetWatchWeapon(weaponData.weaponDef, true)
		end
	end
end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
	--Spring.Echo("AllowWeaponTargetCheck", attackerID, attackerWeaponNum, attackerWeaponDefID, Spring.GetGameFrame())
	return false, true
	end


function gadget:GameFrame(frame)
	
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	 if cmdSuspensionTable[cmdID] then 
		-- Custom logic when the command is in the suspension table 
		Spring.Echo("Command suspended:", cmdID)
		
		-- Your additional logic here 
		return false -- Disallow the command if it's in the suspension table 

		end 
	return true 
		-- Allow all other commands
 end

--  function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
-- 	Spring.Echo("commandFallback", cmdID)
--  end