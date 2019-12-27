
-- table.insert(ScavengerBlueprintsStart,FunctionName)
-- table.insert(ScavengerBlueprintsT1,FunctionName)
-- table.insert(ScavengerBlueprintsT2,FunctionName)
-- table.insert(ScavengerBlueprintsT3,FunctionName)

-- example blueprint:
-- function a(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 120
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.CreateUnit("corrad", posx, posy, posz, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx-100, posy, posz, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx+100, posy, posz, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx, posy, posz-100, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx, posy, posz+100, math.random(0,3),GaiaTeamID) 
	-- end
-- end
-- table.insert(ScavengerBlueprintsT1,a)

function a(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corrad", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsStart,a)

function b(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armrad", posx, posy, posz, math.random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsStart,b)