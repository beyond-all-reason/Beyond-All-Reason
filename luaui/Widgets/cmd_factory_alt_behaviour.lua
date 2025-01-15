function widget:GetInfo()
    return {
      name = "Factory Alt Behaviour",
      desc = "Queueing with alt in a factory won't cancel the current command.",
      author = "hihoman23",
      date = "2024",
      license = "GNU GPL, v2 or later",
      layer = 0,
      enabled = false
    }
end

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitWorkerTask = Spring.GetUnitWorkerTask

local CMD_INSERT = CMD.INSERT

local isFactory = {}
local buildOpts = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.isFactory then
        isFactory[unitDefID] = true
    end
    if unitDef.buildOptions then
        local opts = {}
        for _, opt in pairs(unitDef.buildOptions) do
            opts[opt] = true
        end
        buildOpts[unitDefID] = opts
    end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
    if cmdID < 0 and cmdOpts.alt and not cmdOpts.right then
        local factoryExists = false
        for _, unitID in ipairs(spGetSelectedUnits()) do
            local unitDefID = spGetUnitDefID(unitID)
            if isFactory[unitDefID] and buildOpts[unitDefID][-cmdID] then
                factoryExists = true
                if not cmdOpts.internal then
                    cmdOpts.coded = cmdOpts.coded + CMD.OPT_INTERNAL -- prevent repeating command
                end
                local currentCmdID, targetID = spGetUnitWorkerTask(unitID)
                spGiveOrderToUnit(unitID, CMD_INSERT, {currentCmdID and 1 or 0, cmdID, cmdOpts.coded}, {"ctrl", "alt"})
            end
        end
        return factoryExists
    end
end

function widget:PlayerChanged()
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:Initialize()
    widget:PlayerChanged()
end