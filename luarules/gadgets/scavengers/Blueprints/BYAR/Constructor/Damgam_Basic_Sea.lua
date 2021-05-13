local UDN = UnitDefNames
local nameSuffix = '_scav'

local function DamBasicSeaT1_1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corfmkr_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfmkr_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfmkr_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfmkr_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armfmkr_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfmkr_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfmkr_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfmkr_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_1)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_1)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_1)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_1)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_1)

local function DamBasicSeaT1_2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coruwms_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwms_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwms_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwms_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armuwms_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwms_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwms_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwms_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_2)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_2)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_2)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_2)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_2)

local function DamBasicSeaT1_3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.cortide_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cortide_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cortide_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cortide_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armtide_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armtide_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armtide_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armtide_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_3)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_3)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_3)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_3)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_3)

local function DamBasicSeaT1_4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coruwes_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwes_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwes_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwes_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armuwes_scav.id), {posx+(32), posy, posz+(-32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwes_scav.id), {posx+(-32), posy, posz+(32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwes_scav.id), {posx+(32), posy, posz+(32), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwes_scav.id), {posx+(-32), posy, posz+(-32), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_4)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_4)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_4)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_4)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_4)

local function DamBasicSeaT1_5(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_5)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_5)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_5)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_5)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_5)

local function DamBasicSeaT1_6(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corfrt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfdrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armfrt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(16), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(48), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(48), posy, posz+(-16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(48), posy, posz+(16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(-48), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(-48), posy, posz+(16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(-48), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(16), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(48), posy, posz+(48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(-48), posy, posz+(-16), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(-16), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfdrag_scav.id), {posx+(-16), posy, posz+(48), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_6)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_6)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_6)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_6)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_6)

local function DamBasicSeaT1_7(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.cortl_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfrad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cortl_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armfrad_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armtl_scav.id), {posx+(-48), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armtl_scav.id), {posx+(48), posy, posz+(0), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_7)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_7)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_7)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_7)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_7)

local function DamBasicSeaT1_8(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.cortl_scav.id), {posx+(0), posy, posz+(-48), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corfhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cortl_scav.id), {posx+(0), posy, posz+(48), 1}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armtl_scav.id), {posx+(8), posy, posz+(56), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armtl_scav.id), {posx+(-8), posy, posz+(-56), 1}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,DamBasicSeaT1_8)
table.insert(ScavengerConstructorBlueprintsT1Sea,DamBasicSeaT1_8)
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT1_8)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT1_8)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT1_8)









------------------------------------------------------------------------ Tech 2

local function DamBasicSeaT2_1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coruwmmm_scav.id), {posx+(40), posy, posz+(40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwmmm_scav.id), {posx+(40), posy, posz+(-40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwmmm_scav.id), {posx+(-40), posy, posz+(40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwmmm_scav.id), {posx+(-40), posy, posz+(-40), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armuwmmm_scav.id), {posx+(-40), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwmmm_scav.id), {posx+(-40), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwmmm_scav.id), {posx+(40), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwmmm_scav.id), {posx+(40), posy, posz+(32), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT2_1)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT2_1)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT2_1)

local function DamBasicSeaT2_2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(32), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(-32), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(32), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+(-32), posy, posz+(32), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadvms_scav.id), {posx+(32), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadvms_scav.id), {posx+(32), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadvms_scav.id), {posx+(-32), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadvms_scav.id), {posx+(-32), posy, posz+(-32), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT2_2)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT2_2)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT2_2)

