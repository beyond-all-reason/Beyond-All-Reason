--
-- Builder Priority/Passive builders Widget (depends: gadget:unit_builder_priority)
--
-- Old Project page on github: https://github.com/SpringWidgets/passive-builders
--
-- Changelog:
--   v2 [teh]decay Fixed bug with rezz bots and spys
--   v3 [teh]decay exclude Commando from "passive" builders
--   v4 [teh]decay add ability to select which builders to put on passive mode: nanos, cons, labs
--   v5 [teh]Flow restyled + relative position + bugfix
--   v6 [teh]Flow removed GUI, options widget handles that part now
--   v7 Partial rewrite for better tracing and debugability
--   v8 [teh]Flow renamed widget from "Passive Builders" to "Builder Priority"
--
-- Notes:
--   - For debugging select all lines ending in "-- DEBUG" and uncomment

local info = {
	name = "Builder Priority",
	desc = "Allows to set builders (nanos, labs and cons) on low or high priority mode",
	author = "[teh]decay",
	date = "20 aug 2015",
	license = "GNU GPL, v2 or later",
	layer = 0,
	version = 8,
	enabled = true  -- loaded by default
}

local CMD_PRIORITY = 34571

-- symbol localization optimization for engine calls
local spEcho = Spring.Echo
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetPlayerInfo = Spring.GetPlayerInfo

local armCommanderDefId = UnitDefNames["armcom"].id
local corCommanderDefId = UnitDefNames["corcom"].id

-- widget global settings and assigned defaults
local lowpriorityLabs = true
local lowpriorityNanos = true
local lowpriorityCons = false

-- controlled units by category
local builderLabs = {}
local builderNanos = {}
local builderCons = {}
-- local builderUnknown = {}  -- DEBUG

local function isNano(unitDef)
	return not unitDef.canMove and not unitDef.isFactory
end

local function isLab(unitDef)
	return unitDef.isFactory
end

local function isCons(unitDef)
	return unitDef.canMove and unitDef.canAssist and not unitDef.isFactory
end

local function highpriorityBuilder(unitId)
	spGiveOrderToUnit(unitId, CMD_PRIORITY, { 1 }, 0)
end

local function lowpriorityBuilder(unitId)
	spGiveOrderToUnit(unitId, CMD_PRIORITY, { 0 }, 0)
end

local function toggleUnit(unitId, passive)
	if passive then
		lowpriorityBuilder(unitId)
	else
		highpriorityBuilder(unitId)
	end
end

