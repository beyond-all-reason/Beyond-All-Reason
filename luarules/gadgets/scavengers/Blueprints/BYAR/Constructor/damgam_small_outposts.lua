--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west
-- randompopups[math_random(1,#randompopups)]

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
--table.insert(ScavengerConstructorBlueprintsT0,CopyPasteFunction)




local function DamSmallOutpost2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 72
local r = math_random(0,3)
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(-40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(-72), 1}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(-40), 1}, {"shift"})
		elseif r == 2 then
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(80), 1}, {"shift"})
			
		else
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-80), 1}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamSmallOutpost2)


local function DamWindfarm1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
local r = math_random(0,3)
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(96), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-96), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-96), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(96), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(96), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-96), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-48), posy, posz+(-80), 1}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(80), posy, posz+(-96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(80), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(-96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(0), posy, posz+(96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(80), posy, posz+(96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-80), posy, posz+(96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-80), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armwin_scav.id), {posx+(-80), posy, posz+(-96), 1}, {"shift"})
		elseif r == 2 then
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-96), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(96), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(96), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-96), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-96), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(96), posy, posz+(-80), 1}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(80), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(-96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-80), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-80), posy, posz+(96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(80), posy, posz+(-96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(-80), posy, posz+(-96), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corwin_scav.id), {posx+(80), posy, posz+(96), 1}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,DamWindfarm1)
table.insert(ScavengerConstructorBlueprintsT1,DamWindfarm1)


local function DamMinefield1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 192
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-192,192)), posy, posz+(math_random(-192,192)), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,DamMinefield1)
table.insert(ScavengerConstructorBlueprintsT1,DamMinefield1)
table.insert(ScavengerConstructorBlueprintsT2,DamMinefield1)
table.insert(ScavengerConstructorBlueprintsT3,DamMinefield1)

local function DamMinefield2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,DamMinefield2)
table.insert(ScavengerConstructorBlueprintsT1,DamMinefield2)
table.insert(ScavengerConstructorBlueprintsT2,DamMinefield2)
table.insert(ScavengerConstructorBlueprintsT3,DamMinefield2)

local function DamMinefield3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 384
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine1_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormine3_scav.id), {posx+(math_random(-384,384)), posy, posz+(math_random(-384,384)), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,DamMinefield3)
table.insert(ScavengerConstructorBlueprintsT1,DamMinefield3)
table.insert(ScavengerConstructorBlueprintsT2,DamMinefield3)
table.insert(ScavengerConstructorBlueprintsT3,DamMinefield3)

local function DamRandomTurretfieldT1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
local randomturrets = {UDN.armllt_scav.id, UDN.armclaw_scav.id, UDN.armbeamer_scav.id, UDN.armhlt_scav.id, UDN.armguard_scav.id, UDN.armrl_scav.id, UDN.armferret_scav.id, UDN.armcir_scav.id, UDN.armnanotc_scav.id, UDN.cormaw_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.corpun_scav.id, UDN.corrl_scav.id, UDN.cormadsam_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,DamRandomTurretfieldT1)
table.insert(ScavengerConstructorBlueprintsT1,DamRandomTurretfieldT1)

local function DamRandomTurretfieldT2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id, UDN.cortron_scav.id, UDN.armemp_scav.id, UDN.corjuno_scav.id, UDN.armjuno_scav.id, UDN.armminivulc_scav.id, UDN.corminibuzz_scav.id, }
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamRandomTurretfieldT2)

local function DamRandomTurretfieldT3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id, UDN.corsilo_scav.id, UDN.armsilo_scav.id, UDN.cortron_scav.id, UDN.armemp_scav.id, UDN.corjuno_scav.id, UDN.armjuno_scav.id, UDN.corminibuzz_scav.id }
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamRandomTurretfieldT3)
table.insert(ScavengerConstructorBlueprintsT4,DamRandomTurretfieldT3)

local function DamRandomNanoTower(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 24
--local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id,}
	if radiusCheck then
		return posradius
	else
		local r = math_random(0,1)
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -UDN.cornanotc_scav.id, {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -UDN.armnanotc_scav.id, {posx+(math_random(-96,96)), posy, posz+(math_random(-96,96)), 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,DamRandomNanoTower)

local function DamIceRandomNanoTowerDuo(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 48
--local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id,}
	if radiusCheck then
		return posradius
	else
		local r = math_random(0,1)
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(24), posy, posz, 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-24), posy, posz, 0}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(24), posy, posz, 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-24), posy, posz, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT1,DamIceRandomNanoTowerDuo)
table.insert(ScavengerConstructorBlueprintsT2,DamIceRandomNanoTowerDuo)

