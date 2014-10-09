
function gadget:GetInfo()
    return {
        name      = 'Lightning Spash Damage',
        desc      = 'Handles Lightning Weapons Spash Damage',
        author    = 'TheFatController',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

----------------------------------------------------------------
-- Synced
----------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then

----------------------------------------------------------------
-- Config
----------------------------------------------------------------

local sparkWeapons = {
    [WeaponDefNames.armzeus_lightning.id] = {ceg = "ZEUS_FLASH_SUB", forkdamage = 0.5, maxunits=2},
    [WeaponDefNames.armclaw_dclaw.id] = {ceg = "CLAW_FLASH_SUB", forkdamage = 0.325, maxunits=2},
}

local immuneToSplash = {
    [UnitDefNames["armzeus"].id] = true,
    [UnitDefNames["armclaw"].id] = true,
}

local mRandom = math.random
----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
    if sparkWeapons[weaponID] then
      local x,y,z = Spring.GetUnitPosition(unitID)
      local angle = math.rad(mRandom(1,360))
      local nearUnits = Spring.GetUnitsInSphere(x,y,z,60)
      local count = 0
      for _,nearUnit in ipairs(nearUnits) do
        if (count >= sparkWeapons[weaponID].maxunits) then 
          return
        end
        local nearUnitDefID = Spring.GetUnitDefID(nearUnit)
        if (nearUnit ~= unitID) and (not immuneToSplash[nearUnitDefID]) then
          local nx,ny,nz = Spring.GetUnitPosition(nearUnit)
          Spring.SpawnCEG(sparkWeapons[weaponID].ceg,nx,ny,nz,0,0,0)
          Spring.AddUnitDamage(nearUnit, damage*sparkWeapons[weaponID].forkdamage, 0, attackerID)
          count = count + 1
        end
      end    
    end
end

else
----------------------------------------------------------------
-- Unsynced
----------------------------------------------------------------

end