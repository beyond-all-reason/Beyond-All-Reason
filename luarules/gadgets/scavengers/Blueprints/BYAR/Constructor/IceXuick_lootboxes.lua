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

local function IceXuickLootboxT1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 32
	if radiusCheck then
		return posradius
	else
        Spring.GiveOrderToUnit(scav, -(UDN.lootboxbronze.id), {posx, posy, posz, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,IceXuickLootboxT1)
table.insert(ScavengerConstructorBlueprintsT2,IceXuickLootboxT1)

local function IceXuickLootboxT2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 32
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.lootboxsilver.id), {posx, posy, posz, 0}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT2,IceXuickLootboxT2)
table.insert(ScavengerConstructorBlueprintsT3,IceXuickLootboxT2)

local function IceXuickLootboxT3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 48
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.lootboxgold.id), {posx, posy, posz, 0}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,IceXuickLootboxT3)

local function IceXuickLootboxT4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 64
    if radiusCheck then
        return posradius
    else
        Spring.GiveOrderToUnit(scav, -(UDN.lootboxplatinum.id), {posx, posy, posz, 0}, {"shift"})
    end
end
table.insert(ScavengerConstructorBlueprintsT3,IceXuickLootboxT4)

