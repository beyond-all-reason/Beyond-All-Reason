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

-- local function DamSmallOutpost1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 144
-- local r = math_random(0,1)
	-- if radiusCheck then
		-- return posradius
	-- else
		-- if r == 0 then
			-- Spring.GiveOrderToUnit(scav, -(UDN.armrl_scav.id), {posx+(-128), posy, posz+(0), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armrl_scav.id), {posx+(0), posy, posz+(-128), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armrl_scav.id), {posx+(0), posy, posz+(128), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-144), posy, posz+(144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armrl_scav.id), {posx+(128), posy, posz+(0), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(144), posy, posz+(144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-144), posy, posz+(-144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(144), posy, posz+(-144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armsolar_scav.id), {posx+(0), posy, posz+(0), 2}, {"shift"})
		-- else
			-- Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(-128), posy, posz+(0), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(144), posy, posz+(144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(128), posy, posz+(0), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(0), posy, posz+(128), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-144), posy, posz+(144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corrl_scav.id), {posx+(0), posy, posz+(-128), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-144), posy, posz+(-144), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corsolar_scav.id), {posx+(0), posy, posz+(0), 2}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(144), posy, posz+(-144), 2}, {"shift"})
		-- end
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0,DamSmallOutpost1)
-- table.insert(ScavengerConstructorBlueprintsT1,DamSmallOutpost1)




local function DamSmallOutpost2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 72
local r = math_random(0,3)
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(-40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(-72), 1}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(8), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(40), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-40), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-72), posy, posz+(40), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(-8), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-8), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armclaw_scav.id), {posx+(-72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(72), posy, posz+(-40), 1}, {"shift"})
		elseif r == 2 then
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-80), posy, posz+(80), 1}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-16), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(-80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-80), posy, posz+(48), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormaw_scav.id), {posx+(80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(80), posy, posz+(-80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
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
local randomturrets = {UDN.armllt_scav.id, UDN.armclaw_scav.id, UDN.armbeamer_scav.id, UDN.armhlt_scav.id, UDN.armguard_scav.id, UDN.armrl_scav.id, UDN.armpacko_scav.id, UDN.armcir_scav.id, UDN.armnanotc_scav.id, UDN.cormaw_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.corpun_scav.id, UDN.corrl_scav.id, UDN.cormadsam_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
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
local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id, UDN.corsilo_scav.id, UDN.armsilo_scav.id, UDN.cortron_scav.id, UDN.armemp_scav.id, UDN.corjuno_scav.id, UDN.armjuno_scav.id, }
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
table.insert(ScavengerConstructorBlueprintsT3,DamRandomTurretfieldT2)

local function DamRandomNanoTower(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 16
local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id,}
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
table.insert(ScavengerConstructorBlueprintsT1,DamRandomNanoTower)
table.insert(ScavengerConstructorBlueprintsT2,DamRandomNanoTower)
table.insert(ScavengerConstructorBlueprintsT3,DamRandomNanoTower)
