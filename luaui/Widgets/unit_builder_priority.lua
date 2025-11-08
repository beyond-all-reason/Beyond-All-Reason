-- depends on gadget: unit_builder_priority
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Builder Priority",
		desc = "Allows to set builders (nanos, labs and cons) on low or high priority mode",
		author = "[teh]decay",
		date = "20 aug 2015",
		license = "GNU GPL, v2 or later",
		layer = 0,
		version = 8,
		enabled = true
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spEcho = Spring.Echo

local CMD_PRIORITY = GameCMD.PRIORITY

-- symbol localization optimization for engine calls
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local myTeamID = spGetMyTeamID()

-- widget global settings and assigned defaults
local lowpriorityLabs = true
local lowpriorityNanos = true
local lowpriorityCons = false

-- controlled units by category
local builderLabs = {}
local builderNanos = {}
local builderCons = {}

local unitIsBuilder = {}
local unitIsCommander = {}
local unitIsNano = {}
local unitIsLab = {}
local unitIsCons = {}
for udefID, def in ipairs(UnitDefs) do
	if def.isBuilder then
		unitIsBuilder[udefID] = def.id
		if def.customParams.iscommander then
			unitIsCommander[udefID] = true
		end
		if not def.canMove and not def.isFactory then
			unitIsNano[udefID] = true
		end
		if def.isFactory then
			unitIsLab[udefID] = true
		end
		if def.canMove and def.canAssist and not def.isFactory then
			unitIsCons[udefID] = true
		end
	end
end

local function toggleUnit(unitID, passive)
	if passive then
		spGiveOrderToUnit(unitID, CMD_PRIORITY, { 0 }, 0)
	else
		spGiveOrderToUnit(unitID, CMD_PRIORITY, { 1 }, 0)
	end
end

local function classifyUnit(unitID, unitDefID)
	if unitIsBuilder[unitDefID] and not unitIsCommander[unitDefID] then
		if unitIsNano[unitDefID] then
			builderNanos[unitID] = true
			toggleUnit(unitID, lowpriorityNanos)
		elseif unitIsLab[unitDefID] then
			builderLabs[unitID] = true
			toggleUnit(unitID, lowpriorityLabs)
		elseif unitIsCons[unitDefID] then
			builderCons[unitID] = true
			toggleUnit(unitID, lowpriorityCons)
		end
	end
end

local function declassifyUnit(unitID, unitDefID)
	if unitIsBuilder[unitDefID] and not unitIsCommander[unitDefID] then
		if unitIsNano[unitDefID] then
			builderNanos[unitID] = nil
		elseif unitIsLab[unitDefID] then
			builderLabs[unitID] = nil
		elseif unitIsCons[unitDefID] then
			builderCons[unitID] = nil
		end
	end
end

local function toggleCategory(builderIds, passive)
	spEcho("[passiveunits] Toggling category")
	for unitID, _ in pairs(builderIds) do
		spEcho("[passiveunits] Toggling " .. tostring(unitID) .. " to passive: " .. tostring(passive))
		toggleUnit(unitID, passive)
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

function widget:PlayerChanged(playerID)
	myTeamID = spGetMyTeamID()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end

	WG.builderpriority = {}
	WG.builderpriority.getLowPriorityNanos = function()
		return lowpriorityNanos
	end
	WG.builderpriority.setLowPriorityNanos = function(value)
		lowpriorityNanos = value
		toggleNanos()
	end
	WG.builderpriority.getLowPriorityLabs = function()
		return lowpriorityLabs
	end
	WG.builderpriority.setLowPriorityLabs = function(value)
		lowpriorityLabs = value
		toggleLabs()
	end
	WG.builderpriority.getLowPriorityCons = function()
		return lowpriorityCons
	end
	WG.builderpriority.setLowPriorityCons = function(value)
		lowpriorityCons = value
		toggleCons()
	end

	local myUnits = Spring.GetTeamUnits(myTeamID)
	for i = 1, #myUnits do
		local unitID = myUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		classifyUnit(unitID, unitDefID)
	end
end

function widget:Shutdown()
	WG.builderpriority = nil
end

function widget:UnitCreated(unitID, unitDefID, unitTeamID)
	if unitTeamID == myTeamID then
		classifyUnit(unitID, unitDefID)
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeamID)
	if unitTeamID == myTeamID then
		classifyUnit(unitID, unitDefID)
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeamID, newTeamID)
	if unitTeamID == myTeamID then
		declassifyUnit(unitID, unitDefID)
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeamID)
	if unitTeamID == myTeamID then
		classifyUnit(unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if unitTeam == myTeamID then
		declassifyUnit(unitID, unitDefID)
	end
end

function widget:GetConfigData()
	return {
		lowpriorityLabs = lowpriorityLabs,
		lowpriorityNanos = lowpriorityNanos,
		lowpriorityCons = lowpriorityCons,
	}
end

function widget:SetConfigData(cfg)
	lowpriorityLabs = cfg.lowpriorityLabs == true
	lowpriorityNanos = cfg.lowpriorityNanos == true
	lowpriorityCons = cfg.lowpriorityCons == true
end
