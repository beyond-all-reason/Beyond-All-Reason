
function gadget:GetInfo()
  return {
	name 	= "Fido Range Fix",
	desc	= "Makes sure Gauss range and MaxRange == Plasma range when on plasma mode",
	author	= "Doo",
	date	= "01/09/2018",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

local FIDOID = UnitDefNames["armfido"].id
local wDef2 = WeaponDefs[UnitDefs[FIDOID].weapons[2].weaponDef]



if (gadgetHandler:IsSyncedCode()) then --SYNCED
  function gadget:Initialize()
  hplasmarange = ((wDef2.projectilespeed*30)^2)/Game.gravity
  if hplasmarange >= wDef2.range then
	hplasmarange = wDef2.range
  end
  end
  
  function gadget:UnitCreated(unitID, unitDefID)
	if unitDefID == FIDOID then
		Spring.SetUnitWeaponState(unitID, 1, "range", hplasmarange)
		Spring.SetUnitMaxRange(unitID, hplasmarange)
	end
  end
  
  function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
	if unitDefID == FIDOID then
		if cmdID == CMD.ONOFF then
			if cmdParams and cmdOpts[1] == 0 then -- DESACTIVATE (GAUSS)
			Spring.SetUnitWeaponState(unitID, 1, "range", wDef2.range)
			Spring.SetUnitMaxRange(unitID, wDef2.range)
			elseif cmdParams and cmdOpts[1] == 1 then -- ACTIVATE (HEAVY PLASMA)
			Spring.SetUnitWeaponState(unitID, 1, "range", hplasmarange)
			Spring.SetUnitMaxRange(unitID, hplasmarange)
			end
		end
	end
  end
end