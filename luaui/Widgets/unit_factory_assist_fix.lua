local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Factory Assist Fix",
		desc    = "Fixes factory assist so that builders don't leave to repair damaged finished units",
		author  = "TheDujin",
		date    = "Jun 30 2025",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Globals
----------------------------------------------------------------
local myTeam = Spring.GetMyTeamID()

-- Tracks unit IDs of all assist-capable builders that I own and are alive
local myAssistBuilders = {}

local isAssistBuilder = {}

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

local CMD_REPAIR = CMD.REPAIR
local CMD_GUARD = CMD.GUARD
local CMD_REMOVE = CMD.REMOVE
local CMD_OPT_ALT = CMD.OPT_ALT

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and unitDef.canAssist then
		isAssistBuilder[unitDefID] = true
	end
end

-- If this builder unit is repairing the newly built unit when it should
-- instead be guarding the factory, remove the repair command
local function maybeRemoveRepairCmd(builderUnitID, builtUnitID, factID)
	local firstCmdID, _, _, firstCmdParam_1 = spGetUnitCurrentCommand(builderUnitID, 1)
	if firstCmdID ~= CMD_REPAIR or firstCmdParam_1 ~= builtUnitID then
		return -- there's no relevant repair command to remove
	end
	local secondCmdID, _, _, secondCmdParam_1 = spGetUnitCurrentCommand(builderUnitID, 2)
	if secondCmdID ~= CMD_GUARD or secondCmdParam_1 ~= factID then
		return -- there's no relevant factory guard, so the repair command is intentional
	end
	spGiveOrderToUnit(builderUnitID, CMD_REMOVE, firstCmdID, CMD_OPT_ALT)
end

function widget:UnitFromFactory(unitID, _, unitTeam, factID)
	if (not spAreTeamsAllied(myTeam, unitTeam)) then
		return -- impossible to be assisting enemy factory
	end
	local unitHealth, unitMaxHealth = spGetUnitHealth(unitID)
	if (unitHealth >= unitMaxHealth) then
		return -- if unit comes out with full health, guard works just fine
	end

	for myBuilderID in pairs(myAssistBuilders) do
		maybeRemoveRepairCmd(myBuilderID, unitID, factID)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if isAssistBuilder[unitDefID] then
		if unitTeam == myTeam then     -- i own it!
			myAssistBuilders[unitID] = true
		elseif myAssistBuilders[unitID] then -- formerly owned, but not anymore
			myAssistBuilders[unitID] = nil
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID)
	if myAssistBuilders[unitID] then -- it's dead :(
		myAssistBuilders[unitID] = nil
	end
end

------------------------------------------------------------------------------------------------
---------------------------------- SETUP AND TEARDOWN ------------------------------------------
------------------------------------------------------------------------------------------------

----- Returns true if the widget was actually removed
local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0) or Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return true
	end
end

function widget:Initialize()
	myTeam = Spring.GetMyTeamID()
	if maybeRemoveSelf() then
		return
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		widget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end

function widget:PlayerChanged()
	myTeam = Spring.GetMyTeamID()
	if maybeRemoveSelf() then
		return -- early-return, just in case any other logic is added below
	end
end
