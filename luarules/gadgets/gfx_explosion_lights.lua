local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Explosion_lights",
		desc = "",
		author = "Floris",
		date = "April 2017",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced
	local spGetProjectilePosition = Spring.GetProjectilePosition

	local explosionTypes = {
		Flame = true,
		Cannon = true,
		LaserCannon = true,
		BeamLaser = true,
		MissileLauncher = true,
		AircraftBomb = true,
		StarburstLauncher = true,
		TorpedoLauncher = true,
	}

	local cannonWeapons = {}
	local watchedExplosions = {}
	local watchedProjectiles = {}

	-- a sim frame's events as x, y, z, weaponDefID, ownerID runs, handed over once in GameFramePost
	local explosions, explosionCount = {}, 0
	local barrelfires, barrelfireCount = {}, 0

	function gadget:Initialize()
		for wdid, wd in pairs(WeaponDefs) do
			if explosionTypes[wd.type] then
				Script.SetWatchExplosion(wdid, true)
				watchedExplosions[wdid] = true
			end
			if wd.type == "Cannon" or wd.type == "LaserCannon" then
				cannonWeapons[wdid] = true
			end
			if wd.type == "Cannon" and wd.damages[0] >= 20 then
				Script.SetWatchProjectile(wdid, true)
				watchedProjectiles[wdid] = true
			elseif wd.type == "LaserCannon" and wd.damages[0] >= 10 then
				Script.SetWatchProjectile(wdid, true)
				watchedProjectiles[wdid] = true
			end
		end
	end

	function gadget:Shutdown()
		for wdid in pairs(watchedExplosions) do
			Script.SetWatchExplosion(wdid, false)
		end
		for wdid in pairs(watchedProjectiles) do
			Script.SetWatchProjectile(wdid, false)
		end
	end

	---@param ownerID UnitID? nil for explosions without an owner
	function gadget:Explosion(weaponID, px, py, pz, ownerID)
		if ownerID then
			local n = explosionCount
			explosions[n + 1] = px
			explosions[n + 2] = py
			explosions[n + 3] = pz
			explosions[n + 4] = weaponID
			explosions[n + 5] = ownerID
			explosionCount = n + 5
		end
	end

	function gadget:ProjectileCreated(projectileID, ownerID, weaponID)
		if cannonWeapons[weaponID] then
			local px, py, pz = spGetProjectilePosition(projectileID)
			local n = barrelfireCount
			barrelfires[n + 1] = px
			barrelfires[n + 2] = py
			barrelfires[n + 3] = pz
			barrelfires[n + 4] = weaponID
			barrelfires[n + 5] = ownerID
			barrelfireCount = n + 5
		end
	end

	function gadget:GameFramePost()
		if explosionCount > 0 then
			SendToUnsynced("explosion_light", explosions, explosionCount)
			explosions, explosionCount = {}, 0
		end
		if barrelfireCount > 0 then
			SendToUnsynced("barrelfire_light", barrelfires, barrelfireCount)
			barrelfires, barrelfireCount = {}, 0
		end
	end
else -- Unsynced
	local myPlayerID = Spring.GetLocalPlayerID()
	local myAllyID = Spring.GetLocalAllyTeamID()
	local fullView = select(2, Spring.GetSpectatingState())
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spIsPosInLos = Spring.IsPosInLos

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myPlayerID = Spring.GetLocalPlayerID()
			myAllyID = Spring.GetLocalAllyTeamID()
			fullView = select(2, Spring.GetSpectatingState())
		end
	end

	-- moves the events the local player can see to the front, in order, and returns their length
	local function keepVisible(events, count)
		if fullView then
			return count
		end
		local kept = 0
		for i = 1, count, 5 do
			local px, py, pz, ownerID = events[i], events[i + 1], events[i + 2], events[i + 4]
			if spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) then
				events[kept + 1] = px
				events[kept + 2] = py
				events[kept + 3] = pz
				events[kept + 4] = events[i + 3]
				events[kept + 5] = ownerID
				kept = kept + 5
			end
		end
		for i = kept + 1, count do
			events[i] = nil
		end
		return kept
	end

	local function SpawnExplosions(_, explosions, count)
		count = keepVisible(explosions, count)
		if count > 0 and Script.LuaUI("VisibleExplosionBatch") then
			Script.LuaUI.VisibleExplosionBatch(explosions, count)
		end
		return true
	end

	local function SpawnBarrelfires(_, barrelfires, count)
		count = keepVisible(barrelfires, count)
		if count > 0 and Script.LuaUI("BarrelfireBatch") then
			Script.LuaUI.BarrelfireBatch(barrelfires, count)
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("explosion_light", SpawnExplosions)
		gadgetHandler:AddSyncAction("barrelfire_light", SpawnBarrelfires)
	end

	function gadget:Shutdown()
		gadgetHandler.RemoveSyncAction("explosion_light")
		gadgetHandler.RemoveSyncAction("barrelfire_light")
	end
end
