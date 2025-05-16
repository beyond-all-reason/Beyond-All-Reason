
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
        explosionLightEventSize = explosionLightEventSize + 1
        explosionLightEventCache[explosionLightEventSize] = px
        explosionLightEventSize = explosionLightEventSize + 1
        explosionLightEventCache[explosionLightEventSize] = py
        explosionLightEventSize = explosionLightEventSize + 1
        explosionLightEventCache[explosionLightEventSize] = pz
        explosionLightEventSize = explosionLightEventSize + 1
        explosionLightEventCache[explosionLightEventSize] = weaponID
        explosionLightEventSize = explosionLightEventSize + 1
        explosionLightEventCache[explosionLightEventSize] = ownerID
        --SendToUnsynced("explosion_light", px, py, pz, weaponID, ownerID)
        
    end

    function gadget:ProjectileCreated(projectileID, ownerID, weaponID)		-- needs: Script.SetWatchProjectile(weaponDefID, true)
		if cannonWeapons[weaponID] then	-- optionally disable this to pass through missiles too
			local px, py, pz = Spring.GetProjectilePosition(projectileID)
			--SendToUnsynced("barrelfire_light", px, py, pz, weaponID, ownerID)
            barrelfireLightEventSize = barrelfireLightEventSize + 1
            barrelfireLightEventCache[barrelfireLightEventSize] = px
            barrelfireLightEventSize = barrelfireLightEventSize + 1
            barrelfireLightEventCache[barrelfireLightEventSize] = py
            barrelfireLightEventSize = barrelfireLightEventSize + 1
            barrelfireLightEventCache[barrelfireLightEventSize] = pz
            barrelfireLightEventSize = barrelfireLightEventSize + 1
            barrelfireLightEventCache[barrelfireLightEventSize] = weaponID
            barrelfireLightEventSize = barrelfireLightEventSize + 1
            barrelfireLightEventCache[barrelfireLightEventSize] = ownerID

		end
    end

    function gadget:GameFramePost()
        if next (explosionLightEventCache) then
            SendToUnsynced("explosion_light_batched", explosionLightEventSize, explosionLightEventStride, unpack(explosionLightEventCache) )
            explosionLightEventCache = {}
            explosionLightEventSize = 0
        end
        
        if next (barrelfireLightEventCache) then
            SendToUnsynced("barrelfire_light_batched", barrelfireLightEventSize, barrelfireLightEventStride, unpack(barrelfireLightEventCache) )
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
    local function SpawnExplosionBatched(_,explosionLightEventSize, explosionLightEventStride, ...)
        local VisibleExplosionBatch = Script.LuaUI("VisibleExplosionBatch")
        if not VisibleExplosionBatch then
            return
        end
        VisibleExplosionBatch = Script.LuaUI.VisibleExplosionBatch
        tracy.ZoneBeginN("SpawnExplosionBatched")
        local args = { ... }
        -- is in-place shifting of args table better than a new table?
        -- We need to know last status as that tells us if we are finished with a batch 
        -- We are filtering this down to only the visible events here: 

        local spectatingState = select(2, spGetSpectatingState())
        local currentIndex = 0
        for i = 1, explosionLightEventSize, explosionLightEventStride do
            local px = args[i]
            local py = args[i + 1]
            local pz = args[i + 2]
            local weaponID = args[i + 3]
            local ownerID = args[i + 4]
            if ownerID ~= nil and (spectatingState or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID)) then
                args[currentIndex + 1] = px
                args[currentIndex + 2] = py
                args[currentIndex + 3] = pz
                args[currentIndex + 4] = weaponID
                args[currentIndex + 5] = ownerID
                currentIndex = currentIndex + explosionLightEventStride
            end
        end
        local batchCount = currentIndex / explosionLightEventStride
        tracy.ZoneEnd()
        
        if batchCount > 0 then
            VisibleExplosionBatch(batchCount, explosionLightEventStride, unpack(args))
        end
        --local batchEndMarker = currentIndex + (explosionLightEventStride-1)
        --for i = 1, currentIndex , explosionLightEventStride do
        --    VisibleExplosionFunction(args[i], args[i + 1], args[i + 2], args[i + 3], args[i + 4], batchCount, i == batchEndMarker)
        --end
    end
    local function SpawnBarrelfireBatched(_,barrelfireLightEventSize, barrelfireLightEventStride, ...)
        local BarrelfireBatch = Script.LuaUI("BarrelfireBatch")
        if not BarrelfireBatch then
            return
        end
        BarrelfireBatch = Script.LuaUI.BarrelfireBatch
        tracy.ZoneBeginN("SpawnBarrelfireBatched")
        local args = { ... }
        -- is in-place shifting of args table better than a new table?
        -- We need to know last status as that tells us if we are finished with a batch 
        -- We are filtering this down to only the visible events here: 
        local spectatingState = select(2, spGetSpectatingState())
        local currentIndex = 0
        --Spring.Echo(barrelfireLightEventSize, barrelfireLightEventStride)
        for i = 1, barrelfireLightEventSize, barrelfireLightEventStride do
            local px = args[i]
            local py = args[i + 1]
            local pz = args[i + 2]
            local weaponID = args[i + 3]
            local ownerID = args[i + 4]
            --Spring.Echo(px, py, pz, weaponID, ownerID)
            if ownerID ~= nil and (spectatingState or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID)) then
                args[currentIndex + 1] = px
                args[currentIndex + 2] = py
                args[currentIndex + 3] = pz
                args[currentIndex + 4] = weaponID
                args[currentIndex + 5] = ownerID
                currentIndex = currentIndex + barrelfireLightEventStride
            end
        end
        --Spring.Echo(barrelfireLightEventSize, barrelfireLightEventStride,args)
        local batchCount = currentIndex / barrelfireLightEventStride
        if batchCount > 0 then
            BarrelfireBatch(batchCount, barrelfireLightEventStride, unpack(args))
        end

        tracy.ZoneEnd()
        
        --local batchEndMarker = currentIndex + (barrelfireLightEventStride-1)
        --for i = 1, currentIndex , barrelfireLightEventStride do
        --    BarrelfireFunction(args[i], args[i + 1], args[i + 2], args[i + 3], args[i + 4], batchCount, i == batchEndMarker)
        --end
    end
    function gadget:Initialize()
        gadgetHandler:AddSyncAction("explosion_light", SpawnExplosion)
        gadgetHandler:AddSyncAction("barrelfire_light", SpawnBarrelfire)
        gadgetHandler:AddSyncAction("explosion_light_batched", SpawnExplosionBatched)
        gadgetHandler:AddSyncAction("barrelfire_light_batched", SpawnBarrelfireBatched)
    end

    function gadget:Shutdown()
        gadgetHandler.RemoveSyncAction("explosion_light")
        gadgetHandler.RemoveSyncAction("barrelfire_light")
        gadgetHandler.RemoveSyncAction("explosion_light_batched")
        gadgetHandler.RemoveSyncAction("barrelfire_light_batched")
    end
end
