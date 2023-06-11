
function gadget:GetInfo()
	return {
		name      = "UnitDefs Turret TurnSpeeds",
		desc      = "Allows to set units' turret turnspeeds from UnitDefs tables, and other weapon parameters",
		author    = "Doo, Itanthias",
		date      = "May 2018, May 2023",
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
 ]]

if not gadgetHandler:IsSyncedCode() then return end

local unitConf = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	if weapons and not string.find((string.lower(unitDef.scriptName)), "lua") then
		for weaponID, weapon in pairs(weapons) do
			local customParamName = 'wpn'..weaponID..'turret'
			if unitDef.customParams[customParamName..'x'] and unitDef.customParams[customParamName..'y'] then
				local TurretX = (tonumber(unitDef.customParams[customParamName..'x']))*182
				local TurretY = (tonumber(unitDef.customParams[customParamName..'y']))*182
				if not unitConf[unitDefID] then
					unitConf[unitDefID] = {}
				end
				unitConf[unitDefID][#unitConf[unitDefID]+1] = {'SetWeapon'..weaponID..'TurretSpeed', 0, TurretX, TurretY}
			end

			if WeaponDefs[weapon.weaponDef].customParams then
				if WeaponDefs[weapon.weaponDef].customParams.active_range then
					-- magic 65536 COB constant for range
					local active_range = tonumber(WeaponDefs[weapon.weaponDef].customParams.active_range)*65536
					local default_range = tonumber(WeaponDefs[weapon.weaponDef].range)*65536
					-- ensure unitConf[unitDefID] exists
					if not unitConf[unitDefID] then
						unitConf[unitDefID] = {}
					end
					-- add new entry to unitConf[unitDefID]
					-- and fill with parameters to pass in
					-- {function name, return values, pass in values}
					unitConf[unitDefID][#unitConf[unitDefID]+1] = {'SetWeapon'..weaponID..'range', 0, default_range, active_range}
				end
				if WeaponDefs[weapon.weaponDef].customParams.active_accuracy then
					-- magic 65536 COB constant
					-- magic 45055 constant for accuracy
					-- https://github.com/beyond-all-reason/spring/blob/BAR105/rts/Sim/Weapons/WeaponDef.cpp#L112
					-- random 0xafff factor in engine
					local active_accuracy = math.sin(tonumber(WeaponDefs[weapon.weaponDef].customParams.active_accuracy)*math.pi/45055)*65536
					local default_accuracy = tonumber(WeaponDefs[weapon.weaponDef].accuracy)*65536
					-- ensure unitConf[unitDefID] exists
					if not unitConf[unitDefID] then
						unitConf[unitDefID] = {}
					end
					-- add new entry to unitConf[unitDefID]
					-- and fill with parameters to pass in
					-- {function name, return values, pass in values}
					unitConf[unitDefID][#unitConf[unitDefID]+1] = {'SetWeapon'..weaponID..'accuracy', 0, default_accuracy, active_accuracy}
				end
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
