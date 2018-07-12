
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

-- exclude air (to prevent aa missiles that reach ground from having lights)
--local groundTypes = {
--    default = true,
--    commanders = true,
--    crawlingbombs = true,
--    platform = true,
--    heavyunits = true,
--    nanos = true,
--    shields = true,
--    scouts = true,
--    corvettes = true,
--    destroyers = true,
--    cruisers = true,
--    carriers = true,
--    battleships = true,
--    flagships = true
--}
--local skipAirWeapons = {}
--local groundDamage = false
--for weaponID, weaponDef in pairs(WeaponDefs) do
--    groundDamage = false
--    for type, damage in pairs(weaponDef.damages) do            -- weaponDef.damages doesnt contain what i expected
--        Spring.Echo(type..'  '..damage)
--        if groundTypes[type] ~= nil and damage > 0 then
--            groundDamage = true
--            break
--        end
--    end
--    if groundDamage == false then
--        skipAirWeapons[weaponID] = true
--    end
--end

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

    function gadget:Initialize()
        gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
    end

    function gadget:Shutdown()
        gadgetHandler.RemoveSyncAction("explosion_light")
    end
end