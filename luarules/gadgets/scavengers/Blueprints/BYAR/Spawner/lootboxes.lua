
-- table.insert(ScavengerBlueprintsT0,FunctionName)
-- table.insert(ScavengerBlueprintsT1,FunctionName)
-- table.insert(ScavengerBlueprintsT2,FunctionName)
-- table.insert(ScavengerBlueprintsT3,FunctionName)
-- table.insert(ScavengerBlueprintsT0Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT1Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT2Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT3Sea,FunctionName)

-- example blueprint:
-- local function a(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 120
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.CreateUnit("corrad", posx, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx-100, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx+100, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx, posy, posz-100, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx, posy, posz+100, math_random(0,3),GaiaTeamID)
	-- end
-- end
-- table.insert(ScavengerBlueprintsT1,a)

-- Lootboxes

local nameSuffix = '_scav'

local function lootboxgolddrop(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("lootboxgold", posx, posy, posz, math_random(0,3),GaiaTeamID, false, false)

	end
end
table.insert(ScavengerBlueprintsT0,lootboxgolddrop)
table.insert(ScavengerBlueprintsT1,lootboxgolddrop)
table.insert(ScavengerBlueprintsT2,lootboxgolddrop)
table.insert(ScavengerBlueprintsT3,lootboxgolddrop)
