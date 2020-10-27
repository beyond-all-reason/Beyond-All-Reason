-- this has to be here on top of every blueprint file
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

--	possible tables:
--	table.insert(ScavengerConstructorBlueprintsT0,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT1,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT2,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT3,nameoffunction)

local nameSuffix = '_scav'

-- FACTORIES

local function scavlabt1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {}
	local r = math_random(0,5)
	local posradius = 120
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(64), posy, posz+(3), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormstor_scav.id), {posx+(120), posy, posz+(75), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-104), posy, posz+(11), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(144), posy, posz+(-29), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-80), posy, posz+(131), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(-64), posy, posz+(3), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(0), posy, posz+(-93), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(80), posy, posz+(131), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormstor_scav.id), {posx+(-120), posy, posz+(75), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(0), posy, posz+(-173), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx+(0), posy, posz+(67), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(104), posy, posz+(11), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-144), posy, posz+(-29), 3}, {"shift"})
			
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-125), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(99), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(67), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-64), posy, posz+(35), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(35), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-141), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(144), posy, posz+(3), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-64), posy, posz+(67), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-64), posy, posz+(99), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(112), posy, posz+(-29), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-112), posy, posz+(-29), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-125), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-141), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-144), posy, posz+(3), 0}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 2 then
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-80), posy, posz+(-90), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(72), posy, posz+(62), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(72), posy, posz+(94), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(72), posy, posz+(30), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(144), posy, posz+(86), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-72), posy, posz+(62), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-144), posy, posz+(86), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(104), posy, posz+(30), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(80), posy, posz+(-90), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx+(0), posy, posz+(54), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-104), posy, posz+(30), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-72), posy, posz+(94), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-72), posy, posz+(30), 0}, {"shift"})
			
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(-50), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-72), posy, posz+(-50), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-82), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(104), posy, posz+(-50), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-82), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-40), posy, posz+(-50), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(40), posy, posz+(-50), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(72), posy, posz+(-50), 0}, {"shift"})
		elseif r == 3 then
			Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 4 then
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(25), posy, posz+(-159), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(81), posy, posz+(25), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(65), posy, posz+(-183), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(65), posy, posz+(185), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(113), posy, posz+(9), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-63), posy, posz+(-87), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(81), posy, posz+(-7), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(33), posy, posz+(-199), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(81), posy, posz+(-39), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-127), posy, posz+(-23), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corap_scav.id), {posx+(-31), posy, posz+(9), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(33), posy, posz+(201), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-23), posy, posz+(-63), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(-63), posy, posz+(-55), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(-63), posy, posz+(73), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(25), posy, posz+(161), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(81), posy, posz+(57), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-95), posy, posz+(-55), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-127), posy, posz+(-55), 2}, {"shift"})
			
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(65), posy, posz+(-151), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-63), posy, posz+(105), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-31), posy, posz+(89), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(65), posy, posz+(153), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-159), posy, posz+(-55), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(113), posy, posz+(-23), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(113), posy, posz+(41), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-175), posy, posz+(-23), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-111), posy, posz+(57), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-95), posy, posz+(89), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(145), posy, posz+(-7), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-95), posy, posz+(-87), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(1), posy, posz+(-199), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(145), posy, posz+(25), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(1), posy, posz+(201), 0}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.armap_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavlabt1)