local function DamIceRandomNanoTowerQuad(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 56
--local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id,}
	if radiusCheck then
		return posradius
	else
		local r = math_random(0,1)
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(24), posy, posz+(24), 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-24), posy, posz+(24), 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(24), posy, posz+(-24), 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-24), posy, posz+(-24), 0}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(24), posy, posz+(24), 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-24), posy, posz+(24), 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(24), posy, posz+(-24), 0}, {"shift"})
	        Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-24), posy, posz+(-24), 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamIceRandomNanoTowerQuad)
table.insert(ScavengerConstructorBlueprintsT3,DamIceRandomNanoTowerQuad)
table.insert(ScavengerConstructorBlueprintsT4,DamIceRandomNanoTowerQuad)

local function DamLandGantry1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 112
--local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id,}
	if radiusCheck then
		return posradius
	else
		local r = math_random(0,1)
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-112), posy, posz+(-32), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(112), posy, posz+(-32), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-112), posy, posz+(16), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(112), posy, posz+(16), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(40), posy, posz+(-24), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-40), posy, posz+(-24), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armshltx_scav.id), {posx+(0), posy, posz+(80), 0}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-112), posy, posz+(16), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(112), posy, posz+(16), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-112), posy, posz+(-32), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(112), posy, posz+(-32), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corgant_scav.id), {posx+(0), posy, posz+(80), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(40), posy, posz+(-24), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(-40), posy, posz+(-24), 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamLandGantry1)
table.insert(ScavengerConstructorBlueprintsT4,DamLandGantry1)

local function DamLandAircraftGantry1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 204
	if radiusCheck then
		return posradius
	else
		local r = math_random(0,1)
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armapt3_scav.id), {posx+(0), posy, posz+(20), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-116), posy, posz+(-128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-196), posy, posz+(-64), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(188), posy, posz+(-64), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(124), posy, posz+(-128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-204), posy, posz+(-8), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(4), posy, posz+(184), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armgate_scav.id), {posx+(4), posy, posz+(-136), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(196), posy, posz+(88), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(196), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-188), posy, posz+(40), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(180), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(60), posy, posz+(-144), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-52), posy, posz+(-144), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-108), posy, posz+(184), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(116), posy, posz+(184), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armflak_scav.id), {posx+(-204), posy, posz+(88), 3}, {"shift"})
			
		else
			Spring.GiveOrderToUnit(scav, -(UDN.corapt3_scav.id), {posx+(1), posy, posz+(11), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-96), posy, posz+(-140), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(192), posy, posz+(-60), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-192), posy, posz+(-60), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(96), posy, posz+(-140), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(104), posy, posz+(172), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(0), posy, posz+(180), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-200), posy, posz+(76), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-184), posy, posz+(28), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-104), posy, posz+(172), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(32), posy, posz+(-140), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(200), posy, posz+(-20), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(200), posy, posz+(76), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corgate_scav.id), {posx+(-24), posy, posz+(-148), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+(-200), posy, posz+(-20), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(184), posy, posz+(28), 1}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamLandAircraftGantry1)
table.insert(ScavengerConstructorBlueprintsT4,DamLandAircraftGantry1)

local function DamLandMiniVulcan1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 134
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armminivulc_scav.id), {posx+(-14), posy, posz+(13), 0}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(26), posy, posz+(-91), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(90), posy, posz+(-59), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(26), posy, posz+(101), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-134), posy, posz+(53), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-86), posy, posz+(-43), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(58), posy, posz+(-75), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(58), posy, posz+(85), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(122), posy, posz+(53), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(90), posy, posz+(69), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-118), posy, posz+(21), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-102), posy, posz+(-11), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-6), posy, posz+(-107), 2}, {"shift"})
		
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniVulcan1)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniVulcan1)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniVulcan1)

local function DamLandMiniVulcan2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 172
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armminivulc_scav.id), {posx+(-14), posy, posz+(20), 2}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(138), posy, posz+(-132), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(138), posy, posz+(12), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(138), posy, posz+(76), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-102), posy, posz+(156), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(10), posy, posz+(-100), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-150), posy, posz+(-52), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-70), posy, posz+(156), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-6), posy, posz+(172), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-134), posy, posz+(-84), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-38), posy, posz+(172), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(74), posy, posz+(-132), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(138), posy, posz+(44), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(122), posy, posz+(108), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-118), posy, posz+(-116), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(122), posy, posz+(-20), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-134), posy, posz+(140), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(42), posy, posz+(-116), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-166), posy, posz+(-20), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-86), posy, posz+(-132), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(106), posy, posz+(-148), 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniVulcan2)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniVulcan2)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniVulcan2)

