function ScenarioScript_Trigger_Ambush()
    local killed = gadget:UnitDestroyed(unitID, unitDefID)
    if killed == true then
        local unitID = Spring.CreateUnit()
    else
        return
    end
end

local loadoutUnitsAlive = {} -- table of {unitID = true}
local objectiveUnits = {}

function gadget:Loadout()
    for i, loadout in ipairs(modopts.loadoutunits) do
    local unitID = Spring.CreateUnit(loadout)
    loadoutUnitsAlive[unitID] = true
        if loadout.objectiveID then 
            objectiveUnits[unitID] = loadout.objectiveID
        end
    end
end

function gadget:UnitDestroyed(unitID, ...)
    if loadoutUnitsAlive[unitID] then -- check it it hasent already died
        loadoutUnitsAlive[unitID] = nil -- remove it 
        if  objectiveUnits[unitID] then -- OPTION A
            DoObjective(objectiveUnits[unitID])
            objectiveUnits[unitID] = nil -- remove if needed
            
        end
    end
end
--[[
function gadget:GameFrame(n)
    --OPTION B
    for unitID, objectiveID in pairs(objectiveUnits) do 
        if loadoutUnitsAlive[unitID] == nil then -- the unit died
            DoObjective(objectiveUnits[unitID])
            objectiveUnits[unitID] = nil -- remove it
         end
    end
end

]]--


--[[local CMD_STOP = CMD.STOP
Spring.DestroyUnit(unitID, false, true)
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID ~= CMD_STOP then return end
    if not unitID then return end
    if teamID ~= Spring.GetMyTeamID() then return end

    if (Spring.GetUnitSelfDTime(unitID) > 0) then
        Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
    end 
end]]--




--[[function widgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam)
    for _,w in ipairs(self.UnitDestroyedList) do
      w:UnitDestroyed(unitID, unitDefID, unitTeam)
    end
    return
  end]]--



--UniDefNames['unitname'].id
--[[return {
	actions = {
		-- My custom actions go here
	},
	functions = {
        {
            humanName = "Zombies in area",
            name = "ZOMBIES_IN_AREA",
            input = {"area"},
            output = "unit_array",
            tags = {"Units"},
            execute = function()
                local units = {}
                for _, unitID in pairs(Spring.GetUnitsInRectangle(unpack(input.area))) do
                    if UnitDefs[Spring.GetUnitDefID(unitID)].customParams.zombie then
                        table.insert(units, unitID)
                    end
                end
                return units
            end
        },
	},
}]]--

