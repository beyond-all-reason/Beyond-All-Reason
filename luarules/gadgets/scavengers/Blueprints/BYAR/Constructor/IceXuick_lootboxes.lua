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
    local posradius = 48
	local r = 0 --math_random(0,4)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.lootboxbronze_scav.id), {posx, posy, posz, 0}, {"shift"})
        end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,IceXuickLootboxT1)
table.insert(ScavengerConstructorBlueprintsT0Sea,IceXuickLootboxT1)


local function IceXuickLootboxT2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 48
    local r = 0 --math_random(0,5)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.lootboxsilver_scav.id), {posx, posy, posz, 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT1,IceXuickLootboxT2)
table.insert(ScavengerConstructorBlueprintsT1Sea,IceXuickLootboxT2)

local function IceXuickLootboxT3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 48
    local r = 0 --math_random(0,6)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.lootboxgold_scav.id), {posx, posy, posz, 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT2,IceXuickLootboxT3)
table.insert(ScavengerConstructorBlueprintsT2Sea,IceXuickLootboxT3)

local function IceXuickLootboxT4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 48
	local r = 0 --math_random(0,10)
        if radiusCheck then
            return posradius
        else
            if r == 0 then
                Spring.GiveOrderToUnit(scav, -(UDN.lootboxplatinum_scav.id), {posx, posy, posz, 0}, {"shift"})
        end
    end
end
table.insert(ScavengerConstructorBlueprintsT3,IceXuickLootboxT4)
table.insert(ScavengerConstructorBlueprintsT3Sea,IceXuickLootboxT4)


-- Specialist Nanos

local function IceXuickSpecNanoT1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 64
	local r = 0 --math_random(0,1)
	local options = {UDN.lootboxnano_t1_var1_scav.id,UDN.lootboxnano_t1_var2_scav.id,UDN.lootboxnano_t1_var3_scav.id,UDN.lootboxnano_t1_var4_scav.id}
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(options[math.random(1,4)]), {posx, posy, posz, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT1,IceXuickSpecNanoT1)
table.insert(ScavengerConstructorBlueprintsT1Sea,IceXuickSpecNanoT1)

local function IceXuickSpecNanoT2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 80
	local r = 0 --math_random(0,2)
	local options = {UDN.lootboxnano_t2_var1_scav.id,UDN.lootboxnano_t2_var2_scav.id,UDN.lootboxnano_t2_var3_scav.id,UDN.lootboxnano_t2_var4_scav.id}
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(options[math.random(1,4)]), {posx, posy, posz, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,IceXuickSpecNanoT2)
table.insert(ScavengerConstructorBlueprintsT2Sea,IceXuickSpecNanoT2)

local function IceXuickSpecNanoT3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 112
	local r = 0 --math_random(0,2)
	local options = {UDN.lootboxnano_t3_var1_scav.id,UDN.lootboxnano_t3_var2_scav.id,UDN.lootboxnano_t3_var3_scav.id,UDN.lootboxnano_t3_var4_scav.id}
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(options[math.random(1,4)]), {posx, posy, posz, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT3,IceXuickSpecNanoT3)
table.insert(ScavengerConstructorBlueprintsT3Sea,IceXuickSpecNanoT3)

local function IceXuickSpecNanoT4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
    local posradius = 128
	local r = 0 --math_random(0,2)
	local options = {UDN.lootboxnano_t4_var1_scav.id,UDN.lootboxnano_t4_var2_scav.id,UDN.lootboxnano_t4_var3_scav.id,UDN.lootboxnano_t4_var4_scav.id}
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(options[math.random(1,4)]), {posx, posy, posz, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT3,IceXuickSpecNanoT4)
table.insert(ScavengerConstructorBlueprintsT3Sea,IceXuickSpecNanoT4)

