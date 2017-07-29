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
local Units = { -- List of plasma bots whose behaviour must be altered
    [UnitDefNames["armham"].id] = true,
    [UnitDefNames["corthud"].id] = true,
}

function gadget:UnitCreated(unitID) -- add to table
	if (Units[Spring.GetUnitDefID(unitID)]) then
		plasmaBots[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID) -- Remove from table
	if plasmaBots[unitID] then
		plasmaBots[unitID] = nil
	end
end

function gadget:GameFrame()
	for unitID, isPlasmaBot in pairs(plasmaBots) do
		HasTarget1 = Spring.GetUnitWeaponTarget(unitID, 1) -- Does its 1st (low traj) weapon have a target?
		HasTarget2 = Spring.GetUnitWeaponTarget(unitID, 2) -- Does its 2nd (high traj) can target? weap2 is slaved so both will always try to target the same target.
		if HasTarget1 ~= nil and HasTarget1 ~= 0 then -- If weapon1 can target, always give priority to it.
				Spring.CallCOBScript(unitID, "SetWeapon", 0, 1) -- Call the COB script that blocks the weapon2 aim script.
			elseif HasTarget2 ~= nil and HasTarget2 ~= 0 then -- If weapon1 can't target, but weapon2 can.
				Spring.CallCOBScript(unitID, "SetWeapon", 0, 2) -- Call the COB script that enables the weapon2 aim script and blocks weapon1's.
		end
	end
end

function gadget:ProjectileCreated(proID, proOwner, weaponDefID)
	if proOwner then
		if weaponDefID then
			if plasmaBots[proOwner] then
			-- a plasma weapon has fired: copy reloadstate to the other one to avoid increased firerates
				if WeaponDefs[weaponDefID].name == "armham_arm_ham" or WeaponDefs[weaponDefID].name == "corthud_arm_ham" then -- Weapon1 had fired
					local reloadstate = Spring.GetUnitWeaponState(proOwner, 1, "reloadstate")
					Spring.SetUnitWeaponState(proOwner, 2, "reloadstate", reloadstate) -- Copy reloadstate from 1 to 2
				elseif WeaponDefs[weaponDefID].name == "armham_arm_ham2" or WeaponDefs[weaponDefID].name == "corthud_arm_ham2" then -- Weapon2 had fired
					local reloadstate = Spring.GetUnitWeaponState(proOwner, 2, "reloadstate")
					Spring.SetUnitWeaponState(proOwner, 1, "reloadstate", reloadstate) -- Copy reloadstate from 2 to 1	
				end
				
			end
		end
	end
end