local function scavlabt2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {}
	local r = math_random(0,5)
	local posradius = 70
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.coralab_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(UDN.armalab_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(UDN.coravp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
			elseif r == 3 then
				Spring.GiveOrderToUnit(scav, -(UDN.armavp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
			elseif r == 4 then
				Spring.GiveOrderToUnit(scav, -(UDN.coraap_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.armaap_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})

		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavlabt2)
table.insert(ScavengerConstructorBlueprintsT3,scavlabt2)

-- ECO BUILDINGS

local function scavmetalmakerst1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 88
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx-32, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+32, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx-32, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+32, posy, posz+32, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-72, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-40, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-8, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-72, posy, posz-40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-72, posy, posz-8, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+72, posy, posz+72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+72, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+72, posy, posz+8, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+40, posy, posz+72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+8, posy, posz+72, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavmetalmakerst1)
table.insert(ScavengerConstructorBlueprintsT1,scavmetalmakerst1)

local function scavmetalmakerst2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx-40, posy, posz-40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+40, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx-40, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+40, posy, posz-40, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-104, posy, posz-104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-72, posy, posz-104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-40, posy, posz-104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-104, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-104, posy, posz-40, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+104, posy, posz+104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+104, posy, posz+72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+104, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+72, posy, posz+104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+40, posy, posz+104, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavmetalmakerst2)
table.insert(ScavengerConstructorBlueprintsT3,scavmetalmakerst2)

local function scavpowerplants(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	local r = math_random(0,2)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(-80), posy, posz+(80), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-16), posy, posz+(64), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(64), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(16), posy, posz+(-64), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-64), posy, posz+(16), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-80), posy, posz+(-96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(80), posy, posz+(96), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(-144), posy, posz+(144), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(144), posy, posz+(-144), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(104), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(104), posy, posz+(24), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(72), posy, posz+(24), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(-24), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-72), posy, posz+(-24), 1}, {"shift"})
			elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(-40), posy, posz+(-40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(40), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(40), posy, posz+(-40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(-40), posy, posz+(40), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(104), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-8), posy, posz+(-104), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(8), posy, posz+(104), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-104), posy, posz+(8), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(144), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(144), posy, posz+(16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(112), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(144), posy, posz+(-48), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-144), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-112), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-144), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-144), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-144), posy, posz+(16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-144), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-144), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-112), posy, posz+(48), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(112), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(144), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(144), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(144), 1}, {"shift"})
			else
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-40), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(64), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-64), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(40), posy, posz+(-40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-64), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(32), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(40), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(0), posy, posz+(128), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-40), posy, posz+(-40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(0), posy, posz+(-128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-32), 1}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavpowerplants)
table.insert(ScavengerConstructorBlueprintsT2,scavpowerplants)

local function scavmstoredual(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormstor_scav.id), {posx-40, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormstor_scav.id), {posx+40, posy, posz, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-96, posy, posz-80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz-80, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+96, posy, posz+80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+64, posy, posz+80, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavmstoredual)
table.insert(ScavengerConstructorBlueprintsT2,scavmstoredual)
table.insert(ScavengerConstructorBlueprintsT3,scavmstoredual)

-- SMALL RADAR OUTPOSTS

local function scavradaronlyoutpost(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 88
local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.cornanotc_scav.id,}
	local r = math_random(0,1)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-88, posy, posz, 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+88, posy, posz, 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz-88, 2}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz+88, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(0), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(0), 1}, {"shift"})
				
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(32), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-32), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(32), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-32), 1}, {"shift"})
			end

	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaronlyoutpost)
table.insert(ScavengerConstructorBlueprintsT1,scavradaronlyoutpost)

local function scavradaroutpostsmallred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 70
local unitoptions = {UDN.corrad_scav.id, UDN.coreyes_scav.id, UDN.corwin_scav.id, UDN.corjamt_scav.id, UDN.cornanotc_scav.id,}
local defenseoptions = {UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corrl_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+40, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-40, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx, posy, posz+60, 3}, {"shift"})


	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaroutpostsmallred)
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostsmallred)

-- ROADBLOCKS

local function roadblocks(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptionsblue = {UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armclaw_scav.id,}
	local unitoptionsred = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	local posradius = 80
	local r = math_random(0,7)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+64, posy, posz+64, 0}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+64, posy, posz-64, 0}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+64, posy, posz, 0}, {"shift"})
			elseif r == 3 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz-64, 0}, {"shift"})
			elseif r == 4 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+64, posy, posz+64, 0}, {"shift"})
			elseif r == 5 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+64, posy, posz-64, 0}, {"shift"})
			elseif r == 6 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+64, posy, posz, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz-64, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,roadblocks)
