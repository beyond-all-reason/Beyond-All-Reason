
function gadget:GetInfo()
  return {
	name 	= "Ranges Fix",
	desc	= "Makes sure the unit's maxRange fits its weapons",
	author	= "Doo",
	date	= "01/09/2018",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

local FIDOID = UnitDefNames["armfido"].id
local wDef2 = WeaponDefs[UnitDefs[FIDOID].weapons[1].weaponDef]

local Ranges = {}
for unitDefID, defs in pairs(UnitDefs) do
	local maxRange = 0
	local maxAARange = 0
	for i, weapon in pairs (defs.weapons) do
		local wDef = WeaponDefs[weapon.weaponDef]
		if wDef.range >= maxRange and wDef.canAttackGround == true then
			maxRange = wDef.range
		elseif wDef.range >= maxAARange and not wDef.canAttackGround == true then
			maxAARange = wDef.range
		end
	end
	if maxRange ~= 0 then
		Ranges[unitDefID] = maxRange
	else
		Ranges[unitDefID] = maxAARange
	end
	if defs.customParams.customrange then
		Ranges[unitDefID] = tonumber(defs.customParams.customrange)
	end
end


if (gadgetHandler:IsSyncedCode()) then --SYNCED
  function gadget:Initialize()
  hplasmarange = ((wDef2.projectilespeed*30)^2)/Game.gravity
  if hplasmarange >= wDef2.range then
	hplasmarange = wDef2.range
  end
  -- Spring.Echo(hplasmarange, wDef2.range)
  end
  
  function gadget:UnitCreated(unitID, unitDefID)
	if unitDefID == FIDOID then
		Spring.SetUnitWeaponState(unitID, 1, "range", hplasmarange)
		Spring.SetUnitMaxRange(unitID, hplasmarange)
		return
	end
	if Ranges[unitDefID] then
		Spring.SetUnitMaxRange(unitID, Ranges[unitDefID])	
		return
	end
  end
  
  function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
	if unitDefID == FIDOID then
		if cmdID == CMD.ONOFF then
			if cmdParams and cmdOpts[1] == 0 then -- DESACTIVATE (GAUSS)
				Spring.SetUnitWeaponState(unitID, 2, "range", 0)
				Spring.SetUnitWeaponState(unitID, 1, "range", wDef2.range)
				Spring.SetUnitMaxRange(unitID, wDef2.range)
			elseif cmdParams and cmdOpts[1] == 1 then -- ACTIVATE (HEAVY PLASMA)
				Spring.SetUnitWeaponState(unitID, 2, "range", hplasmarange)
				Spring.SetUnitWeaponState(unitID, 1, "range", hplasmarange)
				Spring.SetUnitMaxRange(unitID, hplasmarange)
			end
			Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
			Spring.GiveOrderToUnit(unitID, CMD.WAIT, {}, {})
		end
	end
  end
end