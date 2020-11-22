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
local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id, UDN.cortron_scav.id, UDN.armemp_scav.id, UDN.corjuno_scav.id, UDN.armjuno_scav.id, }
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
table.insert(ScavengerConstructorBlueprintsT3,DamRandomTurretfieldT3)

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

-- local function DamJunoTower1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 48
-- --local randomturrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id,}
	-- if radiusCheck then
		-- return posradius
	-- else
		-- local r = math_random(0,1)
		-- if r == 0 then
			-- Spring.GiveOrderToUnit(scav, -(UDN.corjuno_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(-16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-48), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(16), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-16), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(48), posy, posz+(16), 0}, {"shift"})
		-- else
			-- Spring.GiveOrderToUnit(scav, -(UDN.armjuno_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(-16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(-16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(16), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-16), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-16), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(48), posy, posz+(16), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-48), posy, posz+(-48), 0}, {"shift"})
			-- Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(16), posy, posz+(48), 0}, {"shift"})
		-- end
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1,DamJunoTower1)
-- table.insert(ScavengerConstructorBlueprintsT2,DamJunoTower1)
-- table.insert(ScavengerConstructorBlueprintsT3,DamJunoTower1)

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