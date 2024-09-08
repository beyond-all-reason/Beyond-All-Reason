
function widget:GetInfo()
    return {
      name = "Factory Quotas",
      desc = "Creates quotas of units that should be fulfilled(for example 5 Sheldons, 5 Sumos), will be queued before factory queue.",
      author = "hihoman23",
      date = "2024",
      license = "GNU GPL, v2 or later",
      layer = -1,
      enabled = true,
      handler = true
    }
end

VFS.Include('luarules/configs/customcmds.h.lua')

local maxBuildProg = 0.075 -- maximum build progress that gets replaced in a repeat queue
local maxMetal = 500 -- maximum metal cost that gets replaced in a repeat queue(7.5% of a juggernaut is still over 2k metal)

-- factoryID is unitID of the factory
local quotas = {} -- {[factoryID] = {[unitDefID] = amount, ...}, ...}

local builtUnits = {} -- {[factoryID] = {[unitDefID] = {[unitID] = true, ...}, ...}, ...}
local unitToFactoryID = {} -- {[unitID] = factoryID, ...}

local possibleFactories = {}
local factoryDefIDs = {}
local metalcosts = {}

for unitDefID, uDef in pairs(UnitDefs) do
    metalcosts[unitDefID] = uDef.metalCost
    if uDef.isFactory then
        factoryDefIDs[unitDefID] = true
        for _, opt in pairs(uDef.buildOptions) do
            possibleFactories[opt] = possibleFactories[opt] or {}
            possibleFactories[opt][unitDefID] = true
        end
    end
end

----- Speed ups ------
local myTeam = Spring.GetMyTeamID()
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitDefID = Spring.GetUnitDefID
local spGetRealBuildQueue = Spring.GetRealBuildQueue
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
-----

--------- quota logic -------------
local function getNumberOfUnits(factoryID, unitDefID)
    local numberOfUnits
    if builtUnits[factoryID] and builtUnits[factoryID][unitDefID] then
        numberOfUnits = table.count(builtUnits[factoryID][unitDefID])
    else
        numberOfUnits = 0
    end
    return numberOfUnits
end

local function getMostNeedQuota(quota, factoryID)
    local minimumQuota
    local minimumUnitDefID
    local minimumRatio
    for unitDefID, quotaNumber in pairs(quota) do
        if not minimumQuota then
            minimumQuota = quotaNumber
            minimumUnitDefID = unitDefID
            minimumRatio = getNumberOfUnits(factoryID, unitDefID)/quotaNumber
            
        else
            local currentRatio = getNumberOfUnits(factoryID, unitDefID)/quotaNumber
            if currentRatio < minimumRatio then
                minimumQuota = quotaNumber
                minimumUnitDefID = unitDefID
                minimumRatio = currentRatio
            end
        end
    end
    return minimumQuota, minimumUnitDefID
end

