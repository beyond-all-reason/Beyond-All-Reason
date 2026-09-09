local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Projectile launch alignment",
		desc = "Keeps a projectile aligned with its launch piece until it travels clear of the weapon",
		author = "Egzothicki",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPieceMap = Spring.GetUnitPieceMap
local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local spSetProjectilePosition = Spring.SetProjectilePosition

local railWeaponDefs = {} -- [weaponDefID] = { length, pieceNames }
local piecesByUnitDef = {} -- [weaponDefID] = { [unitDefID] = resolved piece numbers }
local railedProjectiles = {} -- [projectileID] = { ownerID, pieceNumber, direction, length }

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		local length = tonumber(weaponDef.customParams.launchrail_length)
		local pieceList = weaponDef.customParams.launchrail_pieces
		if length and length > 0 and pieceList then
			local pieceNames = {}
			for pieceName in pieceList:gmatch("%S+") do
				pieceNames[#pieceNames + 1] = pieceName
			end
			if pieceNames[1] then
				railWeaponDefs[weaponDefID] = { length = length, pieceNames = pieceNames }
				piecesByUnitDef[weaponDefID] = {}
			end
		end
	end

	if not next(railWeaponDefs) then
		gadgetHandler:RemoveGadget(self)
		return
	end

	for weaponDefID in pairs(railWeaponDefs) do
		Script.SetWatchProjectile(weaponDefID, true)
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	local rail = railWeaponDefs[weaponDefID]
	if not rail or not proOwnerID then
		return
	end

	local unitDefID = spGetUnitDefID(proOwnerID)
	if not unitDefID then
		return
	end

	local pieceNumbers = piecesByUnitDef[weaponDefID][unitDefID]
	if not pieceNumbers then
		pieceNumbers = {}
		local pieceMap = spGetUnitPieceMap(proOwnerID)
		for index = 1, #rail.pieceNames do
			pieceNumbers[#pieceNumbers + 1] = pieceMap[rail.pieceNames[index]]
		end
		piecesByUnitDef[weaponDefID][unitDefID] = pieceNumbers
	end

	local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
	local pieceNumber, bestDistanceSq
	for index = 1, #pieceNumbers do
		local pieceX, pieceY, pieceZ = spGetUnitPiecePosDir(proOwnerID, pieceNumbers[index])
		if pieceX then
			local deltaX, deltaY, deltaZ = pieceX - positionX, pieceY - positionY, pieceZ - positionZ
			local distanceSq = deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ
			if not bestDistanceSq or distanceSq < bestDistanceSq then
				bestDistanceSq, pieceNumber = distanceSq, pieceNumbers[index]
			end
		end
	end
	if not pieceNumber then
		return
	end

	local directionX, directionY, directionZ = spGetProjectileDirection(projectileID)
	if not directionX or (directionX == 0 and directionY == 0 and directionZ == 0) then
		directionX, directionY, directionZ = 0, 1, 0
	end

	railedProjectiles[projectileID] = {
		ownerID = proOwnerID,
		pieceNumber = pieceNumber,
		directionX = directionX,
		directionY = directionY,
		directionZ = directionZ,
		length = rail.length,
	}
end

function gadget:ProjectileDestroyed(projectileID)
	railedProjectiles[projectileID] = nil
end

function gadget:GameFramePost(frame)
	for projectileID, rail in pairs(railedProjectiles) do
		local released = true

		if spGetUnitIsDead(rail.ownerID) == false and spGetProjectileTimeToLive(projectileID) > 0 then
			local anchorX, anchorY, anchorZ = spGetUnitPiecePosDir(rail.ownerID, rail.pieceNumber)
			if anchorX then
				local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
				local travel = (positionX - anchorX) * rail.directionX
					+ (positionY - anchorY) * rail.directionY
					+ (positionZ - anchorZ) * rail.directionZ

				if travel < rail.length then
					spSetProjectilePosition(
						projectileID,
						anchorX + rail.directionX * travel,
						anchorY + rail.directionY * travel,
						anchorZ + rail.directionZ * travel
					)
					released = false
				end
			end
		end

		if released then
			railedProjectiles[projectileID] = nil
		end
	end
end
