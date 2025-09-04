function widget:GetInfo()
    return {
      name = "Factory Alt Behavior",
      desc = "Queueing with alt in a factory won't cancel the current command.",
      author = "hihoman23",
      date = "Jan 2025",
      license = "GNU GPL, v2 or later",
      layer = 0,
      enabled = true
    }
end

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitWorkerTask = Spring.GetUnitWorkerTask

local CMD_INSERT = CMD.INSERT
local factoryBuildOpts = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.isFactory and unitDef.buildOptions then
        local opts = {}
        for _, opt in pairs(unitDef.buildOptions) do
            opts[opt] = true
        end
        factoryBuildOpts[unitDefID] = opts
    end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
    if cmdID < 0 and cmdOpts.alt and not cmdOpts.right then
        local factoryExists = false
        for _, unitID in ipairs(spGetSelectedUnits()) do
            local unitDefID = spGetUnitDefID(unitID)
            if factoryBuildOpts[unitDefID] and factoryBuildOpts[unitDefID][-cmdID] then
                factoryExists = true
                if not cmdOpts.internal then
                    cmdOpts.coded = cmdOpts.coded + CMD.OPT_INTERNAL -- prevent repeating command
                end
                local currentCmdID, targetID = spGetUnitWorkerTask(unitID)
                
                -- insert command into wanted position
                spGiveOrderToUnit(unitID, CMD_INSERT, {currentCmdID and 1 or 0, cmdID, cmdOpts.coded}, CMD.OPT_CTRL + CMD.OPT_ALT)
            end
        end
        return factoryExists
    end
end