table.insert(ScavengerConstructorBlueprintsT1,roadblocks)

-- WALL OF TURRETS (lines)

local function scavwallofturrets(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id,}
	local posradius = 112
	local r = math_random(0,3)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-64, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+64, posy, posz-32, 0}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-32, posy, posz+64, 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+32, posy, posz-64, 1}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-96, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+96, posy, posz, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz-96, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz+96, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavwallofturrets)
table.insert(ScavengerConstructorBlueprintsT1,scavwallofturrets)

local function scavwallofturretsadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id,}
	local r = math_random(0,1)
	local posradius = 100
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+100, posy, posz-60, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+50, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx-50, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-100, posy, posz+60, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+60, posy, posz-100, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+32, posy, posz-50, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx-32, posy, posz+50, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-60, posy, posz+100, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavwallofturretsadv)
table.insert(ScavengerConstructorBlueprintsT3,scavwallofturretsadv)

local function scavadvsol(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corllt_scav.id, UDN.corrad_scav.id, UDN.corjamt_scav.id,}
	local unitoptions2 = {UDN.armllt_scav.id, UDN.armrad_scav.id, UDN.armjamt_scav.id,}
	local r = math_random(0,1)
	local x1 = math_random(-48,48)
	local x2 = math_random(-48,48)
	local posradius = 112
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+x1, posy, posz-120, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx-40, posy, posz-40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+40, posy, posz-40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx-40, posy, posz+40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+40, posy, posz+40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+x2, posy, posz+120, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptions2[math_random(1,#unitoptions2)]), {posx+x1, posy, posz-112, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions2[math_random(1,#unitoptions2)]), {posx+x2, posy, posz+112, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavadvsol)
table.insert(ScavengerConstructorBlueprintsT2,scavadvsol)

-- MEDIUM RADAR OUTPOSTS

local function scavradaroutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+96, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-96, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz-96, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+32, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+128, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz+32, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostred)
table.insert(ScavengerConstructorBlueprintsT2,scavradaroutpostred)

local function scavartyoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.corrad_scav.id, UDN.coreyes_scav.id, UDN.corjamt_scav.id, UDN.cornanotc_scav.id,}
local unitoptions2 = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+100, posy, posz+25, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-100, posy, posz-25, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-32, posy, posz+80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions2[math_random(1,#unitoptions2)]), {posx, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+32, posy, posz+112, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-32, posy, posz-112, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions2[math_random(1,#unitoptions2)]), {posx, posy, posz-96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+32, posy, posz-80, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavartyoutpostred)
table.insert(ScavengerConstructorBlueprintsT2,scavartyoutpostred)

-- MEDIUM ARTILLERY BASES

local function scavartyoutpostredadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+25, posy, posz+100, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-25, posy, posz-128, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz+64, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+192, posy, posz+128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+128, posy, posz+64, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavartyoutpostredadv)
table.insert(ScavengerConstructorBlueprintsT3,scavartyoutpostredadv)

-- JAMMED AA BASES

local function scavaaoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local unitoptions = {UDN.corarad_scav.id, UDN.corvipe_scav.id, UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.cormadsam_scav.id,}
	local posradius = 120
	local r = math_random(0,1)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx-48, posy, posz-48, 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+48, posy, posz+48, 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx-48, posy, posz+48, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+48, posy, posz-48, 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz+48, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz+80, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-48, posy, posz+80, 0}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz-48, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz-80, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+48, posy, posz-80, 0}, {"shift"})
			else
			Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(-93), posy, posz+(-1), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(35), posy, posz+(15), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-77), posy, posz+(-49), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(35), posy, posz+(111), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-109), posy, posz+(47), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(83), posy, posz+(63), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-141), posy, posz+(15), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-45), posy, posz+(15), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(19), posy, posz+(-81), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-45), posy, posz+(-17), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(19), posy, posz+(-145), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(131), posy, posz+(111), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(131), posy, posz+(15), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-141), posy, posz+(-17), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-77), posy, posz+(47), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-109), posy, posz+(-49), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(19), posy, posz+(-113), 1}, {"shift"})
			
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(99), posy, posz+(15), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-13), posy, posz+(-97), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-141), posy, posz+(47), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(35), posy, posz+(47), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(131), posy, posz+(47), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-45), posy, posz+(-49), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(131), posy, posz+(79), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(35), posy, posz+(79), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(51), posy, posz+(-129), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-45), posy, posz+(47), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(99), posy, posz+(111), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(67), posy, posz+(111), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(51), posy, posz+(-97), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-141), posy, posz+(-49), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-13), posy, posz+(-129), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(67), posy, posz+(15), 1}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavaaoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavaaoutpostred)

