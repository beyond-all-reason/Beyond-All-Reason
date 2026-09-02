local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Weapon prefire",
		desc = "Raises weapons that rest lowered so they can take targets behind cover",
		author = "Daniel Harvey",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = -1, -- before Target on the move, which calls GG.Prefire
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Missile, cannon and starburst weapons test line of fire from their muzzle piece,
-- both when the engine decides whether to accept a target and when this game's
-- targeting code probes one. When the muzzle rides on an animated piece that rests
-- lowered (Rocketeer), a target the unit could hit once aimed fails that test from
-- the resting pose, the target is refused, and nothing ever raises the arm.
--
-- This gadget finds units whose muzzle piece differs from their AimFromWeapon piece,
-- and whenever such a unit has something to shoot at but the muzzle cannot see it,
-- tests line of fire from the AimFromWeapon piece instead. If that passes, the unit
-- script is asked to aim at the target, which brings the muzzle up in time for the
-- engine's next attempt.

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHeading = Spring.GetUnitHeading
local spGetHeadingFromVector = Spring.GetHeadingFromVector
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local spGetUnitScriptPiece = Spring.GetUnitScriptPiece
local spCallCOBScript = Spring.CallCOBScript
local spGetGameFrame = Spring.GetGameFrame

local asin = math.asin
local max = math.max
local diag = math.diag
local pairsNext = next

local CMD_ATTACK = CMD.ATTACK
local FIRESTATE_FIREATWILL = CMD.FIRESTATE_FIREATWILL
local COB_ANGLE_PER_RADIAN = 65536 / (2 * math.pi)

local pollInterval = 15 -- frames between checks of a unit with nothing on its weapons
local prefireInterval = 30 -- frames between aim requests to one unit

--------------------------------------------------------------------------------
-- Unit defs

-- Weapons that acquire targets on their own, indexed like UnitDef.weapons.
local weaponsByDef = {}
local rangeByDef = {}
for unitDefID = 1, #UnitDefs do
	local unitDef = UnitDefs[unitDefID]
	if unitDef.canAttack and unitDef.maxWeaponRange > 0 then
		local weapons
		for weaponNum, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weapon.slavedTo == 0 and weaponDef.type ~= "Shield" and weaponDef.range > 10 then
				weapons = weapons or {}
				weapons[#weapons + 1] = weaponNum
			end
		end
		if weapons then
			weaponsByDef[unitDefID] = weapons
			rangeByDef[unitDefID] = unitDef.maxWeaponRange
		end
	end
end

-- unitDefID => false when no weapon can be prefired, else { [weaponNum] = aim piece }.
-- Only COB scripts answer AimFromWeaponN/QueryWeaponN this way; Lua-scripted units
-- raise an error and are marked false.
local aimPiecesByDef = {}

local function scriptPiece(unitID, functionName)
	local ok, _, piece = pcall(spCallCOBScript, unitID, functionName, 1, 0)
	if not ok or not piece then
		return nil
	end
	return spGetUnitScriptPiece(unitID, piece)
end

local function resolveAimPieces(unitID, unitDefID)
	local weapons = weaponsByDef[unitDefID]
	local aimPieces = false
	if weapons then
		for i = 1, #weapons do
			local weaponNum = weapons[i]
			local aimPiece = scriptPiece(unitID, "AimFromWeapon" .. weaponNum)
			local muzzlePiece = scriptPiece(unitID, "QueryWeapon" .. weaponNum)
			if aimPiece and muzzlePiece and aimPiece ~= muzzlePiece then
				aimPieces = aimPieces or {}
				aimPieces[weaponNum] = aimPiece
			end
		end
	end
	aimPiecesByDef[unitDefID] = aimPieces
	return aimPieces
end

local function getAimPieces(unitID, unitDefID)
	local aimPieces = aimPiecesByDef[unitDefID]
	if aimPieces == nil then
		aimPieces = resolveAimPieces(unitID, unitDefID)
	end
	return aimPieces
end

--------------------------------------------------------------------------------
-- Prefire

local prefireFrames = {} -- unitID => frame of the last aim request

local function requestAim(unitID, weaponNum, x, y, z)
	local frame = spGetGameFrame()
	if (prefireFrames[unitID] or -prefireInterval) + prefireInterval > frame then
		return
	end
	prefireFrames[unitID] = frame
	local ux, uy, uz = spGetUnitPosition(unitID, true)
	local dx, dy, dz = x - ux, y - uy, z - uz
	local heading = spGetHeadingFromVector(dx, dz) - spGetUnitHeading(unitID)
	if heading > 32767 then
		heading = heading - 65536
	elseif heading < -32768 then
		heading = heading + 65536
	end
	local pitch = asin(dy / max(diag(dx, dy, dz), 1)) * COB_ANGLE_PER_RADIAN
	pcall(spCallCOBScript, unitID, "AimWeapon" .. weaponNum, 0, heading, pitch)
end

local function aimPiecePosition(unitID, weaponNum)
	local aimPieces = getAimPieces(unitID, spGetUnitDefID(unitID))
	local piece = aimPieces and aimPieces[weaponNum]
	if not piece then
		return nil
	end
	return spGetUnitPiecePosDir(unitID, piece)
end

---Call when the muzzle cannot see a ground position that is otherwise targetable.
---Returns true when the aim piece can see it, after asking the unit to aim there.
---@param unitID UnitID
---@param weaponNum integer
---@return boolean
local function prefireTargetPos(unitID, weaponNum, x, y, z)
	local px, py, pz = aimPiecePosition(unitID, weaponNum)
	if not px or not spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, px, py, pz, x, y, z) then
		return false
	end
	requestAim(unitID, weaponNum, x, y, z)
	return true
