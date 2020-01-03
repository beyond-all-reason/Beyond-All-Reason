-- this has to be here on top and nowhere else
local UDN = UnitDefNames




local function placeholderradar1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 150
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrad.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt.id), {posx-100, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt.id), {posx+100, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt.id), {posx, posy, posz-100, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt.id), {posx, posy, posz+100, 0}, {"shift"})
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