-- CLOAKED BASES

local function scavheavyoutpostcloak(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 64
local unitoptions = {UDN.corvipe_scav.id, UDN.armferret_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-48, posy, posz+16, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+48, posy, posz-16, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavheavyoutpostcloak)
table.insert(ScavengerConstructorBlueprintsT3,scavheavyoutpostcloak)

-- BIG BASES

local function scavbigoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 176
local unitoptions = {UDN.corrad_scav.id, UDN.corarad_scav.id, UDN.corshroud_scav.id, UDN.cornanotc_scav.id, UDN.armtarg_scav.id,}
local defenseoptions = {UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	local r = math_random(0,2)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx-56, posy, posz+56, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+40, posy, posz-16, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx-100, posy, posz-140, 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-20, posy, posz-100, 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+60, posy, posz-100, 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+240, posy, posz-260, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+140, posy, posz+56, 0}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz+128, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz+96, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz+64, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+128, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz+128, 0}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz-192, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+128, posy, posz-192, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz-192, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz-160, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz-128, 0}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+240, posy, posz-260, 0}, {"shift"})
			elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(-45), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(51), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-13), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-13), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(0), posy, posz+(3), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(-104), posy, posz+(91), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(104), posy, posz+(-101), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(19), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(51), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-32), posy, posz+(-45), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(104), posy, posz+(91), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(0), posy, posz+(-45), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(32), posy, posz+(51), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(19), 0}, {"shift"})
			else
			Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(128), posy, posz+(-128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(176), posy, posz+(208), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(56), posy, posz+(56), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-48), posy, posz+(48), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-128), posy, posz+(-192), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(48), posy, posz+(-48), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-184), posy, posz+(184), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(176), posy, posz+(-144), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(-128), posy, posz+(128), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(208), posy, posz+(176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-112), posy, posz+(176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(48), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-176), posy, posz+(144), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(208), posy, posz+(16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(192), posy, posz+(128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-48), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(128), posy, posz+(128), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-16), posy, posz+(176), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-56), posy, posz+(-56), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-208), posy, posz+(-176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(176), posy, posz+(16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-144), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(128), posy, posz+(192), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(-48), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(-176), posy, posz+(-16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-176), posy, posz+(-176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(0), posy, posz+(0), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(16), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(-16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(-176), posy, posz+(16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-192), posy, posz+(-128), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-16), posy, posz+(-176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(48), posy, posz+(-16), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(144), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(144), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-176), posy, posz+(112), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-176), posy, posz+(-208), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(208), posy, posz+(-16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(16), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(112), posy, posz+(-176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(-144), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(184), posy, posz+(-184), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(176), posy, posz+(-112), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(176), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-208), posy, posz+(-16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(-16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-128), posy, posz+(-128), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-208), posy, posz+(16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(48), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(176), posy, posz+(176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(16), posy, posz+(176), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-48), posy, posz+(-16), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(240), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(16), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-240), posy, posz+(0), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(16), posy, posz+(-176), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(-176), 2}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavbigoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavbigoutpostred)

-- LONG RANGE PLASMA CANNON BASES