local function classifyUnit(unitId, unitDef)
	-- spEcho("[passiveunits] Classifiying unit. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG

	if not unitDef.isBuilder then
		-- spEcho("[passiveunits] Classified unit is not a builder. Skipping.")  -- DEBUG
		return  -- skip if it is not a builder
	end

	local is_armcom = unitDef.id == armCommanderDefId
	local is_corcom = unitDef.id == corCommanderDefId

	if is_armcom or is_corcom then
		-- spEcho("[passiveunits] Classified unit is a commander. Skipping.")  -- DEBUG
		return -- skip the commanders
	end

	if isNano(unitDef) then
		-- spEcho("[passiveunits] Classified unit is a nano. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderNanos[unitId] = true
		toggleUnit(unitId, lowpriorityNanos)
		return
	end

	if isLab(unitDef) then
		-- spEcho("[passiveunits] Classified unit is a lab. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderLabs[unitId] = true
		toggleUnit(unitId, lowpriorityLabs)
		return
	end

	if isCons(unitDef) then
		-- spEcho("[passiveunits] Classified unit is a cons. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderCons[unitId] = true
		toggleUnit(unitId, lowpriorityCons)
		return
	end

	-- spEcho("[passiveunits] Classified unit is a cons. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
	-- builderUnknown[unitId] = true  -- DEBUG
end

local function declassifyUnit(unitId, unitDef)
	-- spEcho("[passiveunits] Declassifying unit. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG

	if not unitDef.isBuilder then
		-- spEcho("[passiveunits] Declassified unit is not a builder. Skipping.")  -- DEBUG
		return  -- skip if it is not a builder
	end

	local is_armcom = unitDef.id == armCommanderDefId
	local is_corcom = unitDef.id == corCommanderDefId

	if is_armcom or is_corcom then
		-- spEcho("[passiveunits] Declassified unit is a commander. Skipping.")  -- DEBUG
		return -- skip the commanders
	end

	if isNano(unitDef) then
		-- spEcho("[passiveunits] Declassified unit is a nano. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderNanos[unitId] = nil
		return
	end

	if isLab(unitDef) then
		-- spEcho("[passiveunits] Declassified unit is a lab. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderLabs[unitId] = nil
		return
	end

	if isCons(unitDef) then
		-- spEcho("[passiveunits] Declassified unit is a cons. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderCons[unitId] = nil
		return
	end

	-- spEcho("[passiveunits] Declassified unit is a cons. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
	-- builderUnknown[unitId] = nil  -- DEBUG
end

local function toggleCategory(builderIds, passive)
	spEcho("[passiveunits] Toggling category")

	for unitId, _ in pairs(builderIds) do
		spEcho("[passiveunits] Toggling " .. tostring(unitId) .. " to passive: " .. tostring(passive))

		toggleUnit(unitId, passive)
	end
end

local function toggleNanos()
	toggleCategory(builderNanos, lowpriorityNanos)
end

local function toggleLabs()
	toggleCategory(builderLabs, lowpriorityLabs)
end

local function toggleCons()
	toggleCategory(builderCons, lowpriorityCons)
end

--
-- Callin handlers
--
local function handleNewUnit(unitId, unitDefId, unitTeamId)
	if (unitTeamId ~= spGetMyTeamID()) then
		return  -- created/finished/given unit is not ours at the point of the event
	end

	local unitDef = UnitDefs[unitDefId]

	if unitDef == nil then
		return  -- this unit has no asociated definition
	end

	classifyUnit(unitId, unitDef)
end

local function handleRemovedUnit(unitId, unitDefId, unitTeamId)
	if (unitTeamId ~= spGetMyTeamID()) then
		return  -- removed/taken/given unit is not ours at the point of the event
	end

	local unitDef = UnitDefs[unitDefId]

	if unitDef == nil then
		return  -- this unit has no asociated definition
	end

	declassifyUnit(unitId, unitDef)
end

local function handleWidgetReload()
	local myId = spGetMyPlayerID()
	local myTeamId = spGetMyTeamID()

	if select(3, spGetPlayerInfo(myId, false)) then
		return
	end

	local myUnits = spGetTeamUnits(myTeamId)

	for i = 1, #myUnits do
		local unitId = myUnits[i]
		local unitDefId = spGetUnitDefID(unitId)

		handleNewUnit(unitId, unitDefId, myTeamId)
	end
end

--
-- Callins (widget setup/config/teardown)
--
function widget:GetInfo()
	return info
end

function widget:GetConfigData()
	-- spEcho("[builder_priority] widget:GetConfigData (nanos: "..tostring(lowpriorityNanos).." cons: "..tostring(lowpriorityCons).." labs: "..tostring(lowpriorityLabs)..")")  -- DEBUG

	return {
		lowpriorityLabs = lowpriorityLabs,
		lowpriorityNanos = lowpriorityNanos,
		lowpriorityCons = lowpriorityCons,
	}
end

function widget:SetConfigData(cfg)
	-- spEcho("[builder_priority] widget:SetConfigData (nanos: "..tostring(cfg.lowpriorityNanos).." cons: "..tostring(cfg.lowpriorityCons).." labs: "..tostring(cfg.lowpriorityLabs)..")")  -- DEBUG

	lowpriorityLabs = cfg.lowpriorityLabs == true
	lowpriorityNanos = cfg.lowpriorityNanos == true
	lowpriorityCons = cfg.lowpriorityCons == true
end

function widget:Initialize()
	-- spEcho("[builder_priority] Initializing plugin")  -- DEBUG

	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end

	WG['builderpriority'] = {}

	WG['builderpriority'].getLowPriorityNanos = function()
		return lowpriorityNanos
	end

	WG['builderpriority'].setLowPriorityNanos = function(value)
		-- spEcho("[builder_priority] Toggling nanos from "..tostring(lowpriorityNanos).." to "..tostring(value))  -- DEBUG
		lowpriorityNanos = value
		toggleNanos()
	end

	WG['builderpriority'].getLowPriorityLabs = function()
		return lowpriorityLabs
	end

	WG['builderpriority'].setLowPriorityLabs = function(value)
		-- spEcho("[builder_priority] Toggling factories from "..tostring(lowpriorityLabs).." to "..tostring(value))  -- DEBUG
		lowpriorityLabs = value
		toggleLabs()
	end

	WG['builderpriority'].getLowPriorityCons = function()
		return lowpriorityCons
	end

	WG['builderpriority'].setLowPriorityCons = function(value)
		-- spEcho("[builder_priority] Toggling constructors from "..tostring(lowpriorityCons).." to "..tostring(value))  -- DEBUG
		lowpriorityCons = value
		toggleCons()
	end

	handleWidgetReload()
end

function widget:Shutdown()
	WG['builderpriority'] = nil
end

function widget:GameStart()
	widget:PlayerChanged()
end

--
-- Callins (game state change handlers)
--
function widget:UnitCreated(unitId, unitDefId, unitTeamId)
	handleNewUnit(unitId, unitDefId, unitTeamId)
end

function widget:UnitGiven(unitId, unitDefId, unitTeamId)
	handleNewUnit(unitId, unitDefId, unitTeamId)
end

function widget:UnitTaken(unitId, unitDefId, unitTeamId, newTeamId)
	handleRemovedUnit(unitId, unitDefId, unitTeamId)
end

function widget:UnitFinished(unitId, unitDefId, unitTeamId)
	handleNewUnit(unitId, unitDefId, unitTeamId)
end

function widget:UnitDestroyed(unitId, unitDefId, unitTeamId, attackerId, attackerDefId, attackerTeamId)
	handleRemovedUnit(unitId, unitDefId, unitTeamId)
end

function widget:PlayerChanged(playerId)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end
