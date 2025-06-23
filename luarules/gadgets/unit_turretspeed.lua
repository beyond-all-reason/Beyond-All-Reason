
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "UnitDefs Turret TurnSpeeds",
		desc      = "Allows to set units' turret turnspeeds from UnitDefs tables",
		author    = "Doo",
		date      = "May 2018",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

--[[ HOW TO:
 -Include unitDefsTurretSpeeds.h in unitScript
 -Replace the turret turnspeed values in the AimWeaponX and RestoreAfterDelay functions with the corresponding static_vars "WeaponXTurretX" and "WeaponXTurretY"
 -Set customParams.wpnXturretx and customParams.wpnXturrety values (= old COB values)
 -The gadget will call the SetWeaponXTurretSpeed(var1,var2) cob function with wpnXturretx, wpnXturrety values, therefore setting the static_vars to their wanted values
 -If using continuous aiming, the correct values for the waitforturn checks are: > 65536, > WeaponXTurretY/30, < 65536 - WeaponXTurretY/30 (== not within one frame of the last valid heading)

 This gadget will only call the setting function if it finds both the wpnXturretx and wpnXturrety customParams, if the weapon doesn't use a rotation around x-axis in its aiming then just set it to 1 (not nil)

For future notes, look for these in COB scripts
 Weapon1TurretX 
 Weapon1TurretY
 
Look for these in UnitDefs customparams:
 wpn1turretx
 wpn1turrety

This, should entirely be removed anyway, along with the customparams. No unit uses them any more anyway. 
Would otherwise require:

include "weapon1control.h"
  
in bos. noone uses that.   
 
 ]]

-- finds fields weapon1turretx/weapon1turrety, up to 10.
-- if these are renamed please update this comment accordingly so no sneaky code is lost :)

if not gadgetHandler:IsSyncedCode() then return end

local unitConf = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	if weapons and not string.find((string.lower(unitDef.scriptName)), "lua") then
		for weaponID, weapon in pairs(weapons) do
			local customParamName = 'weapon'..weaponID..'turret'
			if unitDef.customParams[customParamName..'x'] and unitDef.customParams[customParamName..'y'] then
				local TurretX = (tonumber(unitDef.customParams[customParamName..'x']))*182
				local TurretY = (tonumber(unitDef.customParams[customParamName..'y']))*182
				if not unitConf[unitDefID] then
					unitConf[unitDefID] = {}
				end
				unitConf[unitDefID][#unitConf[unitDefID]+1] = {'SetWeapon'..weaponID..'TurretSpeed', 0, TurretX, TurretY}
			end
		end
	end
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		local udefID = Spring.GetUnitDefID(unitID)
		gadget:UnitCreated(unitID, udefID)
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if unitConf[unitDefID] then
		for i=1, #unitConf[unitDefID] do
			Spring.CallCOBScript(unitID, unitConf[unitDefID][i][1], unitConf[unitDefID][i][2], unitConf[unitDefID][i][3], unitConf[unitDefID][i][4])
		end
	end
end
