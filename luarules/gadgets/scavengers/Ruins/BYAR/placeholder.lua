
local function corLonelyWind2(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 64
	if radiusCheck then
		return posradius
	else
		SpawnRuin("corwin", posx, posy, posz, math.random(0,3))
		SpawnRuin("corwin", posx+48, posy, posz, math.random(0,3))
		SpawnRuin("corwin", posx-48, posy, posz, math.random(0,3))
		SpawnRuin("corwin", posx, posy, posz+48, math.random(0,3))
		SpawnRuin("corwin", posx, posy, posz-48, math.random(0,3))
		SpawnRuin("corak", posx+96, posy, posz, math.random(0,3), true)
		SpawnRuin("corak", posx-96, posy, posz, math.random(0,3))
		SpawnRuin("corak", posx, posy, posz+96, math.random(0,3))
		SpawnRuin("corak", posx, posy, posz-96, math.random(0,3))
	end
end
table.insert(RuinsList,corLonelyWind2)

local function armLonelyWind2(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 64
	if radiusCheck then
		return posradius
	else
		SpawnRuin("armwin", posx, posy, posz, math.random(0,3))
		SpawnRuin("armwin", posx+48, posy, posz, math.random(0,3))
		SpawnRuin("armwin", posx-48, posy, posz, math.random(0,3))
		SpawnRuin("armwin", posx, posy, posz+48, math.random(0,3))
		SpawnRuin("armwin", posx, posy, posz-48, math.random(0,3))
		SpawnRuin("armpw", posx+96, posy, posz, math.random(0,3), true)
		SpawnRuin("armpw", posx-96, posy, posz, math.random(0,3))
		SpawnRuin("armpw", posx, posy, posz+96, math.random(0,3))
		SpawnRuin("armpw", posx, posy, posz-96, math.random(0,3), true)
	end
end
table.insert(RuinsList,armLonelyWind2)

local function corLonelyWind(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		SpawnRuin("corsolar", posx, posy, posz, math.random(0,3))

	end
end
table.insert(RuinsList,corLonelyWind)

local function armLonelyWind(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		SpawnRuin("armsolar", posx, posy, posz, math.random(0,3))
	end
end
table.insert(RuinsList,armLonelyWind)


-- Lonely Sonars

local function corLonelyTidal2(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 64
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cortide", posx, posy, posz, math.random(0,3))
		SpawnRuin("cortide", posx+48, posy, posz, math.random(0,3))
		SpawnRuin("cortide", posx-48, posy, posz, math.random(0,3))
		SpawnRuin("cortide", posx, posy, posz+48, math.random(0,3))
		SpawnRuin("cortide", posx, posy, posz-48, math.random(0,3))
	end
end
table.insert(RuinsListSea,corLonelyTidal2)

local function armLonelyTidal2(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 64
	if radiusCheck then
		return posradius
	else
		SpawnRuin("armtide", posx, posy, posz, math.random(0,3))
		SpawnRuin("armtide", posx+48, posy, posz, math.random(0,3))
		SpawnRuin("armtide", posx-48, posy, posz, math.random(0,3))
		SpawnRuin("armtide", posx, posy, posz+48, math.random(0,3))
		SpawnRuin("armtide", posx, posy, posz-48, math.random(0,3))
	end
end
table.insert(RuinsListSea,corLonelyTidal2)

local function corLonelyTidal(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		SpawnRuin("cortide", posx, posy, posz, math.random(0,3))

	end
end
table.insert(RuinsListSea,corLonelyTidal)

local function armLonelyTidal(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		SpawnRuin("armtide", posx, posy, posz, math.random(0,3))
	end
end
table.insert(RuinsListSea,armLonelyTidal)