local function scavlrpcoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 136
	local r = math_random(0,1)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-120, posy, posz+32, 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+120, posy, posz-32, 1}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(106), posy, posz+(-80), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-46), posy, posz+(-136), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx+(-62), posy, posz+(40), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(34), posy, posz+(8), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(-102), posy, posz+(80), 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-46), posy, posz+(-8), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(-22), posy, posz+(-64), 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-6), posy, posz+(0), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(98), posy, posz+(56), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-78), posy, posz+(-120), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(50), posy, posz+(136), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-94), posy, posz+(-88), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(66), posy, posz+(-24), 2}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-94), posy, posz+(-56), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(18), posy, posz+(136), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(82), posy, posz+(120), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(98), posy, posz+(88), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(26), posy, posz+(64), 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-14), posy, posz+(-136), 1}, {"shift"})
			end
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavlrpcoutpostred)

-- COUNTER INTRUSION BASES

local function scavicsoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local defenseoptions = {UDN.corarad_scav.id, UDN.corshroud_scav.id, UDN.corhlt_scav.id, UDN.cornanotc_scav.id,}
local posradius = 144
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(0), posy, posz+(-122), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-72), posy, posz+(30), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(-32), posy, posz+(-74), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(70), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-64), posy, posz+(-122), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-16), posy, posz+(86), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(32), posy, posz+(-74), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coreyes_scav.id), {posx+(-72), posy, posz+(62), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(72), posy, posz+(30), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(70), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-128), posy, posz+(102), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(16), posy, posz+(86), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(70), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+(0), posy, posz+(134), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coreyes_scav.id), {posx+(72), posy, posz+(62), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-32), posy, posz+(-122), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+(96), posy, posz+(-58), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+(128), posy, posz+(102), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-90), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsd_scav.id), {posx+(0), posy, posz+(22), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-90), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(70), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-144), posy, posz+(38), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(144), posy, posz+(38), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-96), posy, posz+(-58), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(-122), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(32), posy, posz+(-122), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavicsoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavicsoutpostred)



-- HEAVY DEFENSIVE BASES

local function scavdoomoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
local unitoptions = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-120, posy, posz-32, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+120, posy, posz+32, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavdoomoutpostred)

-- HEAVY DEFENSIVE AIRREPAIR BASES

local function scavdaaoutpostheavy(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 170
local unitoptions = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(135), posy, posz+(74), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(87), posy, posz+(-22), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-137), posy, posz+(138), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-57), posy, posz+(-166), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(135), posy, posz+(138), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-89), posy, posz+(-54), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-89), posy, posz+(138), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(87), posy, posz+(10), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-89), posy, posz+(-166), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corasp_scav.id), {posx+(-1), posy, posz+(34), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-89), posy, posz+(106), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-89), posy, posz+(74), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-137), posy, posz+(10), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(151), posy, posz+(-70), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(119), posy, posz+(-182), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(47), posy, posz+(130), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-41), posy, posz+(-86), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(7), posy, posz+(-182), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(87), posy, posz+(-54), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-89), posy, posz+(42), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-137), posy, posz+(42), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-169), posy, posz+(58), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-137), posy, posz+(74), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-89), posy, posz+(10), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(135), posy, posz+(42), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-49), posy, posz+(130), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(71), posy, posz+(-182), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(87), posy, posz+(74), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(87), posy, posz+(106), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(23), posy, posz+(-102), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-169), posy, posz+(-70), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-89), posy, posz+(-22), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(167), posy, posz+(26), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(87), posy, posz+(42), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(167), posy, posz+(58), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(87), posy, posz+(138), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-169), posy, posz+(26), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(39), posy, posz+(-182), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-25), posy, posz+(-182), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(135), posy, posz+(10), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavdaaoutpostheavy)
table.insert(ScavengerConstructorBlueprintsT3,scavdaaoutpostheavy)

-- HEAVY POWERPLANT BASES

