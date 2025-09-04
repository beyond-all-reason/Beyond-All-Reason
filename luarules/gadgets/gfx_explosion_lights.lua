
local gadget = gadget ---@type Gadget

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

-- Pre-batching perf test done with 20 corhlt firing at once 

if gadgetHandler:IsSyncedCode() then

    local cannonWeapons = {}

    function gadget:Initialize()
        for wdid, wd in pairs(WeaponDefs) do
            if wd.type == "Flame" then
                Script.SetWatchExplosion(wdid, true)
            end
			if wd.type == "Cannon" then
				cannonWeapons[wdid] = true
				Script.SetWatchExplosion(wdid, true)
				if wd.damages[0] >= 20 then
					Script.SetWatchProjectile(wdid, true)
				end
			end
			if wd.type == "LaserCannon" then
				cannonWeapons[wdid] = true
				Script.SetWatchExplosion(wdid, true)
				if wd.damages[0] >= 10 then
					Script.SetWatchProjectile(wdid, true)
				end
			end
			if wd.type == "BeamLaser" then
				Script.SetWatchExplosion(wdid, true)
			end
			if wd.type == "MissileLauncher" then
				Script.SetWatchExplosion(wdid, true)
			end
            if wd.type == "AircraftBomb" then
                Script.SetWatchExplosion(wdid, true)
            end
            if wd.type == "StarburstLauncher" then
                Script.SetWatchExplosion(wdid, true)
            end
            if wd.type == "TorpedoLauncher" then
                Script.SetWatchExplosion(wdid, true)
            end
        end
    end
    function gadget:Shutdown()
        for wdid, wd in pairs(WeaponDefs) do
            if wd.type == "Flame" then
                Script.SetWatchExplosion(wdid, false)
            end
            if wd.type == "Cannon" then
                Script.SetWatchExplosion(wdid, false)
				if wd.damages[0] >= 20 then
					Script.SetWatchProjectile(wdid, false)
				end
            end
        end
    end

    local explosionLightEventCache = {} -- px, py, pz, weaponID, ownerID
    local explosionLightEventSize = 0
    local explosionLightEventStride = 5
    local barrelfireLightEventCache = {} -- px, py, pz, weaponID, ownerID
    local barrelfireLightEventSize = 0
    local barrelfireLightEventStride = 5
    function gadget:Explosion(weaponID, px, py, pz, ownerID, projectileID)
        explosionLightEventCache[explosionLightEventSize + 1] = px
        explosionLightEventCache[explosionLightEventSize + 2] = py
        explosionLightEventCache[explosionLightEventSize + 3] = pz
        explosionLightEventCache[explosionLightEventSize + 4] = weaponID
        explosionLightEventCache[explosionLightEventSize + 5] = ownerID
        explosionLightEventSize = explosionLightEventSize + 5
    end

    function gadget:ProjectileCreated(projectileID, ownerID, weaponID)		-- needs: Script.SetWatchProjectile(weaponDefID, true)
		if cannonWeapons[weaponID] then	-- optionally disable this to pass through missiles too
			local px, py, pz = Spring.GetProjectilePosition(projectileID)
			--SendToUnsynced("barrelfire_light", px, py, pz, weaponID, ownerID)
            barrelfireLightEventCache[barrelfireLightEventSize + 1] = px
            barrelfireLightEventCache[barrelfireLightEventSize + 2] = py
            barrelfireLightEventCache[barrelfireLightEventSize + 3] = pz
            barrelfireLightEventCache[barrelfireLightEventSize + 4] = weaponID
            barrelfireLightEventCache[barrelfireLightEventSize + 5] = ownerID
            barrelfireLightEventSize = barrelfireLightEventSize + 5
		end
    end

    function gadget:GameFramePost()
        if next (explosionLightEventCache) then
            SendToUnsynced("VisibleExplosionBatch", explosionLightEventSize, explosionLightEventStride, unpack(explosionLightEventCache) )
            explosionLightEventCache = {}
            explosionLightEventSize = 0
        end
        
        if next (barrelfireLightEventCache) then
            SendToUnsynced("BarrelfireBatch", barrelfireLightEventSize, barrelfireLightEventStride, unpack(barrelfireLightEventCache) )
            barrelfireLightEventCache = {}
            barrelfireLightEventSize = 0
        end
    end

