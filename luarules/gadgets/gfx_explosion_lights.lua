
function gadget:GetInfo()
  return {
    name      = "Explosion_lights",
    desc      = "",
    author    = "Floris",
    date      = "April 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

-------------------------------------------------------------------------------
-- Synced
-------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

  function gadget:Explosion(weaponID, px, py, pz, ownerID)
	  SendToUnsynced("explosion_light", px, py, pz, weaponID, ownerID)
  end

-------------------------------------------------------------------------------
-- Unsynced
-------------------------------------------------------------------------------
else
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

  local function SpawnExplosion(_,px,py,pz, weaponID, ownerID)
    if Script.LuaUI("GadgetWeaponExplosion") then
      Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
    end
  end

  function gadget:Initialize()
    gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
  end

  function gadget:Shutdown()
    gadgetHandler.RemoveSyncAction("explosion_light")
  end

end