local function scavnrgplants(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corhlt_scav.id, UDN.corflak_scav.id, UDN.corshroud_scav.id, UDN.cortarg_scav.id, UDN.corfort_scav.id, UDN.corfort_scav.id,}
	local posradius = 160
	local r = math_random(0,4)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx-192, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+192, posy, posz, 0}, {"shift"})

				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx-96, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+96, posy, posz, 0}, {"shift"})

				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx-64, posy, posz, 0}, {"shift"})
				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+64, posy, posz, 0}, {"shift"})

				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-32, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz-64, 2}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+32, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-32, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+32, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+64, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz+80, 0}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-160, posy, posz-160, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+160, posy, posz-160, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-160, posy, posz+160, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+160, posy, posz+160, 0}, {"shift"})

				Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx, posy, posz, 1}, {"shift"})

				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx, posy, posz-40, 0}, {"shift"})
				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx, posy, posz+40, 0}, {"shift"})

				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-96, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-96, posy, posz, 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-96, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+96, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx+96, posy, posz, 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+96, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz+64, 0}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(-65), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(-65), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coreyes_scav.id), {posx+(0), posy, posz+(39), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(-33), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(0), posy, posz+(-73), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(104), posy, posz+(-145), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(-33), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corestor_scav.id), {posx+(-88), posy, posz+(95), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(-1), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-136), posy, posz+(143), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(56), posy, posz+(31), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(16), posy, posz+(39), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(136), posy, posz+(-113), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(136), posy, posz+(111), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(32), posy, posz+(39), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(143), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-136), posy, posz+(111), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(144), posy, posz+(-89), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-104), posy, posz+(-145), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(144), posy, posz+(87), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(31), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-24), posy, posz+(63), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(-32), posy, posz+(39), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(-144), posy, posz+(-89), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+(0), posy, posz+(-9), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(0), posy, posz+(-57), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-56), posy, posz+(-1), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(136), posy, posz+(143), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(-16), posy, posz+(39), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(24), posy, posz+(63), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(136), posy, posz+(-145), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corestor_scav.id), {posx+(88), posy, posz+(95), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corestor_scav.id), {posx+(-88), posy, posz+(-97), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corestor_scav.id), {posx+(88), posy, posz+(-97), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-136), posy, posz+(-145), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-136), posy, posz+(-113), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(104), posy, posz+(143), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(-144), posy, posz+(87), 0}, {"shift"})
			elseif r == 3 then
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-44), posy, posz+(63), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(148), posy, posz+(95), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-44), posy, posz+(95), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(116), posy, posz+(95), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corafus_scav.id), {posx+(20), posy, posz+(-1), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(180), posy, posz+(63), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(84), posy, posz+(-33), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(180), posy, posz+(95), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(180), posy, posz+(31), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-132), posy, posz+(23), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corestor_scav.id), {posx+(132), posy, posz+(47), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-60), posy, posz+(-129), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-92), posy, posz+(-129), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-124), posy, posz+(-65), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(84), posy, posz+(-65), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-84), posy, posz+(71), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-132), posy, posz+(71), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-44), posy, posz+(31), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(52), posy, posz+(-65), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corestor_scav.id), {posx+(-76), posy, posz+(-81), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+(-124), posy, posz+(-97), 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-124), posy, posz+(-129), 2}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+(-84), posy, posz+(23), 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-160, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+160, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+64, posy, posz+64, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavnrgplants)
table.insert(ScavengerConstructorBlueprintsT3,scavnrgplants)

-- BUILD SUPER HEAVY BOSS

-- too big to build currently

-- local function scavpwbosst1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 164
-- local unitoptions = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}
-- 	if radiusCheck then
-- 		return posradius
-- 	else
-- 		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-192, posy, posz-192, 0}, {"shift"})
-- 		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+192, posy, posz-192, 0}, {"shift"})
-- 		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-192, posy, posz+192, 0}, {"shift"})
-- 		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+192, posy, posz+192, 0}, {"shift"})
-- 		Spring.GiveOrderToUnit(scav, -(UDN.armpwt4_scav.id), {posx, posy, posz, 0}, {"shift"})
-- 	end
-- end
-- table.insert(ScavengerConstructorBlueprintsT3,scavpwbosst1)
