function gadget:GetInfo()
    return {
        name      = "Critter Spawner",
        desc      = "Spawns critters when trees are reclaimed, at semi random",
        author    = "Hornet",
        date      = "2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if Spring.GetModOptions().april1extra ~= true then
	return false
end


local initialUnits = {}
local crittersPresent = {}
local critterNames = {}
local gaiaID = Spring.GetGaiaTeamID()
local gaiaAllyID = select(6, Spring.GetTeamInfo(gaiaID))
local currentCritter = UnitDefNames['critter_penguin'].id

if not gadgetHandler:IsSyncedCode() then
    return
end

for unitDefID, defs in pairs(UnitDefs) do
	if string.find(defs.name, "critter_") then
		critterNames[unitDefID] = defs.name
	end
end


-- 437 = critter_ant
-- 438 = critter_crab
--  439 = critter_duck
--    440 = critter_goldfish
--  441 = critter_gull
--     442 = critter_penguin
--     443 = critter_penguinbro
--    444 = critter_penguinking

function gadget:GameFrame(frame)
    if frame == 15 then
		--clean critters list of irrelevants, if empty add penguins

        for id, unit in pairs(initialUnits) do
            if id==UnitDefNames['critter_ant'].id or id==UnitDefNames['critter_crab'].id or id==UnitDefNames['critter_duck'].id or id==UnitDefNames['critter_penguin'].id then ---ant crab duck penguin
                table.insert(crittersPresent, id)
            end
        end


        if #crittersPresent == 0 then
            table.insert(crittersPresent, UnitDefNames['critter_penguin'].id)--add penwins
        end

		--Spring.Echo('hornet cp', #crittersPresent)


    end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    local frame = Spring.GetGameFrame ()
    if frame < 10 then

        --scan for critters present
        if teamID == gaiaID and string.find(UnitDefs[unitDefID].name, "critter_") then --rough double check, this should be only critters anyway
            initialUnits[unitDefID] = unitDefID
        end


    end
end



--Spring.Echo('hornet critters here')


function gadget:FeatureDestroyed(featureID, allyTeamID)
	--Spring.Echo('hornet fd')
    if allyTeamID == gaiaAllyID then
        --10% 1, 3.333% 2, ~1% 3

        if math.random(1,10) == 1 then
            currentCritter = crittersPresent[math.random(1, #crittersPresent)]
            local posx, posy, posz = Spring.GetFeaturePosition(featureID)
            local critterID = Spring.CreateUnit(currentCritter, posx, posy, posz, "north", Spring.GetGaiaTeamID())
            Spring.SetUnitBlocking(critterID, false)

            if math.random(1,3) == 1 then
                local critterID = Spring.CreateUnit(currentCritter, posx, posy, posz, "north", Spring.GetGaiaTeamID())
                Spring.SetUnitBlocking(critterID, false)
            end

            if math.random(1,3) == 1 then
                local critterID = Spring.CreateUnit(currentCritter, posx, posy, posz, "north", Spring.GetGaiaTeamID())
                Spring.SetUnitBlocking(critterID, false)
            end

        end

        --seperate gull roll
        if math.random(1,20) == 1 then
            local posx, posy, posz = Spring.GetFeaturePosition(featureID)
            local critterID = Spring.CreateUnit(UnitDefNames['critter_gull'].id, posx, posy, posz+5, "north", Spring.GetGaiaTeamID())
        end



    end
end
