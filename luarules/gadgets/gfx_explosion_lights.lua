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

	function gadget:Explosion(weaponID, px, py, pz, ownerID, projectileID)
		SendToUnsynced("explosion_light", px, py, pz, weaponID, ownerID)
	end

	function gadget:ProjectileCreated(projectileID, ownerID, weaponID)
		if cannonWeapons[weaponID] then
			local px, py, pz = spGetProjectilePosition(projectileID)
			SendToUnsynced("barrelfire_light", px, py, pz, weaponID, ownerID)
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

	local function SpawnExplosion(_, px, py, pz, weaponID, ownerID)
		if ownerID ~= nil and Script.LuaUI("VisibleExplosion") then
			if fullView or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) then
				Script.LuaUI.VisibleExplosion(px, py, pz, weaponID, ownerID)
			end
		end
	end

	local function SpawnBarrelfire(_, px, py, pz, weaponID, ownerID)
		if ownerID ~= nil and Script.LuaUI("Barrelfire") then
			if fullView or spGetUnitAllyTeam(ownerID) == myAllyID or spIsPosInLos(px, py, pz, myAllyID) then
				Script.LuaUI.Barrelfire(px, py, pz, weaponID, ownerID)
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
