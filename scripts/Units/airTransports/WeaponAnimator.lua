WeaponAnimator = {}

-- VARIABLES
local aimPieceNum
local firePieceNum
local aimFromPieceNum

-- MODULE FUNCTIONS
-- function WeaponAnimator.Init(...)         -- Resolve aim/fire/aimFrom piece names from setup; hide fire piece at startup
-- function WeaponAnimator.AimFromWeapon()   -- Return the aimFrom piece ID for the engine aim-from query
-- function WeaponAnimator.AimWeapon(...)    -- Rotate aim piece toward target heading/pitch; return true to confirm aim
-- function WeaponAnimator.QueryWeapon()     -- Return the fire piece ID for the engine weapon query
-- function WeaponAnimator.FireWeapon(...)   -- Fire animation hook (currently a no-op placeholder)

---@param setup table
function WeaponAnimator.Init(setup)
	aimPieceNum = piece(setup.aimPiece)
	firePieceNum = piece(setup.firePiece)
	aimFromPieceNum = piece(setup.aimFromPiece)
	Hide(firePieceNum)
end

---@return number pieceNumber
function WeaponAnimator.AimFromWeapon()
	return aimFromPieceNum
end

---@param heading number
---@param pitch number
---@return boolean
function WeaponAnimator.AimWeapon(heading, pitch)
	Turn(aimPieceNum, 1, -pitch, 100)
	return true
end

---@return number pieceNumber
function WeaponAnimator.QueryWeapon()
	return firePieceNum
end

---@param val number  weapon state value passed by the engine
function WeaponAnimator.FireWeapon(val)
end