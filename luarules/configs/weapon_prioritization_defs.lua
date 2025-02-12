--[[
WeaponDefs are assigned a behavior from the following table.
ALL
CANBEUW
COMMANDER
EMPABLE
FASTSURFACE
GROUNDSCOUT
HOVER
LIGHTAIRSCOUT
MINE
MOBILE
NOTAIR
NOTHOVER
NOTMOBILE
NOTSHIP
NOTSUB
NOWEAPON
OBJECT
RAPTOR
SHIP
SURFACE
T4AIR
UNDERWATER
VTOL
WEAPON

]]--
WeaponBehaviors = {
	antiSpam = {
		FASTSURFACE = 1.1,
		GROUNDSCOUT = 1.2
	},
	slowProjectile = {
		FASTSURFACE = 0.5,
		GROUNDSCOUT = 0.2
	},
	highAlpha = {
		FASTSURFACE = 0.9,
		GROUNDSCOUT = 0.2
	},
}

----Unit Type Categorization Functions----
local function unitIsSpam(uDef)
	if (uDef.customParams.purpose and findMatch(uDef.customParams.purpose, "SPAM"))
		or (uDef.health < 400
		and uDef.weapons and next(uDef.weapons)
		and uDef.metalcost and uDef.metalcost < 55)
	then
		return true
	else
		return false
	end
end

local UnitCategorizationFunctions = {
	SPAM = unitIsSpam
}

----Weapon Type Categorization Functions----
local function weaponIsAlphastrike(wDef)
	if wDef.customParams.purpose and wDef.customParams.purpose == "ALPHASTRIKE"
		or wDef.reloadTime and wDef.reloadTime < 3
	then
		return true
	else
		return false
	end
end

local function weaponIsAntispam(wDef)
	if wDef.customParams.purpose and wDef.customParams.purpose == "ANTISPAM"
	then
		return true
	else
		return false
	end
end

local UnitCategorizationFunctions = {
	ALPHASTRIKE = weaponIsAlphastrike,
	ANTISPAM = weaponIsAntispam
}

--zzz next episode: figure out exactly how the weapon checks are gonna work