local function DamBasicSeaT2_3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coruwfus_scav.id), {posx+(-40), posy, posz+(-40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwfus_scav.id), {posx+(-40), posy, posz+(40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwfus_scav.id), {posx+(40), posy, posz+(40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwfus_scav.id), {posx+(40), posy, posz+(-40), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx+(48), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx+(-48), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx+(48), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx+(-48), posy, posz+(-32), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT2_3)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT2_3)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT2_3)

local function DamBasicSeaT2_4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(-40), posy, posz+(-40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(40), posy, posz+(-40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(40), posy, posz+(40), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coruwadves_scav.id), {posx+(-40), posy, posz+(40), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(-32), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(32), posy, posz+(32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(32), posy, posz+(-32), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armuwadves_scav.id), {posx+(-32), posy, posz+(-32), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT2_4)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT2_4)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT2_4)

local function DamBasicSeaT2_5(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 100
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corfdoom_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corenaa_scav.id), {posx+(0), posy, posz+(80), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coratl_scav.id), {posx+(-72), posy, posz+(8), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.corenaa_scav.id), {posx+(0), posy, posz+(-80), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.coratl_scav.id), {posx+(72), posy, posz+(-8), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.corfdoom_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armatl_scav.id), {posx+(-80), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfflak_scav.id), {posx+(-8), posy, posz+(-72), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armatl_scav.id), {posx+(80), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armfflak_scav.id), {posx+(8), posy, posz+(72), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaT2_5)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaT2_5)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaT2_5)




local function DamBasicSeaFactoryT2_1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 104
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corsy_scav.id), {posx+(0), posy, posz+(6), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-104), posy, posz+(-2), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(104), posy, posz+(-2), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armsy_scav.id), {posx+(0), posy, posz+(6), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(104), posy, posz+(-2), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-104), posy, posz+(-2), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaFactoryT2_1)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaFactoryT2_1)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaFactoryT2_1)

local function DamBasicSeaFactoryT2_2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 104
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corfhp_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(104), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-104), posy, posz+(0), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armfhp_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(104), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-104), posy, posz+(0), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaFactoryT2_2)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaFactoryT2_2)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaFactoryT2_2)

local function DamBasicSeaFactoryT2_3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 104
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.coramsub_scav.id), {posx+(0), posy, posz+(-5), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(104), posy, posz+(3), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-104), posy, posz+(3), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armamsub_scav.id), {posx+(6), posy, posz+(-16), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(94), posy, posz+(8), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-98), posy, posz+(8), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaFactoryT2_3)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaFactoryT2_3)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaFactoryT2_3)

local function DamBasicSeaFactoryT2_4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 96
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corplat_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(96), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-96), posy, posz+(0), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armplat_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-96), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(96), posy, posz+(0), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaFactoryT2_4)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaFactoryT2_4)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaFactoryT2_4)

local function DamBasicSeaFactoryT2_5(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 136
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corasy_scav.id), {posx+(0), posy, posz+(-5), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-136), posy, posz+(3), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(136), posy, posz+(3), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armasy_scav.id), {posx+(0), posy, posz+(-5), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(136), posy, posz+(3), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-136), posy, posz+(3), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,DamBasicSeaFactoryT2_5)
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaFactoryT2_5)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaFactoryT2_5)











------------------------------------------------------------------------ Tech 3


local function DamBasicSeaFactoryT3_1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 112
	if radiusCheck then
		return posradius
	else
        local r = math.random(0,1)
        if r == 0 then
            Spring.GiveOrderToUnit(scav, -(UDN.corgantuw_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-112), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(112), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(112), posy, posz+(-48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-112), posy, posz+(-48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(112), posy, posz+(48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx+(-112), posy, posz+(48), 0}, {"shift"})
        else
            Spring.GiveOrderToUnit(scav, -(UDN.armshltxuw_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-112), posy, posz+(-48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(112), posy, posz+(48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-112), posy, posz+(48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(112), posy, posz+(-48), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(-112), posy, posz+(0), 0}, {"shift"})
            Spring.GiveOrderToUnit(scav, -(UDN.armnanotcplat_scav.id), {posx+(112), posy, posz+(0), 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT3Sea,DamBasicSeaFactoryT3_1)
table.insert(ScavengerConstructorBlueprintsT4Sea,DamBasicSeaFactoryT3_1)