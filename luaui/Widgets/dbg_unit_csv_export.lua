local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Unit CSV Export",
    desc      = "export units (for the purpose of the website database)",
    author    = "Floris",
    date      = "May 2018",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false
  }
end


local filename = "unitlist.csv"
local iconTypes = VFS.Include("gamedata/icontypes.lua")


local function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    if num >= 0 then return math.floor(num * mult + 0.5) / mult
    else return math.ceil(num * mult - 0.5) / mult end
end

local function buildTree(conDefID, tree)
    local buildOptions = UnitDefs[conDefID].buildOptions
    for _, option in ipairs(buildOptions) do
        if not tree[option] then
            tree[option] = true
            if UnitDefs[option].buildOptions then
                tree = buildTree(option, tree)
            end
        end
    end

    return tree
end

function widget:Initialize()
    local file = assert(io.open(filename,'w'), "Unable to save file")

    local columnSeparator = ';'
    local columnSubSeparator = ', '
    -- see https://springrts.com/wiki/Lua_UnitDefs for what is availible
    file:write(
        'id'..columnSeparator..
        'faction'..columnSeparator..
        'techlevel'..columnSeparator..
        'name'..columnSeparator..
        'tooltip'..columnSeparator..
        'description'..columnSeparator..
        'radaricon'..columnSeparator..
        'height'..columnSeparator..
        'metalcost'..columnSeparator..
		'energycost'..columnSeparator..
		'buildtime'..columnSeparator..
        'metalmake'..columnSeparator..
        'energymake'..columnSeparator..
        'buildpower'..columnSeparator..
        'speed'..columnSeparator..
        'health'..columnSeparator..
        'amphib'..columnSeparator..
        'sub'..columnSeparator..
        'air'..columnSeparator..
        'hover'..columnSeparator..
        'ship'..columnSeparator..
        'tank'..columnSeparator..
        'bot'..columnSeparator..
        'building'..columnSeparator..
        'dps'..columnSeparator..
        'weaponrange'..columnSeparator..
        'jammerrange'..columnSeparator..
        'sonarrange'..columnSeparator..
        'radarrange'..columnSeparator..
        'sightrange'..columnSeparator..
        'airsightrange'..columnSeparator..
        'specials'..columnSeparator..
        'weapons'..columnSeparator..
        'buildoptions'..columnSeparator..
        'buildable'..columnSeparator..
		'file'..columnSeparator..
        '\n'
    )

    local allBuildableDefs = {}
    for udid, unitDef in pairs(UnitDefs) do
        local faction = ''
        if string.sub(unitDef.name, 1, 3) == 'arm' then
            faction = 'ARMADA'
        end
        if string.sub(unitDef.name, 1, 3) == 'cor' then
            faction = 'CORTEX'
        end
        if unitDef.buildOptions then
            --if faction == 'ARMADA' or faction == 'CORTEX' then
                for id, optionDefID in pairs(unitDef.buildOptions) do
                    allBuildableDefs[optionDefID] = true
                end
           -- end
        end
    end

    local inBuildoptions = buildTree(UnitDefNames["armcom"].id, {})
    inBuildoptions = buildTree(UnitDefNames["corcom"].id, inBuildoptions)

    for udid, unitDef in pairs(UnitDefs) do
        if inBuildoptions[udid] or unitDef.name == 'armcom' or unitDef.name == 'corcom' or unitDef.name == 'legcom' then
            local faction = ''
            if string.sub(unitDef.name, 1, 3) == 'arm' then
                faction = 'ARMADA'
            end
            if string.sub(unitDef.name, 1, 3) == 'cor' then
                faction = 'CORTEX'
            end
            --if string.sub(unitDef.name, 1, 3) == 'leg' then
            --    faction = 'LEGION'
            --end
            if unitDef.modCategories["raptor"] then
                faction = 'CHICKS'
            end
            if string.find(unitDef.name, "_scav") then
                faction = 'SCAVS'
            end
            if string.sub(unitDef.name, 1, 7) == 'critter' then
                --faction = 'CRITTER'
            end
            if faction ~= '' and faction ~= 'SCAVS' then
                local description = ''
                if unitDef.customParams.description_long then
                    description = unitDef.customParams.description_long
                end

                local techlevel = '1'
                if unitDef.customParams.techlevel then
                    techlevel = unitDef.customParams.techlevel
                end

                local specials = ''
                if unitDef.canCloak then
                    specials = specials .. 'cloak, '
                end
                if unitDef.stealth then
                    specials = specials .. 'stealth, '
                end
                if unitDef.sonarStealth then
                    specials = specials .. 'sonar-stealth, '
                end
                if unitDef.radarDistance >= 1000 then
                    specials = specials .. 'radar, '
                end
                if unitDef.radarDistanceJam > 0  then
                    specials = specials .. 'jammer, '
                end
                if unitDef.hasShield then
                    specials = specials .. 'shield, '
                end
                if unitDef.canResurrect then
                    specials = specials .. 'resurrector, '
                end
                if unitDef.canCapture then
                    specials = specials .. 'capturer, '
                end
                if unitDef.rSpeed > 0 then
                    specials = specials .. 'reversible, '
                end
                if unitDef.transportSize > 0 then
                    specials = specials .. 'transport, '
                end
                if unitDef.customParams.isairbase then
                    specials = specials .. 'airbase, '
                end
                if unitDef.seismicDistance > 0 then
                    specials = specials .. 'stealth-detector, '
                end
                if specials ~= '' then
                    specials = string.sub(specials, 1, #specials-2)
                end

                local jammerRange = ''
                if unitDef.radarDistanceJam > 0 then
                    jammerRange = round(unitDef.radarDistanceJam, 0)
                end
                local radarRange = ''
                if unitDef.radarDistance > 0 then
                    radarRange = round(unitDef.radarDistance, 0)
                end
                local sonarRange = ''
                if unitDef.sonarDistance > 0 then
                    sonarRange = round(unitDef.sonarDistance, 0)
                end
                local sightRange = ''
                if unitDef.sightDistance > 0 then
                    sightRange = round(unitDef.sightDistance, 0)
                end
                local airsightRange = ''
                if unitDef.airSightDistance > 0 then
                    airsightRange = round(unitDef.airSightDistance, 0)
                end

                local dps = 0
                local weaponTable = {}
                local weapons = ''
                local weaponRange = ''
                if unitDef.weapons then
                    for wid, weapon in pairs(unitDef.weapons) do
                        if not string.find(WeaponDefs[weapon.weaponDef].name, 'bogus') and not string.find(WeaponDefs[weapon.weaponDef].name, 'mine') then
                            local weapName = WeaponDefs[weapon.weaponDef].type
                            if weaponRange == '' or weaponRange < WeaponDefs[weapon.weaponDef].range then
                                weaponRange = WeaponDefs[weapon.weaponDef].range
                            end
                            if WeaponDefs[weapon.weaponDef].paralyzer then
                                if weapName == 'BeamLaser' then
                                    weapName = 'EMP-BeamLaser'
                                elseif weapName == 'AircraftBomb' then
                                    weapName = 'EMP-AircraftBomb'
                                elseif weapName == 'StarburstLauncher' then
                                    weapName = 'EMP-StarburstLauncher'
                                end
                            else
								if WeaponDefs[weapon.weaponDef].damages[Game.armorTypes["vtol"]] > WeaponDefs[weapon.weaponDef].damages[Game.armorTypes["default"] or 0] then
									dps = dps + (((WeaponDefs[weapon.weaponDef].damages[Game.armorTypes["vtol"]]*(1/WeaponDefs[weapon.weaponDef].reload)) * WeaponDefs[weapon.weaponDef].salvoSize) * WeaponDefs[weapon.weaponDef].projectiles)
                                else
                                    dps = dps + (((WeaponDefs[weapon.weaponDef].damages[Game.armorTypes["default"] or 0]*(1/WeaponDefs[weapon.weaponDef].reload)) * WeaponDefs[weapon.weaponDef].salvoSize) * WeaponDefs[weapon.weaponDef].projectiles)
                                end
                            end
                            if weaponTable[weapName] then
                                weaponTable[weapName] = weaponTable[weapName] + 1
                            else
                                weaponTable[weapName] = 1
                            end
                        end
                    end
                    for wname, wnum in pairs(weaponTable) do
                        local separator = columnSubSeparator
                        if weapons == '' then
                            separator = ''
                        end
                        if wnum > 1 then
                            weapons = weapons .. separator .. wnum..'x '..wname
                        else
                            weapons = weapons .. separator .. wname
                        end
                    end
                end

                if unitDef.seismicDistance > 0 then
                    weaponRange = unitDef.seismicDistance
                end

                if unitDef.customParams.unitgroup and unitDef.customParams.unitgroup == 'explo' and unitDef.deathExplosion and WeaponDefNames[unitDef.deathExplosion] then
                    local weapon = WeaponDefs[WeaponDefNames[unitDef.deathExplosion].id]
                    if weapon then
                        dps = weapon.damages[Game.armorTypes["default"]]
                    end
                end

                if dps > 0 then
                    dps = round(dps, 0)
                else
                    dps = 0
                end

                if weaponRange ~= '' then
                    weaponRange = round(weaponRange, 0)
                else
                    weaponRange = 0
                end

                local metalMake = ''
                if unitDef.metalMake > 0 then
                    metalMake = round(unitDef.metalMake, 0)
                end
                if unitDef.metalMake < 10 then
                    metalMake = tostring(unitDef.metalMake):sub(1,3)
                    if metalMake:sub(3) == '0' then
                        metalMake = metalMake:sub(1,1)
                    end
                end
                local energyMake = ''
                if unitDef.energyMake > 0 then
                    energyMake = round(unitDef.energyMake, 0)
                end
                if unitDef.energyMake < 10 then
                    energyMake = tostring(unitDef.energyMake):sub(1,3)
                    if energyMake:sub(3) == '0' then
                        energyMake = energyMake:sub(1,1)
                    end
                end

                local buildoptions = ''
                if unitDef.buildOptions then
                    for id, optionDefID in pairs(unitDef.buildOptions) do
                        local separator = columnSubSeparator
                        if buildoptions == '' then
                            separator = ''
                        end
                        buildoptions = buildoptions..separator..UnitDefs[optionDefID].name
                    end
                end

                file:write(
                    unitDef.name..columnSeparator..
                    faction..columnSeparator..
                    techlevel..columnSeparator..
                    unitDef.translatedHumanName..columnSeparator..
                    unitDef.translatedTooltip..columnSeparator..
                    description..columnSeparator..
                    (iconTypes[unitDef.iconType] and iconTypes[unitDef.iconType].bitmap and string.gsub(string.gsub(iconTypes[unitDef.iconType].bitmap, 'icons/', ''), '.png', '') or '')..columnSeparator..
                    round(unitDef.height, 0)..columnSeparator..
                    unitDef.metalCost..columnSeparator..
					unitDef.energyCost..columnSeparator..
					unitDef.buildTime..columnSeparator..
                    metalMake..columnSeparator..
                    energyMake..columnSeparator..
                    unitDef.buildSpeed..columnSeparator..
                    round(unitDef.speed, 0)..columnSeparator..
                    unitDef.health..columnSeparator..
                    ((unitDef.modCategories["phib"] ~= nil or (unitDef.modCategories["canbeuw"] ~= nil and unitDef.modCategories["underwater"] == nil)) and '1' or '')..columnSeparator..
                    ((unitDef.modCategories["underwater"] ~= nil) and '1' or '')..columnSeparator..
                    (unitDef.canFly and '1' or '')..columnSeparator..
                    (unitDef.modCategories["hover"] and '1' or '')..columnSeparator..
                    (unitDef.modCategories["ship"] and '1' or '')..columnSeparator..
                    (unitDef.modCategories["tank"] and '1' or '')..columnSeparator..
                    (unitDef.modCategories["bot"] and '1' or '')..columnSeparator..
                    ((unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0) and '1' or '')..columnSeparator..
                    dps..columnSeparator..
                    weaponRange..columnSeparator..
                    jammerRange..columnSeparator..
                    sonarRange..columnSeparator..
                    radarRange..columnSeparator..
                    sightRange..columnSeparator..
                    airsightRange..columnSeparator..
                    specials..columnSeparator..
                    weapons..columnSeparator..
                    buildoptions..columnSeparator..
                    (allBuildableDefs[udid] and '1' or '0')..columnSeparator..
					(unitDef.customParams.subfolder and unitDef.customParams.subfolder..'/' or "") .. unitDef.name..'.lua'..
                    '\n'
                )
            end
        end
    end

    Spring.Echo("Exported units to file: "..filename)
    file:close()
end