local function isFactoryUsable(factoryID)
    local commandQueue = spGetFactoryCommands(factoryID, 2)
    if not commandQueue then
        return true
    end
    return commandQueue and( #commandQueue == 0 or not (commandQueue[1].options.alt or (commandQueue[2] and commandQueue[2].options.alt)))
end

local function orderDequeue(unitID, buildDefID, count)
	while count > 0 do
		count = count - 100

		spGiveOrderToUnit(unitID, -buildDefID, {}, { "right", "ctrl", "shift" })
	end
end

local function clearFactoryQueue(factoryID)
    
	local queue = spGetRealBuildQueue(factoryID)

	if queue ~= nil then
		for _, buildPair in ipairs(queue) do
			local buildUnitDefID, count = next(buildPair, nil)

			orderDequeue(factoryID, buildUnitDefID, count)
		end
	end
end

local function prependToFactoryQueue(...)
    local factoryID, cmdID, params, opts = ...
    local commandQueue = spGetFactoryCommands(factoryID, -1)
    local altCmds = {}
    local others = {}
    for _, cmd in ipairs(commandQueue) do
        if cmd.options.alt then
            altCmds[#altCmds+1] = cmd
        else
            others[#others+1] = cmd
        end
    end

    clearFactoryQueue(factoryID)

    for i = #altCmds, 1, -1 do -- do alt queue backwards
        local cmd = altCmds[i]
        spGiveOrderToUnit(factoryID, cmd.id, cmd.params, cmd.options)
    end
    spGiveOrderToUnit(...)
    for _, cmd in ipairs(others) do
        spGiveOrderToUnit(factoryID, cmd.id, cmd.params, cmd.options)
    end
end

local function appendToFactoryQueue(...)
    local factoryID, cmdID, params, opts = ...
    local currentCmd, targetID = Spring.GetUnitWorkerTask(factoryID)
    local insertNormally = true
    if targetID and Spring.GetUnitStates(factoryID)["repeat"] then
        local _, _, _, _, buildProgress = Spring.GetUnitHealth(targetID)
        if buildProgress < maxBuildProg and metalcosts[-currentCmd] and (buildProgress * metalcosts[-currentCmd]) < maxMetal then -- 7.5 % is the most that it is willing to cancel, and maximally 500 metal
            insertNormally = false
        end
    end
    if insertNormally then
        spGiveOrderToUnit(...)
    else
        prependToFactoryQueue(...)
    end
end

local function fillQuotas()
    for factoryID, quota in pairs(quotas) do
        if isFactoryUsable(factoryID) then
            for unitDefID, num in pairs(quota) do
                if num == 0 then
                    quota[unitDefID] = nil
                end
            end
            if table.count(quota)>0 then
                local quotaNum, unitDefID = getMostNeedQuota(quota, factoryID)
                if quotaNum > getNumberOfUnits(factoryID, unitDefID) then
                    appendToFactoryQueue(factoryID, -unitDefID, {}, {"alt"})
                end
            end
        end
    end
end

function widget:GameFrame(n)
    if n % 4 == 0 then -- improve perfomance
        fillQuotas()
    end
end

----- handle toggle
local function isOnQuotaBuildMode(unitID)
	return spGetUnitCmdDescs(unitID)[spFindUnitCmdDesc(unitID, CMD_QUOTA_BUILD_TOGGLE)].params[1]+0 == 1
end

function widget:SelectionChanged(newSelection)
    for _, unitID in ipairs(newSelection) do
        if factoryDefIDs[spGetUnitDefID(unitID)] and isOnQuotaBuildMode(unitID) then
            spGiveOrderToUnit(unitID, CMD_QUOTA_BUILD_TOGGLE, {0}, {})
        end
    end
end

----- handle unit tracking
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if builderID and unitTeam == myTeam and factoryDefIDs[spGetUnitDefID(builderID)] then
        builtUnits[builderID] = builtUnits[builderID] or {}
        builtUnits[builderID][unitDefID] = builtUnits[builderID][unitDefID] or {}
        builtUnits[builderID][unitDefID][unitID] = true
        unitToFactoryID[unitID] = builderID
    end
end

local function removeUnit(unitID, unitDefID, unitTeam)
    if unitTeam == myTeam and unitToFactoryID[unitID] then --check if it was built by the same player
        builtUnits[unitToFactoryID[unitID]][unitDefID][unitID] = nil
        unitToFactoryID[unitID] = nil
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    removeUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
    if myTeam == oldTeam and myTeam ~= newTeam then
        removeUnit(unitID, unitDefID, myTeam)
    end
end


function widget:PlayerChanged(playerID)
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget(self)
    end
    myTeam = Spring.GetMyTeamID()
end

function widget:Initialize()
    widget:PlayerChanged()

    WG.Quotas = {}
    WG.Quotas.getQuotas = function()
        return quotas
    end
    WG.Quotas.update = function(newQuotas)
        quotas = newQuotas
    end
    WG.Quotas.getUnitAmount = function(factoryID, unitDefID)
        return getNumberOfUnits(factoryID, unitDefID)
    end
    WG.Quotas.getToggleState = function(unitID)
        return isOnQuotaBuildMode(unitID)
    end
end

function widget:Shutdown()
    WG.Quotas = nil
end
