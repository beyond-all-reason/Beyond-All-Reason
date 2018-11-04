
    function gadget:GetInfo()
      return {
        name      = "UnitDefs Turret TurnSpeeds",
        desc      = "Allows to set units' turret turnspeeds from UnitDefs tables",
        author    = "Doo",
        date      = "May 2018",
        license   = "Whatever works",
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
	
    if (not gadgetHandler:IsSyncedCode()) then return end

	function gadget:Initialize()
		for ct, unitID in pairs(Spring.GetAllUnits()) do
			local udefID = Spring.GetUnitDefID(unitID)
			gadget:UnitCreated(unitID, udefID)
		end
	end
	
    function gadget:UnitCreated(unitID, unitDefID)
		if UnitDefs[unitDefID].weapons then
		for i = 1, 32 do
			if UnitDefs[unitDefID].weapons[i] then
				local customParamName = "wpn"..(tostring(i)).."turret"
				if UnitDefs[unitDefID].customParams and UnitDefs[unitDefID].customParams[customParamName.."x"] and UnitDefs[unitDefID].customParams[customParamName.."y"] then
					local TurretX = (tonumber(UnitDefs[unitDefID].customParams[customParamName.."x"]))*182
					local TurretY = (tonumber(UnitDefs[unitDefID].customParams[customParamName.."y"]))*182
					Spring.CallCOBScript(unitID, "SetWeapon"..(tostring(i)).."TurretSpeed", 0, TurretX, TurretY)
				end
			end
		end
		end
    end