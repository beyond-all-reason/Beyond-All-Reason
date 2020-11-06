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
local function DamgamEcoStuff1T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 160
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-112), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-112), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-80), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(112), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(112), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(-48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(-48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-112), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(80), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(112), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-80), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(80), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(112), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-112), posy, posz+(160), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff1T1)

local function DamgamEcoStuff2T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 168
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-88), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(120), posy, posz+(136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-120), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-120), posy, posz+(-136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(-48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(88), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(-48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(120), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(88), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-120), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-120), posy, posz+(136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-88), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(120), posy, posz+(-136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(120), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(48), posy, posz+(96), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff2T1)

local function DamgamEcoStuff3T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 121
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-103), posy, posz+(80), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(57), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(121), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(89), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(121), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(41), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(121), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-71), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-103), posy, posz+(-80), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(57), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(89), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(25), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-103), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(-39), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+(-39), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(25), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-71), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-103), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-103), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff3T1)

-- local function DamgamEcoStuff4T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff4T1)

-- local function DamgamEcoStuff5T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armrl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff5T1)

-- local function DamgamEcoStuff6T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff6T1)

-- local function DamgamEcoStuff7T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff7T1)

-- local function DamgamEcoStuff8T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armjamt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff8T1)

-- local function DamgamEcoStuff9T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff9T1)

-- local function DamgamEcoStuff10T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff10T1)

-- local function DamgamEcoStuff11T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armcir_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff11T1)

-- local function DamgamEcoStuff12T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff12T1)



-- -------------COR T1
local function DamgamEcoStuff13T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 160
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(-48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(-48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(112), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-112), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(112), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(112), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-112), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-112), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-112), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(112), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(160), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff13T1)

local function DamgamEcoStuff14T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 168
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-120), posy, posz+(-136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(120), posy, posz+(136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-88), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-120), posy, posz+(136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(-48), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(-48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-120), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(120), posy, posz+(-136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-88), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(120), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(48), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(120), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(88), posy, posz+(168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(88), posy, posz+(-168), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-120), posy, posz+(168), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff14T1)

local function DamgamEcoStuff15T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 112
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(56), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-104), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(24), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(88), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-72), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(88), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-72), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(88), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(24), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(88), posy, posz+(80), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+(-56), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(56), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(88), posy, posz+(-80), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff15T1)

-- local function DamgamEcoStuff16T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff16T1)

-- local function DamgamEcoStuff17T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff17T1)

-- local function DamgamEcoStuff18T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff18T1)

-- local function DamgamEcoStuff19T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordl_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff19T1)

-- local function DamgamEcoStuff20T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff20T1)

-- local function DamgamEcoStuff21T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff21T1)

-- local function DamgamEcoStuff22T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff22T1)

-- local function DamgamEcoStuff23T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff23T1)

-- local function DamgamEcoStuff24T1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamEcoStuff24T1)
















-- ----------------------------------- ARM T2
local function DamgamEcoStuff1T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-128), posy, posz+(-48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+(-56), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-128), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(96), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(128), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+(56), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-128), posy, posz+(48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-96), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(128), posy, posz+(48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(128), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(96), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-96), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(128), posy, posz+(-48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-128), posy, posz+(80), 3}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff1T2)

local function DamgamEcoStuff2T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(0), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-80), posy, posz+(48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-80), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-80), posy, posz+(-48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(80), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(80), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(80), posy, posz+(-48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-80), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(80), posy, posz+(48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(80), 3}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff2T2)

-- local function DamgamEcoStuff3T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armarad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff3T2)

-- local function DamgamEcoStuff4T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff4T2)

-- local function DamgamEcoStuff5T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armtarg_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff5T2)

-- local function DamgamEcoStuff6T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff6T2)

-- local function DamgamEcoStuff7T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff7T2)

-- local function DamgamEcoStuff8T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff8T2)



-- ----------------------------------- COR T2

local function DamgamEcoStuff9T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-96), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-128), posy, posz+(-40), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+(56), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(128), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-128), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-96), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(128), posy, posz+(-40), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(96), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(128), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(128), posy, posz+(40), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-128), posy, posz+(40), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-128), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+(-56), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(96), posy, posz+(72), 3}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff9T2)

local function DamgamEcoStuff10T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(80), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(80), posy, posz+(-48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(0), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-80), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(80), posy, posz+(48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-80), posy, posz+(-48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-80), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(80), posy, posz+(80), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-80), posy, posz+(48), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-80), 3}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff10T2)

-- local function DamgamEcoStuff11T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corsd_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff11T2)

-- local function DamgamEcoStuff12T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortarg_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-24), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff12T2)

-- local function DamgamEcoStuff13T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff13T2)

-- local function DamgamEcoStuff14T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff14T2)

-- local function DamgamEcoStuff15T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 40
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(8), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-8), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-40), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff15T2)

-- local function DamgamEcoStuff16T2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT2,DamgamEcoStuff16T2)








