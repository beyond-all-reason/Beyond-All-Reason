--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local UDN = UnitDefNames
local nameSuffix = '_scav'

-- local function CopyPasteFunction(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 0
	-- if radiusCheck then
		-- return posradius
	-- else
	-- -- blueprint here
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0,CopyPasteFunction)


-------------ARM T1
local function DamgamWalledTurret1T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret1T1)

local function DamgamWalledTurret2T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret2T1)

local function DamgamWalledTurret3T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armrad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret3T1)

local function DamgamWalledTurret4T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret4T1)

local function DamgamWalledTurret5T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armrl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret5T1)

local function DamgamWalledTurret6T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret6T1)

local function DamgamWalledTurret7T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armdl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret7T1)

local function DamgamWalledTurret8T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armjamt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret8T1)

local function DamgamWalledTurret9T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret9T1)

local function DamgamWalledTurret10T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret10T1)

local function DamgamWalledTurret11T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armcir_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret11T1)

local function DamgamWalledTurret12T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret12T1)



-------------COR T1
local function DamgamWalledTurret13T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret13T1)

local function DamgamWalledTurret14T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret14T1)

local function DamgamWalledTurret15T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret15T1)

local function DamgamWalledTurret16T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret16T1)

local function DamgamWalledTurret17T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret17T1)

local function DamgamWalledTurret18T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret18T1)

local function DamgamWalledTurret19T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret19T1)

local function DamgamWalledTurret20T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret20T1)

local function DamgamWalledTurret21T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret21T1)

local function DamgamWalledTurret22T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret22T1)

local function DamgamWalledTurret23T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret23T1)

local function DamgamWalledTurret24T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamWalledTurret24T1)
















----------------------------------- ARM T2
local function DamgamWalledTurret1T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret1T2)

local function DamgamWalledTurret2T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armsd_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret2T2)

local function DamgamWalledTurret3T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armarad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret3T2)

local function DamgamWalledTurret4T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret4T2)

local function DamgamWalledTurret5T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armtarg_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret5T2)

local function DamgamWalledTurret6T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret6T2)

local function DamgamWalledTurret7T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret7T2)

local function DamgamWalledTurret8T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret8T2)



----------------------------------- COR T2

local function DamgamWalledTurret9T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret9T2)

local function DamgamWalledTurret10T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 32
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret10T2)

local function DamgamWalledTurret11T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corsd_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret11T2)

local function DamgamWalledTurret12T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cortarg_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-24), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret12T2)

local function DamgamWalledTurret13T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret13T2)

local function DamgamWalledTurret14T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret14T2)

local function DamgamWalledTurret15T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 40
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret15T2)

local function DamgamWalledTurret16T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamWalledTurret16T2)








---------- ARM T3
local function DamgamWalledTurret1T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret1T3)

local function DamgamWalledTurret2T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret2T3)

local function DamgamWalledTurret3T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret3T3)

local function DamgamWalledTurret4T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret4T3)

---------- COR T3
local function DamgamWalledTurret5T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret5T3)

local function DamgamWalledTurret6T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret6T3)

local function DamgamWalledTurret7T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret7T3)

local function DamgamWalledTurret8T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 56
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(8), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-8), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-40), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(40), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-24), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(-8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(-40), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(24), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(8), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamWalledTurret8T3)