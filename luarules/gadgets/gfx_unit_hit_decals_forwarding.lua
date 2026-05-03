local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Unit Hit Decals Forwarding",
		desc    = "Forwards UnitPreDamaged events with projectile impact position, velocity, and engine-reported hit piece to the Unit Hit Lights widget.",
		author  = "Phase 2",
		date    = "2026-05-03",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local SendToUnsynced              = SendToUnsynced
	local spGetProjectilePosition     = Spring.GetProjectilePosition
	local spGetProjectileVelocity     = Spring.GetProjectileVelocity
	local spGetUnitPosition           = Spring.GetUnitPosition
	local spGetUnitLastAttackedPiece  = Spring.GetUnitLastAttackedPiece
	local spGetUnitPieceMap           = Spring.GetUnitPieceMap

	-- Per-weapon classifier — only forward weapons we'll actually decal.
	local WATCHED_WEAPON_TYPES = {
		Cannon            = true,
		MissileLauncher   = true,
		StarburstLauncher = true,
		TorpedoLauncher   = true,
		EmgCannon         = true,
		AircraftBomb      = true,
		BeamLaser         = true,
		LaserCannon       = true,
		LightningCannon   = true,
		Flame             = true,
	}

	local interestingWeapon = {}

	function gadget:Initialize()
		for wdid, wd in pairs(WeaponDefs) do
			if WATCHED_WEAPON_TYPES[wd.type] then
				interestingWeapon[wdid] = true
			end
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,
	                               weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if paralyzer then return damage, 1 end
		if damage <= 0 then return damage, 1 end
		if not weaponDefID or not interestingWeapon[weaponDefID] then return damage, 1 end

		-- Position: projectile's world position at moment of impact.
		local hx, hy, hz
		if projectileID and projectileID >= 0 then
			hx, hy, hz = spGetProjectilePosition(projectileID)
		end
		if not hx then
			hx, hy, hz = spGetUnitPosition(unitID)
		end
		if not hx then
			return damage, 1
		end

		-- Velocity: direction projectile was traveling at impact (used by widget to
		-- backtrack along the strike vector and land closer to the actual mesh).
		local vx, vy, vz = 0, 0, 0
		if projectileID and projectileID >= 0 then
			local pvx, pvy, pvz = spGetProjectileVelocity(projectileID)
			if pvx then vx, vy, vz = pvx, pvy, pvz end
		end

		-- Engine's piece pick. Returns a piece NAME (string) — convert to index so
		-- we always send a number across the synced/unsynced boundary. -1 = no piece.
		local hitPieceIdx = -1
		local hp = spGetUnitLastAttackedPiece(unitID)
		if type(hp) == "number" then
			hitPieceIdx = hp
		elseif type(hp) == "string" then
			local pieceMap = spGetUnitPieceMap(unitID)
			hitPieceIdx = (pieceMap and pieceMap[hp]) or -1
		end
		local hitPiece = hitPieceIdx

		SendToUnsynced("unitHitDecal", unitID, unitDefID, weaponDefID,
		               attackerID or -1, damage,
		               hx, hy, hz,
		               vx, vy, vz,
		               hitPiece)

		return damage, 1
	end

else

	local function unitHitDecal(_, unitID, unitDefID, weaponDefID, attackerID, damage,
	                            hx, hy, hz, vx, vy, vz, hitPiece)
		if attackerID == -1 then attackerID = nil end
		if hitPiece and hitPiece <= 0 then hitPiece = nil end
		-- Broadcast to both widgets independently. Either may be enabled or disabled.
		if Script.LuaUI("UnitHitDecal") then
			Script.LuaUI.UnitHitDecal(unitID, unitDefID, weaponDefID, attackerID, damage,
			                          hx, hy, hz, vx, vy, vz, hitPiece)
		end
		if Script.LuaUI("UnitHitDecalTextured") then
			Script.LuaUI.UnitHitDecalTextured(unitID, unitDefID, weaponDefID, attackerID, damage,
			                                  hx, hy, hz, vx, vy, vz, hitPiece)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("unitHitDecal", unitHitDecal)
	end

	function gadget:ShutDown()
		gadgetHandler:RemoveSyncAction("unitHitDecal")
	end
end