-- ---------- ARM T3
local function DamgamEcoStuff1T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 208
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(-48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(-48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-176), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(-128), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(-112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(-16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(176), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(112), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(-128), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(128), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-64), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(-16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-112), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(64), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(144), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-176), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(128), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-144), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(64), posy, posz+(-96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(128), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-64), posy, posz+(-96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(144), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-112), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(176), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-144), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(-128), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(112), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(-112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(208), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-208), posy, posz+(144), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff1T3)

local function DamgamEcoStuff2T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 270
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(174), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-98), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(62), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(126), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-130), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-34), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-194), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-66), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(206), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(126), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-194), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-146), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-162), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(126), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(94), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(270), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(206), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+(-114), posy, posz+(104), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(270), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(270), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(30), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(270), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(206), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(142), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-2), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(-146), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(142), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-98), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+(-42), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(166), posy, posz+(-136), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-162), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmmkr_scav.id), {posx+(142), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-130), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(238), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+(54), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-66), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(270), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-26), posy, posz+(184), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(270), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-226), posy, posz+(-192), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff2T3)

local function DamgamEcoStuff3T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 214
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(-122), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(166), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(214), posy, posz+(-58), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(54), posy, posz+(166), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-42), posy, posz+(-154), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-106), posy, posz+(198), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-10), posy, posz+(198), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(-58), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armtarg_scav.id), {posx+(62), posy, posz+(94), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(102), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(-26), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-106), posy, posz+(-154), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(182), posy, posz+(-154), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(214), posy, posz+(-154), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(134), posy, posz+(102), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(-58), posy, posz+(-58), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(70), posy, posz+(-58), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(134), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(22), posy, posz+(-138), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(86), posy, posz+(-154), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(134), posy, posz+(-58), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(6), posy, posz+(-58), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(118), posy, posz+(-154), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(54), posy, posz+(198), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(-90), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(150), posy, posz+(-154), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-42), posy, posz+(198), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(214), posy, posz+(-90), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(-154), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(22), posy, posz+(198), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-74), posy, posz+(-154), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(70), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx+(-42), posy, posz+(102), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(214), posy, posz+(-122), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-138), posy, posz+(198), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-74), posy, posz+(198), 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff3T3)

-- local function DamgamEcoStuff4T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armfort_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff4T3)

-- ---------- COR T3
local function DamgamEcoStuff5T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 208
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(-16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(-16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-112), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(176), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-64), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(-48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(64), posy, posz+(-96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(128), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-64), posy, posz+(-96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(-112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(112), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(-112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-128), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-128), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-112), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(128), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-176), posy, posz+(144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(64), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-128), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(-48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(16), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(176), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(48), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(208), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(128), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(112), posy, posz+(-144), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-208), posy, posz+(112), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-176), posy, posz+(-144), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff5T3)

local function DamgamEcoStuff6T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 170
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(110), posy, posz+(-141), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(142), posy, posz+(-45), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(78), posy, posz+(-141), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-114), posy, posz+(179), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(142), posy, posz+(-77), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(46), posy, posz+(-141), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(142), posy, posz+(-13), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-178), posy, posz+(115), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+(54), posy, posz+(-53), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-50), posy, posz+(115), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-170), posy, posz+(-133), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-50), posy, posz+(51), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(142), posy, posz+(-109), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-114), posy, posz+(147), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(14), posy, posz+(-141), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+(-42), posy, posz+(-53), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(134), posy, posz+(171), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(30), posy, posz+(131), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+(54), posy, posz+(43), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-114), posy, posz+(115), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(142), posy, posz+(-141), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+(-114), posy, posz+(51), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-146), posy, posz+(115), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-130), posy, posz+(-29), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff6T3)

local function DamgamEcoStuff7T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 181
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-149), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-93), posy, posz+(159), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(107), posy, posz+(151), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-117), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-181), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-181), posy, posz+(55), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(-109), posy, posz+(79), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-181), posy, posz+(87), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(123), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(75), posy, posz+(-57), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(155), posy, posz+(-89), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(155), posy, posz+(-121), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(59), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-149), posy, posz+(151), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortarg_scav.id), {posx+(-5), posy, posz+(-65), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-181), posy, posz+(151), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(139), posy, posz+(119), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(19), posy, posz+(159), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(155), posy, posz+(-57), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(139), posy, posz+(55), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(91), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(139), posy, posz+(151), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(-101), posy, posz+(-73), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(51), posy, posz+(79), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-181), posy, posz+(119), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(75), posy, posz+(151), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(139), posy, posz+(87), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(155), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(-29), posy, posz+(79), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-85), posy, posz+(-153), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-13), posy, posz+(-145), 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff7T3)

-- local function DamgamEcoStuff8T3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 56
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(8), posy, posz+(56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-8), posy, posz+(-56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-40), posy, posz+(-56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(40), posy, posz+(56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-24), posy, posz+(56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(-8), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(-40), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(24), posy, posz+(-56), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(8), 1}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT3,DamgamEcoStuff8T3)