local function DamLandMiniVulcan3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 196
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armminivulc_scav.id), {posx+(-4), posy, posz+(-11), 3}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(148), posy, posz+(157), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(100), posy, posz+(-131), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(212), posy, posz+(13), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-12), posy, posz+(-163), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(132), posy, posz+(-131), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(180), posy, posz+(93), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-172), posy, posz+(-147), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-140), posy, posz+(-147), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-172), posy, posz+(-35), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-124), posy, posz+(93), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armrad_scav.id), {posx+(180), posy, posz+(-115), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-132), posy, posz+(-107), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(180), posy, posz+(157), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(132), posy, posz+(-99), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armjamt_scav.id), {posx+(-92), posy, posz+(93), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armrad_scav.id), {posx+(-172), posy, posz+(109), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-44), posy, posz+(-147), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-156), posy, posz+(29), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-108), posy, posz+(-147), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-124), posy, posz+(125), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(180), posy, posz+(125), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(20), posy, posz+(173), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-12), posy, posz+(157), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-172), posy, posz+(-3), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(140), posy, posz+(117), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(20), posy, posz+(-179), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-172), posy, posz+(-115), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armjamt_scav.id), {posx+(100), posy, posz+(-99), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-172), posy, posz+(-83), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(196), posy, posz+(-19), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(52), posy, posz+(173), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-92), posy, posz+(125), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(116), posy, posz+(157), 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniVulcan3)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniVulcan3)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniVulcan3)

local function DamLandMiniVulcan4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 328
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-208), posy, posz+(9), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(160), posy, posz+(-39), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-160), posy, posz+(9), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-208), posy, posz+(-39), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(160), posy, posz+(9), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(208), posy, posz+(-39), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-160), posy, posz+(-39), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(208), posy, posz+(9), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armminivulc_scav.id), {posx+(-16), posy, posz+(-7), 2}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(312), posy, posz+(49), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(312), posy, posz+(17), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(8), posy, posz+(177), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-328), posy, posz+(-15), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(312), posy, posz+(81), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(48), posy, posz+(105), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-312), posy, posz+(-47), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(232), posy, posz+(-111), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(168), posy, posz+(-143), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(136), posy, posz+(145), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-152), posy, posz+(97), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armrad_scav.id), {posx+(152), posy, posz+(81), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-56), posy, posz+(-143), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(136), posy, posz+(-159), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-248), posy, posz+(81), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(296), posy, posz+(-15), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(168), posy, posz+(129), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(161), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(104), posy, posz+(145), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-216), posy, posz+(81), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-120), posy, posz+(-127), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-360), posy, posz+(1), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(200), posy, posz+(113), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(112), posy, posz+(-103), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(177), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-120), posy, posz+(113), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-272), posy, posz+(25), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armjamt_scav.id), {posx+(232), posy, posz+(65), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-88), posy, posz+(113), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(232), posy, posz+(97), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-280), posy, posz+(-111), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-24), posy, posz+(-159), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(296), posy, posz+(-47), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armjamt_scav.id), {posx+(-168), posy, posz+(49), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-296), posy, posz+(-79), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-152), posy, posz+(-127), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(104), posy, posz+(-175), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-280), posy, posz+(81), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-88), posy, posz+(-143), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(72), posy, posz+(-191), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-184), posy, posz+(-127), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-184), posy, posz+(97), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(200), posy, posz+(-127), 2}, {"shift"})
		
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniVulcan4)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniVulcan4)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniVulcan4)


local function DamLandMiniBuzzsaw1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 110
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corminibuzz_scav.id), {posx+(3), posy, posz+(-10), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(11), posy, posz+(110), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-53), posy, posz+(-98), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-53), posy, posz+(62), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-21), posy, posz+(94), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(91), posy, posz+(-18), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(91), posy, posz+(14), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-85), posy, posz+(-34), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-69), posy, posz+(-66), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(91), posy, posz+(-50), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniBuzzsaw1)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniBuzzsaw1)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniBuzzsaw1)

