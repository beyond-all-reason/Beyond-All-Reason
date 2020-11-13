local nameSuffix = ''


local function corLonelyWind(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corwin"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)

	end
end
table.insert(RuinsList,corLonelyWind)

local function armLonelyWind(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armwin"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
	end
end
table.insert(RuinsList,armLonelyWind)


-- Lonely Sonars

local function corLonelyTidal(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("cortide"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)

	end
end
table.insert(RuinsListSea,corLonelyTidal)

local function armLonelyTidal(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armtide"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
	end
end
table.insert(RuinsListSea,armLonelyTidal)