else	-- Unsynced


    local myAllyID = Spring.GetMyAllyTeamID()
    local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spIsPosInLos = Spring.IsPosInLos
	local spGetSpectatingState = Spring.GetSpectatingState

    function gadget:PlayerChanged(playerID)
        if playerID == Spring.GetMyPlayerID() then
            myAllyID = Spring.GetMyAllyTeamID()
        end
    end

    local function SpawnExplosion(_,px,py,pz, weaponID, ownerID)
		if ownerID ~= nil and Script.LuaUI("VisibleExplosion") then
			if select(2, spGetSpectatingState()) or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) then
				Script.LuaUI.VisibleExplosion(px, py, pz, weaponID, ownerID)
			end
		end
    end

    local function SpawnBarrelfire(_,px,py,pz, weaponID, ownerID)
		if ownerID ~= nil and Script.LuaUI("Barrelfire") then
			if select(2, spGetSpectatingState()) or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) then
				Script.LuaUI.Barrelfire(px, py, pz, weaponID, ownerID)
			end
		end
    end


    local function SendToLuaUIBatched(funcName,elementCount, elementStride, ...)
        -- Ok so fun note, we CAN send tables to luaui. 
        -- But generally, if we send a table, the copy is slower, but the unpack is faster
        -- Since we will unpack more times than we send, we should be better off sending a table

        local BatchFunc = Script.LuaUI(funcName)
        if not BatchFunc then return end

        tracy.ZoneBeginN(funcName)
        BatchFunc = Script.LuaUI[funcName]
        local args = { ... }
        -- is in-place shifting of args table better than a new table?
        -- We are filtering this down to only the visible events here: 
        local spectatingState = select(2, spGetSpectatingState())
        local currentIndex = 0
        --Spring.Echo(elementCount, barrelfireLightEventStride)
        local fargs = args
        for i = 1, elementCount, elementStride do
            local px = args[i]
            local py = args[i + 1]
            local pz = args[i + 2]
            local weaponID = args[i + 3]
            local ownerID = args[i + 4]
            --Spring.Echo(px, py, pz, weaponID, ownerID)
            if ownerID ~= nil and (spectatingState or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID)) then
                fargs[currentIndex + 1] = px
                fargs[currentIndex + 2] = py
                fargs[currentIndex + 3] = pz
                fargs[currentIndex + 4] = weaponID
                fargs[currentIndex + 5] = ownerID
                currentIndex = currentIndex + elementStride
            end
        end
        --Spring.Echo(elementCount, elementStride,args)
        local batchCount = currentIndex / elementStride
        if batchCount > 0 then
            for i = elementCount, currentIndex + 1, -1 do
                args[i] = nil
            end
            BatchFunc(batchCount * elementStride, elementStride, args)
        end

        tracy.ZoneEnd()
        
    end
    function gadget:Initialize()
        gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
        gadgetHandler:AddSyncAction("barrelfire_light", SpawnBarrelfire)
        gadgetHandler:AddSyncAction("VisibleExplosionBatch", SendToLuaUIBatched)
        gadgetHandler:AddSyncAction("BarrelfireBatch", SendToLuaUIBatched)
    end

    function gadget:Shutdown()
        gadgetHandler.RemoveSyncAction("explosion_light")
        gadgetHandler.RemoveSyncAction("barrelfire_light")
        gadgetHandler.RemoveSyncAction("VisibleExplosionBatch")
        gadgetHandler.RemoveSyncAction("BarrelfireBatch")
    end
end