local function DamLandMiniBuzzsaw2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 245
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corminibuzz_scav.id), {posx+(19), posy, posz+(8), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(123), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-245), posy, posz+(-48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-5), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-181), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(187), posy, posz+(-32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-165), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(139), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(59), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-101), posy, posz+(-176), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(-85), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(203), posy, posz+(32), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-213), posy, posz+(48), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(-69), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-197), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(203), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(187), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-149), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-85), posy, posz+(144), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(139), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(219), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(107), posy, posz+(144), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(11), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-133), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(91), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-229), posy, posz+(-80), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(43), posy, posz+(176), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(27), posy, posz+(-144), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-117), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(75), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(171), posy, posz+(112), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniBuzzsaw2)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniBuzzsaw2)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniBuzzsaw2)

local function DamLandMiniBuzzsaw3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 325
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-3), posy, posz+(140), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-131), posy, posz+(12), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-3), posy, posz+(-116), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(125), posy, posz+(12), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corminibuzz_scav.id), {posx+(-3), posy, posz+(12), 1}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(277), posy, posz+(100), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(149), posy, posz+(-188), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(133), posy, posz+(260), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(117), posy, posz+(-252), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-107), posy, posz+(292), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-235), posy, posz+(-124), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(213), posy, posz+(164), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-123), posy, posz+(260), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-75), posy, posz+(-268), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(85), posy, posz+(116), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-331), posy, posz+(52), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-155), posy, posz+(228), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-139), posy, posz+(-188), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(309), posy, posz+(-76), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-219), posy, posz+(180), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(245), posy, posz+(-108), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-283), posy, posz+(116), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(149), posy, posz+(196), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-107), posy, posz+(-252), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(325), posy, posz+(36), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(245), posy, posz+(132), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(213), posy, posz+(-172), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(-75), posy, posz+(100), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-251), posy, posz+(148), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-283), posy, posz+(84), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(277), posy, posz+(68), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(85), posy, posz+(-76), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(149), posy, posz+(228), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-187), posy, posz+(196), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(-91), posy, posz+(-60), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-299), posy, posz+(-92), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-315), posy, posz+(84), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(149), posy, posz+(-220), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-171), posy, posz+(-188), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(85), posy, posz+(-268), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(277), posy, posz+(-108), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-203), posy, posz+(-124), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-139), posy, posz+(-220), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-203), posy, posz+(-156), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(245), posy, posz+(-140), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(309), posy, posz+(68), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(181), posy, posz+(196), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(181), posy, posz+(-188), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-267), posy, posz+(-92), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-123), posy, posz+(228), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniBuzzsaw3)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniBuzzsaw3)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniBuzzsaw3)

local function DamLandMiniBuzzsaw4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 333
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-75), posy, posz+(131), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-123), posy, posz+(83), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-75), posy, posz+(83), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(85), posy, posz+(-61), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(133), posy, posz+(-61), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-123), posy, posz+(131), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(133), posy, posz+(-109), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(85), posy, posz+(-109), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corminibuzz_scav.id), {posx+(5), posy, posz+(3), 1}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(93), posy, posz+(-325), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-163), posy, posz+(-53), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(189), posy, posz+(-69), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-83), posy, posz+(299), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(61), posy, posz+(139), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-99), posy, posz+(-117), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(221), posy, posz+(-21), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-19), posy, posz+(-213), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-123), posy, posz+(211), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(189), posy, posz+(11), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(269), posy, posz+(-85), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(133), posy, posz+(-189), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-179), posy, posz+(-21), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-67), posy, posz+(-149), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-243), posy, posz+(43), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-19), posy, posz+(235), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-259), posy, posz+(75), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(237), posy, posz+(-53), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(157), posy, posz+(43), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-211), posy, posz+(11), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-323), posy, posz+(123), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(13), posy, posz+(-245), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(29), posy, posz+(-277), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(85), posy, posz+(-189), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-115), posy, posz+(315), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(93), posy, posz+(107), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(29), posy, posz+(171), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-51), posy, posz+(267), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(-179), posy, posz+(139), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+(-179), posy, posz+(91), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx+(189), posy, posz+(-117), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-131), posy, posz+(-85), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-75), posy, posz+(211), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(61), posy, posz+(-309), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(13), posy, posz+(203), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-291), posy, posz+(107), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-51), posy, posz+(-181), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(125), posy, posz+(75), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(301), posy, posz+(-117), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(333), posy, posz+(-133), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamLandMiniBuzzsaw4)
table.insert(ScavengerConstructorBlueprintsT3,DamLandMiniBuzzsaw4)
table.insert(ScavengerConstructorBlueprintsT4,DamLandMiniBuzzsaw4)