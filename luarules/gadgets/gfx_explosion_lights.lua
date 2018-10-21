
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

    function gadget:Initialize()
        for wdid, wd in pairs(WeaponDefs) do
            if wd.type == "Flame" then
                Script.SetWatchWeapon(wdid, true)     -- watch weapon so explosion gets called for flame weapons
            end
        end
    end

    function gadget:Explosion(weaponID, px, py, pz, ownerID)
        SendToUnsynced("explosion_light", px, py, pz, weaponID, ownerID)
    end

    function gadget:ProjectileCreated(projectileID, ownerID, weaponID)
        local px, py, pz = Spring.GetProjectilePosition(projectileID)
        SendToUnsynced("barrelfire_light", px, py, pz, weaponID, ownerID)
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
        if Script.LuaUI("GadgetWeaponExplosion") then
            if ownerID ~= nil then
                local _, _, _, teamID, allyID = Spring.GetPlayerInfo(ownerID)

                if (Spring.GetUnitAllyTeam(ownerID) == myAllyID  or  Spring.IsPosInLos(px, py, pz, myAllyID)) then
                    --if skipAirWeapons[weaponID] == nil or py ~= Spring.GetGroundHeight(px, py) then
                    Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
                    --end
                end
            else
                -- dont know when this happens and if we should show the explosion...
                Script.LuaUI.GadgetWeaponExplosion(px, py, pz, weaponID)
            end
        end
    end

    local function SpawnBarrelfire(_,px,py,pz, weaponID, ownerID)
        if Script.LuaUI("GadgetWeaponBarrelfire") then
            if ownerID ~= nil then
                local _, _, _, teamID, allyID = Spring.GetPlayerInfo(ownerID)

                if (Spring.GetUnitAllyTeam(ownerID) == myAllyID  or  Spring.IsPosInLos(px, py, pz, myAllyID)) then
                    --if skipAirWeapons[weaponID] == nil or py ~= Spring.GetGroundHeight(px, py) then
                    Script.LuaUI.GadgetWeaponBarrelfire(px, py, pz, weaponID, ownerID)
                    --end
                end
            else
                -- dont know when this happens and if we should show the explosion...
                Script.LuaUI.GadgetWeaponBarrelfire(px, py, pz, weaponID)
            end
        end
    end

    function gadget:Initialize()
        gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
        gadgetHandler:AddSyncAction("barrelfire_light", SpawnBarrelfire)
    end

    function gadget:Shutdown()
        gadgetHandler.RemoveSyncAction("explosion_light")
        gadgetHandler.RemoveSyncAction("barrelfire_light")
    end
end