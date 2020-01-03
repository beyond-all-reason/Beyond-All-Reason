-- this has to be here on top of every blueprint file
local UDN = UnitDefNames

--	 facing:
--   0 - south
--   1 - east
--   2 - north
--   3 - west





local function placeholderradar1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 150
local unitoptions = {UDN.corllt.id, UDN.corrl.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrad.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+100, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+100, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsStart,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsT1,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsT2,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsT3,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsStartSea,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsT1Sea,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsT2Sea,placeholderradar1)
table.insert(ScavengerConstructorBlueprintsT3Sea,placeholderradar1)