end

---Call when the muzzle cannot see an enemy unit that is otherwise targetable.
---Returns true when the aim piece can see it, after asking the unit to aim there.
---@param unitID UnitID
---@param weaponNum integer
---@param targetID UnitID
---@return boolean
local function prefireTargetUnit(unitID, weaponNum, targetID)
	local px, py, pz = aimPiecePosition(unitID, weaponNum)
	if not px or not spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, px, py, pz, targetID) then
		return false
	end
	local _, _, _, x, y, z = spGetUnitPosition(targetID, true)
	if x then
		requestAim(unitID, weaponNum, x, y, z)
	end
	return true
end

GG.Prefire = {
	targetPos = prefireTargetPos,
	targetUnit = prefireTargetUnit,
}

--------------------------------------------------------------------------------
-- Attack orders and auto-targeting
--
-- The engine retries a refused Attack target every slow update and searches for
-- auto-targets on its own, so it is enough to notice a tracked unit whose weapons
-- hold no target while it has something to shoot at, and prefire toward that.

local trackedUnits = {} -- unitID => unitDefID, for units with a prefirable weapon

local function hasWeaponTarget(unitID, weapons)
	for i = 1, #weapons do
		local targetType = spGetUnitWeaponTarget(unitID, weapons[i])
		if targetType and targetType ~= 0 then
			return true
		end
	end
	return false
end

local function prefireUnitTarget(unitID, aimPieces, targetID)
	for weaponNum in pairsNext, aimPieces do
		if
			not spGetUnitWeaponTryTarget(unitID, weaponNum, targetID)
			and spGetUnitWeaponTestTarget(unitID, weaponNum, targetID)
			and spGetUnitWeaponTestRange(unitID, weaponNum, targetID)
			and prefireTargetUnit(unitID, weaponNum, targetID)
		then
			return
		end
	end
end

local function prefireGroundTarget(unitID, aimPieces, x, y, z)
	for weaponNum in pairsNext, aimPieces do
		if
			spGetUnitWeaponTestTarget(unitID, weaponNum, x, y, z)
			and spGetUnitWeaponTestRange(unitID, weaponNum, x, y, z)
			and not spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, nil, nil, nil, x, y, z)
			and prefireTargetPos(unitID, weaponNum, x, y, z)
		then
			return
		end
	end
end

local function pollUnit(unitID, unitDefID)
	local aimPieces = aimPiecesByDef[unitDefID]
	if hasWeaponTarget(unitID, weaponsByDef[unitDefID]) then
		return
	end
	local cmdID, _, _, param1, param2, param3 = spGetUnitCurrentCommand(unitID)
	if cmdID == CMD_ATTACK then
		if param2 then
			prefireGroundTarget(unitID, aimPieces, param1, param2, param3)
		else
			prefireUnitTarget(unitID, aimPieces, param1)
		end
	elseif spGetUnitStates(unitID, false) == FIRESTATE_FIREATWILL then
		local enemyID = spGetUnitNearestEnemy(unitID, rangeByDef[unitDefID], true)
		if enemyID then
			prefireUnitTarget(unitID, aimPieces, enemyID)
		end
	end
end

function gadget:GameFrame(frame)
	local slot = frame % pollInterval
	for unitID, unitDefID in pairsNext, trackedUnits do
		if unitID % pollInterval == slot then
			pollUnit(unitID, unitDefID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if weaponsByDef[unitDefID] and getAimPieces(unitID, unitDefID) then
		trackedUnits[unitID] = unitDefID
	end
end

function gadget:UnitDestroyed(unitID)
	trackedUnits[unitID] = nil
	prefireFrames[unitID] = nil
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end
