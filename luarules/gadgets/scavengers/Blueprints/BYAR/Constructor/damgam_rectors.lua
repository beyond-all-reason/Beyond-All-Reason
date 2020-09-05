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

local function DamIceRezzersSmall(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 64
    local r = math_random(0,1)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
            else
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
            end
    end
end
table.insert(ScavengerConstructorBlueprintsT0,DamIceRezzersSmall)
table.insert(ScavengerConstructorBlueprintsT1,DamIceRezzersSmall)
table.insert(ScavengerConstructorBlueprintsT2,DamIceRezzersSmall)
--table.insert(ScavengerConstructorBlueprintsT3,DamIceRezzersSmall)

local function DamIceRezzersBig(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 128
    local r = math_random(0,1)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
            else
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
                Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
            end
    end
end
--table.insert(ScavengerConstructorBlueprintsT0,DamIceRezzersBig)
--table.insert(ScavengerConstructorBlueprintsT1,DamIceRezzersBig)
table.insert(ScavengerConstructorBlueprintsT2,DamIceRezzersBig)
table.insert(ScavengerConstructorBlueprintsT3,DamIceRezzersBig)

-- local function DamArmRectorsSmall(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
--     local posradius = 48
-- 	if radiusCheck then
-- 		return posradius
-- 	else
--         Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
--         Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
--         Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
--         Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
-- 	end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0,DamArmRectorsSmall)
-- table.insert(ScavengerConstructorBlueprintsT1,DamArmRectorsSmall)
-- table.insert(ScavengerConstructorBlueprintsT2,DamArmRectorsSmall)
-- table.insert(ScavengerConstructorBlueprintsT3,DamArmRectorsSmall)

local function DamArmRectorsBig(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 160
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.armrectr_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT1,DamArmRectorsBig)
table.insert(ScavengerConstructorBlueprintsT2,DamArmRectorsBig)
table.insert(ScavengerConstructorBlueprintsT3,DamArmRectorsBig)

-- local function DamCorNecrosSmall(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
--     local posradius = 48
-- 	if radiusCheck then
-- 		return posradius
-- 	else
--         Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
--         Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
--         Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
--         Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
-- 	end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0,DamCorNecrosSmall)
-- table.insert(ScavengerConstructorBlueprintsT1,DamCorNecrosSmall)
-- table.insert(ScavengerConstructorBlueprintsT2,DamCorNecrosSmall)
-- table.insert(ScavengerConstructorBlueprintsT3,DamCorNecrosSmall)

local function DamCorNecrosBig(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 160
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(16), posy, posz+(-16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-16), posy, posz+(-16), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        Spring.GiveOrderToUnit(scav, -(UDN.cornecro_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT1,DamCorNecrosBig)
table.insert(ScavengerConstructorBlueprintsT2,DamCorNecrosBig)
table.insert(ScavengerConstructorBlueprintsT3,DamCorNecrosBig)



-- Sea Stuff

-- local function DamArmRecluseSmall(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    -- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0Sea,DamArmRecluseSmall)
-- table.insert(ScavengerConstructorBlueprintsT1Sea,DamArmRecluseSmall)
-- table.insert(ScavengerConstructorBlueprintsT2Sea,DamArmRecluseSmall)
-- table.insert(ScavengerConstructorBlueprintsT3Sea,DamArmRecluseSmall)

-- local function DamArmRecluseBig(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    -- local posradius = 64
    -- if radiusCheck then
        -- return posradius
    -- else
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(64), posy, posz+(64), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(-64), posy, posz+(64), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(64), posy, posz+(-64), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.armrecl_scav.id), {posx+(-64), posy, posz+(-64), math_random(0,3)}, {"shift"})
    -- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1Sea,DamArmRecluseBig)
-- table.insert(ScavengerConstructorBlueprintsT2Sea,DamArmRecluseBig)
-- table.insert(ScavengerConstructorBlueprintsT3Sea,DamArmRecluseBig)

-- local function DamCorReclusesSmall(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    -- local posradius = 32
	-- if radiusCheck then
		-- return posradius
	-- else
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0Sea,DamCorReclusesSmall)
-- table.insert(ScavengerConstructorBlueprintsT1Sea,DamCorReclusesSmall)
-- table.insert(ScavengerConstructorBlueprintsT2Sea,DamCorReclusesSmall)
-- table.insert(ScavengerConstructorBlueprintsT3Sea,DamCorReclusesSmall)

-- local function DamCorReclusesBig(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    -- local posradius = 64
    -- if radiusCheck then
        -- return posradius
    -- else
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(-32), posy, posz+(32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(-32), posy, posz+(-32), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(64), posy, posz+(64), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(-64), posy, posz+(64), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(64), posy, posz+(-64), math_random(0,3)}, {"shift"})
        -- Spring.GiveOrderToUnit(scav, -(UDN.correcl_scav.id), {posx+(-64), posy, posz+(-64), math_random(0,3)}, {"shift"})
    -- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT1Sea,DamCorReclusesBig)
-- table.insert(ScavengerConstructorBlueprintsT2Sea,DamCorReclusesBig)
-- table.insert(ScavengerConstructorBlueprintsT3Sea,DamCorReclusesBig)
