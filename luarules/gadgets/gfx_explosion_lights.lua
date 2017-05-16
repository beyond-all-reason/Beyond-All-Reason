
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
	
  function gadget:Explosion(weaponID, px, py, pz, ownerID)
	  	SendToUnsynced("explosion_light", px, py, pz, weaponID, ownerID)
  end
	
else
	
-------------------------------------------------------------------------------
-- Unsynced
-------------------------------------------------------------------------------
	
	local myAllyID = Spring.GetMyAllyTeamID()
	
	function gadget:PlayerChanged(playerID)
		if (playerID == Spring.GetMyPlayerID()) then
			myAllyID = Spring.GetMyAllyTeamID()
		end
	end
	
  local function SpawnExplosion(_,px,py,pz, weaponID, ownerID)
    if ownerID ~= nil then
  	    local _, _, _, teamID, allyID = Spring.GetPlayerInfo(ownerID)

        if Script.LuaUI("GadgetWeaponExplosion")  and  (Spring.GetUnitAllyTeam(ownerID) == myAllyID  or  Spring.IsPosInLos(px, py, pz, myAllyID)) then
          Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
        end
    else
        -- dont know when this happens and if we should show the explosion...
        Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID)
    end
  end

  function gadget:Initialize()
    gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
  end

  function gadget:Shutdown()
    gadgetHandler.RemoveSyncAction("explosion_light")
  end

end