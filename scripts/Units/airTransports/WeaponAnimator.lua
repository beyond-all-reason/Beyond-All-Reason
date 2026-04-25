WeaponAnimator = {}

local aimPieceNum
local firePieceNum
local aimFromPieceNum

function WeaponAnimator.Init(setup)
	aimPieceNum = piece(setup.aimPiece)
	firePieceNum = piece(setup.firePiece)
	aimFromPieceNum = piece(setup.aimFromPiece)
	Hide(firePieceNum)
end

function WeaponAnimator.AimFromWeapon()
	return aimFromPieceNum
end

function WeaponAnimator.AimWeapon(heading, pitch)
	Turn(aimPieceNum, 1, -pitch, 100)
	return true
end

function WeaponAnimator.QueryWeapon()
	return firePieceNum
end

function WeaponAnimator.FireWeapon(val)
end