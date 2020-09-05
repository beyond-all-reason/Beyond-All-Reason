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

local function IceXuickSmallRaiders(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 32
	if radiusCheck then
		return posradius
	else
        Spring.GiveOrderToUnit(scav, -(UDN.corak_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corak_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corak_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corak_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,IceXuickSmallRaiders)
table.insert(ScavengerConstructorBlueprintsT1,IceXuickSmallRaiders)

local function IceXuickBigRaiders(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 64
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.corroach_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corroach_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corroach_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.corroach_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armfast_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armfast_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armfast_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armfast_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT2,IceXuickBigRaiders)
table.insert(ScavengerConstructorBlueprintsT3,IceXuickBigRaiders)

local function IceXuickSingleRaiderT1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 32
    local r = math_random(0,4)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.corstorm_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 1 then
                Spring.GiveOrderToUnit(scav, -(UDN.corthud_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 2 then
                Spring.GiveOrderToUnit(scav, -(UDN.armwar_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 3 then
                Spring.GiveOrderToUnit(scav, -(UDN.armfast_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            else
                Spring.GiveOrderToUnit(scav, -(UDN.corspy_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            end
    end
end
table.insert(ScavengerConstructorBlueprintsT0,IceXuickSingleRaiderT1)

local function IceXuickSingleRaiderT2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 40
    local r = math_random(0,4)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.corcan_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 1 then
                Spring.GiveOrderToUnit(scav, -(UDN.cortermite_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 2 then
                Spring.GiveOrderToUnit(scav, -(UDN.coramph_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 3 then
                Spring.GiveOrderToUnit(scav, -(UDN.armzeus_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            else
                Spring.GiveOrderToUnit(scav, -(UDN.armsnipe_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            end
    end
end
table.insert(ScavengerConstructorBlueprintsT1,IceXuickSingleRaiderT2)

local function IceXuickSingleRaiderT3red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 40
    local r = math_random(0,4)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.corsumo_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 1 then
                Spring.GiveOrderToUnit(scav, -(UDN.corban_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 2 then
                Spring.GiveOrderToUnit(scav, -(UDN.corparrow_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 3 then
                Spring.GiveOrderToUnit(scav, -(UDN.cormando_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            else
                Spring.GiveOrderToUnit(scav, -(UDN.corhal_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            end
    end
end
table.insert(ScavengerConstructorBlueprintsT2,IceXuickSingleRaiderT3red)
table.insert(ScavengerConstructorBlueprintsT3,IceXuickSingleRaiderT3red)

local function IceXuickSingleRaiderT3blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 40
    local r = math_random(0,4)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.armmanni_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 1 then
                Spring.GiveOrderToUnit(scav, -(UDN.armmar_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 2 then
                Spring.GiveOrderToUnit(scav, -(UDN.armsptk_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            elseif r == 3 then
                Spring.GiveOrderToUnit(scav, -(UDN.armblade_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            else
                Spring.GiveOrderToUnit(scav, -(UDN.armflea_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
            end
    end
end
table.insert(ScavengerConstructorBlueprintsT2,IceXuickSingleRaiderT3blue)
table.insert(ScavengerConstructorBlueprintsT3,IceXuickSingleRaiderT3blue)


