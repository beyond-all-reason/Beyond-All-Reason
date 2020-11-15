
local function ixruinwallh(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cordrag", posx+(64), posy, posz+(-32), 1)
		SpawnRuin("cordrag", posx+(128), posy, posz+(-64), 1)
		SpawnRuin("cordrag", posx+(96), posy, posz+(-48), 1)
		SpawnRuin("cordrag", posx+(-96), posy, posz+(48), 1)
		SpawnRuin("corfort", posx+(-32), posy, posz+(48), 1)
		SpawnRuin("cordrag", posx+(-64), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(-16), 1)
		SpawnRuin("corfort", posx+(96), posy, posz+(-16), 1)
		SpawnRuin("cordrag", posx+(-128), posy, posz+(64), 1)
		SpawnRuin("cordrag", posx+(0), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(-96), posy, posz+(16), 1)
		SpawnRuin("corfort", posx+(32), posy, posz+(-48), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(16), 1)
	end
end
table.insert(RuinsList,ixruinwallh)

local function ixruinwallv(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cordrag", posx+(16), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(-16), posy, posz+(-32), 1)
		SpawnRuin("corfort", posx+(48), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(-48), posy, posz+(-96), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(-64), 1)
		SpawnRuin("cordrag", posx+(64), posy, posz+(128), 1)
		SpawnRuin("corfort", posx+(16), posy, posz+(96), 1)
		SpawnRuin("corfort", posx+(-16), posy, posz+(-96), 1)
		SpawnRuin("cordrag", posx+(0), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(64), 1)
		SpawnRuin("cordrag", posx+(48), posy, posz+(96), 1)
		SpawnRuin("corfort", posx+(-48), posy, posz+(-32), 1)
		SpawnRuin("cordrag", posx+(-64), posy, posz+(-128), 1)
	end
end
table.insert(RuinsList,ixruinwallv)

local function ixruinwallalt(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("corfort", posx+(0), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(-64), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(-16), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(64), 1)
		SpawnRuin("corfort", posx+(16), posy, posz+(-32), 1)
	end
end
table.insert(RuinsList,ixruinwallalt)

local function ixruinbiggerwallh(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cordrag", posx+(16), posy, posz+(32), 1)
		SpawnRuin("corfort", posx+(-16), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(48), posy, posz+(-96), 1)
		SpawnRuin("cordrag", posx+(-48), posy, posz+(96), 1)
		SpawnRuin("corfort", posx+(0), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(-32), posy, posz+(64), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(16), posy, posz+(-32), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(32), posy, posz+(-64), 1)
		SpawnRuin("cordrag", posx+(-16), posy, posz+(-32), 1)
	end
end
table.insert(RuinsList,ixruinbiggerwallh)

local function ixruinbiggerwallv(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("corfort", posx+(0), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(-64), 1)
		SpawnRuin("cordrag", posx+(32), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(-16), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(-32), posy, posz+(64), 1)
		SpawnRuin("corfort", posx+(16), posy, posz+(-32), 1)
	end
end
table.insert(RuinsList,ixruinbiggerwallv)

local function ixruinbiggerwallllt(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("corfort", posx+(-32), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(64), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(-16), posy, posz+(32), 1)
		SpawnRuin("cordrag", posx+(-16), posy, posz+(-32), 1)
		SpawnRuin("corfort", posx+(32), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(16), posy, posz+(32), 1)
		SpawnRuin("corfort", posx+(-64), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(0), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(96), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(-96), posy, posz+(0), 1)
		SpawnRuin("cordrag", posx+(16), posy, posz+(-32), 1)
		SpawnRuin("corllt", posx+(-64), posy, posz+(48), 0)
		SpawnRuin("corllt", posx+(64), posy, posz+(-48), 2)
	end
end
table.insert(RuinsList,ixruinbiggerwallllt)

local function ixruinsmall0(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cordrag", posx+(-83), posy, posz+(19), 0)
		SpawnRuin("corfort", posx+(29), posy, posz+(3), 0)
		SpawnRuin("cordrag", posx+(45), posy, posz+(-93), 0)
		SpawnRuin("corfort", posx+(61), posy, posz+(3), 0)
		SpawnRuin("cordrag", posx+(-83), posy, posz+(-13), 0)
		SpawnRuin("cordrag", posx+(-51), posy, posz+(-61), 0)
		SpawnRuin("cordrag", posx+(141), posy, posz+(67), 0)
		SpawnRuin("corfort", posx+(29), posy, posz+(35), 0)
		SpawnRuin("cordrag", posx+(-67), posy, posz+(51), 0)
		SpawnRuin("coreyes", posx+(69), posy, posz+(43), 0)
		SpawnRuin("cordrag", posx+(-83), posy, posz+(-45), 0)
	end
end
table.insert(RuinsList,ixruinsmall0)

local function ixruinsmall1(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 85
	if radiusCheck then
		return posradius
	else
		SpawnRuin("corfort", posx+(-85), posy, posz+(0), 1)
		SpawnRuin("corfort", posx+(75), posy, posz+(64), 1)
		SpawnRuin("cordrag", posx+(59), posy, posz+(-32), 1)
		SpawnRuin("cordrag", posx+(43), posy, posz+(-64), 1)
		SpawnRuin("cordrag", posx+(43), posy, posz+(64), 1)
		SpawnRuin("cordrag", posx+(27), posy, posz+(-96), 1)
		SpawnRuin("cordrag", posx+(-5), posy, posz+(-96), 0)
		SpawnRuin("cordrag", posx+(-85), posy, posz+(32), 1)
		SpawnRuin("corfort", posx+(11), posy, posz+(64), 1)
		SpawnRuin("cordrag", posx+(-85), posy, posz+(-32), 1)
		SpawnRuin("cormaw", posx+(11), posy, posz+(96), 0)
	end
end
table.insert(RuinsList,ixruinsmall1)

local function ixruinsmall2(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cordrag", posx+(7), posy, posz+(85), 0)
		SpawnRuin("cordrag", posx+(-25), posy, posz+(69), 0)
		SpawnRuin("corfort", posx+(39), posy, posz+(85), 0)
		SpawnRuin("cordrag", posx+(-9), posy, posz+(-91), 0)
		SpawnRuin("cormaw", posx+(103), posy, posz+(5), 1)
		SpawnRuin("cordrag", posx+(-89), posy, posz+(37), 0)
		SpawnRuin("cordrag", posx+(-57), posy, posz+(53), 0)
		SpawnRuin("corfort", posx+(-41), posy, posz+(-91), 0)
		SpawnRuin("cordrag", posx+(23), posy, posz+(-75), 0)
		SpawnRuin("corfort", posx+(55), posy, posz+(-75), 0)
	end
end
table.insert(RuinsList,ixruinsmall2)

local function ixtinybase0(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 92
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cormakr", posx+(-36), posy, posz+(-36), 1)
		SpawnRuin("corwin", posx+(44), posy, posz+(-52), 1)
		SpawnRuin("corwin", posx+(92), posy, posz+(-52), 1)
		SpawnRuin("cordrag", posx+(-44), posy, posz+(-76), 1)
		SpawnRuin("cordrag", posx+(-76), posy, posz+(-76), 1)
		SpawnRuin("cordrag", posx+(-76), posy, posz+(-44), 1)
		SpawnRuin("cordrag", posx+(100), posy, posz+(68), 1)
		SpawnRuin("corrad", posx+(-76), posy, posz+(68), 1)
		SpawnRuin("cordrag", posx+(68), posy, posz+(100), 1)
	end
end
table.insert(RuinsList,ixtinybase0)

-- local function armLonelyTidal2(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 64
-- 	if radiusCheck then
-- 		return posradius
-- 	else
-- 		SpawnRuin("armtide", posx, posy, posz, math.random(0,3))
-- 		SpawnRuin("armtide", posx+48, posy, posz, math.random(0,3))
-- 		SpawnRuin("armtide", posx-48, posy, posz, math.random(0,3))
-- 		SpawnRuin("armtide", posx, posy, posz+48, math.random(0,3))
-- 		SpawnRuin("armtide", posx, posy, posz-48, math.random(0,3))
-- 	end
-- end
-- table.insert(RuinsListSea,corLonelyTidal2)