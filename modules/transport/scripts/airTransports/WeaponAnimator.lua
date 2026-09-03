WeaponAnimator = {}

local aimPieceNum
local firePieceNum
local aimFromPieceNum

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
function WeaponAnimator.FireWeapon(val) end
