
    function gadget:GetInfo()
      return {
        name      = "UnitDefs Turret TurnSpeeds",
        desc      = "Allows to set units' turret turnspeeds from UnitDefs tables",
        author    = "Doo",
        date      = "May 2018",
        license   = "Whatever works",
        layer     = 0,
        enabled   = false,
      }
    end

--[[ HOW TO:
 -Edit the unit COB script by adding the static_vars "WeaponXTurretX" and "WeaponXTurretY" for each weapons that have a turret speed
 -Set them to 1 in Create() (this will prevent cob script from erroring in the unlikely case it aims before LUA could call the setting function)
 -Create a "SetWeaponXTurretSpeed(var1, var2)" function for each weapon used in the script:
{
	Weapon1TurretX = var1;
	weapon1TurretY = var2;
}
 -Replace the turret turnspeed values in the AimWeaponX and RestoreAfterDelay functions with the static_vars "WeaponXTurretX" and "WeaponXTurretY"
 -Set customParams.wpnXturretx and customParams.wpnXturrety values (= old COB values)
 -The gadget will call the SetWeaponXTurretSpeed(var1,var2) cob function with wpnXturretx, wpnXturrety values, therefore setting the static_vars to their wanted values
 
 This gadget will only call the setting function if it finds both the wpnXturretx and wpnXturrety customParams, if the weapon doesn't use a rotation around x-axis in its aiming then just set it to 1 (not nil)
]]
	
    if (not gadgetHandler:IsSyncedCode()) then return end

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