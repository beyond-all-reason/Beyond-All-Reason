function gadget:GetInfo()
  return {
    name      = "PlasmaAutoHighTraj",
    desc      = "Automatically switches to hightraj when lowtraj weapon isn't available for thuds/hammers",
    author    = "Doo",
    date      = "29 July 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end
plasmaBots = {}
if (not gadgetHandler:IsSyncedCode()) then return end
local Units = {
    [UnitDefNames["armham"].id] = true,
    [UnitDefNames["corthud"].id] = true,
}

function gadget:UnitCreated(unitID)
	if (Units[Spring.GetUnitDefID(unitID)]) then
		plasmaBots[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID)
	if plasmaBots[unitID] then
	plasmaBots[unitID] = nil
	end
end

function gadget:GameFrame()
	for unitID, isPlasmaBot in pairs(plasmaBots) do
		HasTarget1 = Spring.GetUnitWeaponTarget(unitID, 1)
		HasTarget2 = Spring.GetUnitWeaponTarget(unitID, 2)
		if HasTarget1 ~= nil and HasTarget1 ~= 0 then
			-- Spring.Echo("weap1")
			Spring.CallCOBScript(unitID, "SetWeapon", 0, 1)
			elseif HasTarget2 ~= nil and HasTarget2 ~= 0 then
			-- Spring.Echo("weap2")
			Spring.CallCOBScript(unitID, "SetWeapon", 0, 2)
		end
	end
end

function gadget:ProjectileCreated(proID, proOwner, weaponDefID)
if proOwner then
if weaponDefID then
	if plasmaBots[proOwner] then
		if WeaponDefs[weaponDefID].name == "armham_arm_ham" or WeaponDefs[weaponDefID].name == "corthud_arm_ham" then
			local reloadstate = Spring.GetUnitWeaponState(proOwner, 1, "reloadstate")
			Spring.SetUnitWeaponState(proOwner, 2, "reloadstate", reloadstate)
		elseif WeaponDefs[weaponDefID].name == "armham_arm_ham2" or WeaponDefs[weaponDefID].name == "corthud_arm_ham2" then
			local reloadstate = Spring.GetUnitWeaponState(proOwner, 2, "reloadstate")
			Spring.SetUnitWeaponState(proOwner, 1, "reloadstate", reloadstate)		
end
end
end
end
end