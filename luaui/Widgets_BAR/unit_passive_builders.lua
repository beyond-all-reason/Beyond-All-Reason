--
-- Passive Builders Widget (depends: gadget:unit_passive_builders)
--
-- Project page on github: https://github.com/SpringWidgets/passive-builders
--
-- Changelog:
--   v2 [teh]decay Fixed bug with rezz bots and spys
--   v3 [teh]decay exclude Commando from "passive" builders
--   v4 [teh]decay add ability to select which builders to put on passive mode: nanos, cons, labs
--   v5 [teh]Flow restyled + relative position + bugfix
--   v6 [teh]Flow removed GUI, options widget handles that part now
--   v7 Partial rewrite for better tracing and debugability
--
-- Notes:
--   - Some code was used from "Wind Speed" widget. Thx to Jazcash and Floris!
--   - For debugging select all lines ending in "-- DEBUG" and uncomment
--

local info = {
	name = "Passive builders",
	desc = "Allows to set builders (nanos, labs and cons) on passive mode",
	author = "[teh]decay",
	date = "20 aug 2015",
	license = "GNU GPL, v2 or later",
	layer = 0,
	version = 7,
	enabled = true  -- loaded by default
}

local CMD_PASSIVE = 34571

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
local passiveLabs = true
local passiveNanos = true
local passiveCons = false

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

local function activateBuilder(unitId)
	spGiveOrderToUnit(unitId, CMD_PASSIVE, { 0 }, 0)
end

local function passivateBuilder(unitId)
	spGiveOrderToUnit(unitId, CMD_PASSIVE, { 1 }, 0)
end

local function toggleUnit(unitId, passive)
	if passive then
		passivateBuilder(unitId)
	else
		activateBuilder(unitId)
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
		toggleUnit(unitId, passiveNanos)
		return
	end

	if isLab(unitDef) then
		-- spEcho("[passiveunits] Classified unit is a lab. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderLabs[unitId] = true
		toggleUnit(unitId, passiveLabs)
		return
	end

	if isCons(unitDef) then
		-- spEcho("[passiveunits] Classified unit is a cons. ID: "..unitId.." Type: "..unitDef.name)  -- DEBUG
		builderCons[unitId] = true
		toggleUnit(unitId, passiveCons)
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
	toggleCategory(builderNanos, passiveNanos)
end

local function toggleLabs()
	toggleCategory(builderLabs, passiveLabs)
end

local function toggleCons()
	toggleCategory(builderCons, passiveCons)
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
	-- spEcho("[passive_builders] widget:GetConfigData (nanos: "..tostring(passiveNanos).." cons: "..tostring(passiveCons).." labs: "..tostring(passiveLabs)..")")  -- DEBUG

	return {
		passiveLabs = passiveLabs,
		passiveNanos = passiveNanos,
		passiveCons = passiveCons,
	}
end

function widget:SetConfigData(cfg)
	-- spEcho("[passive_builders] widget:SetConfigData (nanos: "..tostring(cfg.passiveNanos).." cons: "..tostring(cfg.passiveCons).." labs: "..tostring(cfg.passiveLabs)..")")  -- DEBUG

	passiveLabs = cfg.passiveLabs == true
	passiveNanos = cfg.passiveNanos == true
	passiveCons = cfg.passiveCons == true
end

function widget:Initialize()
	-- spEcho("[passive_builders] Initializing plugin")  -- DEBUG

	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end

	WG['passivebuilders'] = {}

	WG['passivebuilders'].getPassiveNanos = function()
		return passiveNanos
	end

	WG['passivebuilders'].setPassiveNanos = function(value)
		-- spEcho("[passive_builders] Toggling nanos from "..tostring(passiveNanos).." to "..tostring(value))  -- DEBUG
		passiveNanos = value
		toggleNanos()
	end

	WG['passivebuilders'].getPassiveLabs = function()
		return passiveLabs
	end

	WG['passivebuilders'].setPassiveLabs = function(value)
		-- spEcho("[passive_builders] Toggling factories from "..tostring(passiveLabs).." to "..tostring(value))  -- DEBUG
		passiveLabs = value
		toggleLabs()
	end

	WG['passivebuilders'].getPassiveCons = function()
		return passiveCons
	end

	WG['passivebuilders'].setPassiveCons = function(value)
		-- spEcho("[passive_builders] Toggling constructors from "..tostring(passiveCons).." to "..tostring(value))  -- DEBUG
		passiveCons = value
		toggleCons()
	end

	handleWidgetReload()
end

function widget:Shutdown()
	WG['passivebuilders'] = nil
end

function widget:GameStart()
	widget:PlayerChanged()
end

--
-- Callins (game state change handlers)
--
function widget:UnitCreated(unitId, unitDefId, unitTeamId)
	handleNewUnit(unitId, unitDef, unitTeamId)
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
		widgetHandler:RemoveWidget(self)
	end
end
