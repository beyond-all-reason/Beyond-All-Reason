local versionNum = '5.00'

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Auto Group",
		desc = "v" .. (versionNum) .. " Alt+0-9 sets autogroup# for selected unit type(s). Newly built units get added to group# equal to their autogroup#. Alt BACKQUOTE (~) remove units. Type '/luaui autogroup help' for help or view settings at: Settings/Interface/AutoGroup'.",
		author = "Licho",
		date = "Mar 23, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end


-- Localized functions for performance
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits

include("keysym.h.lua")

---- CHANGELOG -----
-- hihoman23,       v5.00   (01nov2023) :   Allows for multiple presets, which are controlled with load_autogroup_preset,
--											for different saved group presets.
-- badosu born2crawl,		v4.01	(08oct2021)	: 	Use actions instead of hardcoded keybindings
-- versus666,		v3.03	(17dec2011)	: 	Back to alt BACKQUOTE to remove selected units from group
--											to please licho, changed help accordingly.
-- versus666,		v3.02	(16dec2011)	: 	Fixed for 84, removed unused features, now alt backspace to remove
--											selected units from group, changed help accordingly.
-- versus666,		v3.01	(07jan2011)	: 	Added check to comply with F5.
-- wagonrepairer	v3.00	(07dec2010)	:	'Chilified' autogroup.
-- versus666, 		v2.25	(04nov2010)	:	Added switch to show or not group number, by licho's request.
-- versus666, 		v2.24	(27oct2010)	:	Added switch to auto add units when built from factories.
--											Add group label numbers to units in group.
--											Sped up some routines & cleaned code.
--		?,			v2,23				:	Unknown.
-- very_bad_solider,v2.22				:	Ignores buildings and factories.
--											Does not react when META (+ALT) is pressed.
-- CarRepairer,		v2.00				:	Autogroups key is alt instead of alt+ctrl.
--											Added commands: help, loadgroups, cleargroups, verboseMode, addall.
-- Licho,			v1.0				:	Creation.

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local currPreset = 1

local addall = true
local immediate = true
local persist = true
local verbose = true

local rejectedUnits = {} -- contains units, which didn't load, like legion in non-legion games

local presets = {} -- contains ten "presets", which can be used like unit2group
for i = 0, 9 do
	presets[i] = {}
	rejectedUnits[i] = {}
end
local unit2group = presets[currPreset] -- list of unit types to group


local mobileBuilders = {}
local builtInPlace = {}

for udefID, def in ipairs(UnitDefs) do
	if not def.isFactory then
		if def.buildOptions and #def.buildOptions > 0 then
			mobileBuilders[udefID] = true
		end
	end
end

local finiGroup = {}
local myTeam = spGetMyTeamID()
local createdFrame = {}
local toBeAddedLater = {}
local prevHealth = {}

local gameStarted

local GetUnitGroup = Spring.GetUnitGroup
local SetUnitGroup = Spring.SetUnitGroup
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = spGetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local GetMouseState = Spring.GetMouseState
local SelectUnitArray = Spring.SelectUnitArray
local TraceScreenRay = Spring.TraceScreenRay
local GetUnitPosition = Spring.GetUnitPosition
local GetGameFrame = spGetGameFrame
local Echo = Spring.Echo
local GetUnitRulesParam = Spring.GetUnitRulesParam


function widget:GameStart()
	gameStarted = true
	widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
		return
	end
	myTeam = spGetMyTeamID()
end

local function addAllUnits()
	for _, unitID in ipairs(spGetTeamUnits(myTeam)) do
		local unitDefID = GetUnitDefID(unitID)
		local gr = unit2group[unitDefID]
		if gr ~= nil and GetUnitGroup(unitID) == nil then
			SetUnitGroup(unitID, gr)
		end
	end
end

local function changeUnitTypeAutogroup(gr, removeAll)
	if not removeAll and not gr then return end -- noop if add to autogroup and no argument

	if removeAll then
		gr = nil
	end

	local selUnitDefIDs = {}
	local exec = false --set to true when there is at least one unit to process
	local units = GetSelectedUnits()
	for i = 1, #units do
		local unitID = units[i]
		local udid = GetUnitDefID(unitID)
		selUnitDefIDs[udid] = true
		unit2group[udid] = gr
		exec = true
		if gr == nil then
			SetUnitGroup(unitID, -1)
		else
			SetUnitGroup(unitID, gr)
		end
	end
	presets[currPreset] = unit2group
	if exec == false then
		return false --nothing to do
	end
	for udid, _ in pairs(selUnitDefIDs) do
		if verbose then
			if gr then
				Echo( Spring.I18N('ui.autogroups.unitAdded', { unit = UnitDefs[udid].translatedHumanName, groupNumber = gr }) )
			else
				Echo( Spring.I18N('ui.autogroups.unitRemoved', { unit = UnitDefs[udid].translatedHumanName }) )
			end
		end
	end
	if addall then
		local myUnits = spGetTeamUnits(myTeam)
		for i = 1, #myUnits do
			local unitID = myUnits[i]
			local curUnitDefID = GetUnitDefID(unitID)
			if selUnitDefIDs[curUnitDefID] then
				if gr then
					if immediate or not GetUnitIsBeingBuilt(unitID) then
						SetUnitGroup(unitID, gr)
						SelectUnitArray({ unitID }, true)
					end
				else
					SetUnitGroup(unitID, -1)
				end
			end
		end
	end

	return true
end

local function changeUnitTypeAutogroupHandler(_, _, args, data)
	local gr = args and args[1]
	local removeAll = data and data['removeAll']

	changeUnitTypeAutogroup(gr, removeAll)
end

local function removeOneUnitFromGroupHandler(_, _, args)
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	local mindist = math.huge
	local muid = nil
	if pos == nil then
		return
	end
	local units = GetSelectedUnits()
	local dist
	for i = 1, #units do
		local unitID = units[i]
		local x, _, z = GetUnitPosition(unitID)
		dist = (pos[1] - x) * (pos[1] - x) + (pos[3] - z) * (pos[3] - z)
		if dist < mindist then
			mindist = dist
			muid = unitID
		end
	end
	if muid ~= nil then
		SetUnitGroup(muid, -1)
		SelectUnitArray({ muid })
	end

	return true
end

local function loadAutogroupPreset(newPreset)
	if not presets[newPreset] then
		return
	end
	local prevGroup = presets[currPreset]

	currPreset = newPreset

	Echo(Spring.I18N("ui.autogroups.presetSelected", {presetNum = currPreset}))
	unit2group = presets[currPreset]

	if not unit2group then
		return
	end

	for _, uID in ipairs(spGetTeamUnits(myTeam)) do
		local unitDefID = GetUnitDefID(uID)
		local group = unit2group[unitDefID]
		if tonumber(prevGroup[unitDefID]) == GetUnitGroup(uID) then -- if in last
			SetUnitGroup(uID, -1)
		end

		if group ~= nil and GetUnitGroup(uID) == nil and addall then
			SetUnitGroup(uID, group)
		end
	end
end

local function loadAutogroupPresetHandler(cmd, optLine, optWords, data, isRepeat, release, actions)
	loadAutogroupPreset(tonumber(optWords[1]))
end


function widget:Initialize()

	widget:PlayerChanged()

	widgetHandler:AddAction("add_to_autogroup", changeUnitTypeAutogroupHandler, nil, "p") -- With a parameter, adds all units of this type to a specific autogroup
	widgetHandler:AddAction("remove_from_autogroup", changeUnitTypeAutogroupHandler, { removeAll = true }, "p") -- Without a parameter, removes all units of this type from autogroups
	widgetHandler:AddAction("remove_one_unit_from_group", removeOneUnitFromGroupHandler, nil, "p") -- Removes the closest of selected units from groups and selects only it
	widgetHandler:AddAction("load_autogroup_preset", loadAutogroupPresetHandler, nil, "p") -- Changes the autogroup preset

	WG['autogroup'] = {}
	WG['autogroup'].getImmediate = function()
		return immediate
	end
	WG['autogroup'].setImmediate = function(value)
		immediate = value
	end

	WG['autogroup'].getPersist = function()
		return persist
	end
	WG['autogroup'].setPersist = function(value)
		persist = value
	end
	WG['autogroup'].getGroups = function()
		return unit2group
	end
	WG['autogroup'].addCurrentSelectionToAutogroup = function(groupNumber)
		changeUnitTypeAutogroup(groupNumber)
	end
	WG['autogroup'].removeCurrentSelectionFromAutogroup = function()
		changeUnitTypeAutogroup(nil, true)
	end
	WG['autogroup'].removeOneUnitFromGroup = function()
		removeOneUnitFromGroupHandler()
	end
	WG['autogroup'].loadAutogroupPreset = function(newPreset)
		loadAutogroupPreset(newPreset)
	end
	if GetGameFrame() > 0 then
		addAllUnits()
	end
end

function widget:Shutdown()
	WG['autogroup'] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeam or unitID == nil or GetUnitRulesParam(unitID, "resurrected") then
		return
	end

	local builtInFrame = createdFrame[unitID] == GetGameFrame()

	if not builtInFrame then
		finiGroup[unitID] = 1
	end

	if not immediate and ((builtInPlace[unitID] and Spring.GetUnitCommandCount(unitID) == 0) or builtInFrame) then
		local gr = unit2group[unitDefID]
		if gr ~= nil and GetUnitGroup(unitID) == nil then
			SetUnitGroup(unitID, gr)
		end
	end

	builtInPlace[unitID] = nil
end

function widget:GameFrame(n)
	if n % 10 == 0 then
		for unitID, unitDefID in pairs(toBeAddedLater) do
			local health = GetUnitHealth(unitID)
			if health <= prevHealth[unitID] then -- stopped healing
				local group = unit2group[unitDefID]
				if group ~= nil and GetUnitGroup(unitID) == nil then
					SetUnitGroup(unitID, group)
				end
				toBeAddedLater[unitID] = nil
				prevHealth[unitID] = nil
			else
				prevHealth[unitID] = health
			end
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam ~= myTeam then return end

	createdFrame[unitID] = GetGameFrame()

	if builderID and mobileBuilders[spGetUnitDefID(builderID)] then
		builtInPlace[unitID] = true
	end

	if GetUnitRulesParam(unitID, "resurrected") then
		toBeAddedLater[unitID] = unitDefID
		prevHealth[unitID] = 0
		return
	end

	if immediate then
		local gr = unit2group[unitDefID]
		if gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	finiGroup[unitID] = nil
	createdFrame[unitID] = nil
	builtInPlace[unitID] = nil
	toBeAddedLater[unitID] = nil
	prevHealth[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeamID, teamID)
	if newTeamID == myTeam then
		local gr = unit2group[unitDefID]
		if gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
	end
	finiGroup[unitID] = nil
	createdFrame[unitID] = nil
	builtInPlace[unitID] = nil
	toBeAddedLater[unitID] = nil
	prevHealth[unitID] = nil
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
	if teamID == myTeam then
		local gr = unit2group[unitDefID]
		if gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
	end
	finiGroup[unitID] = nil
	createdFrame[unitID] = nil
	builtInPlace[unitID] = nil
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam and finiGroup[unitID] ~= nil then
		local gr = unit2group[unitDefID]
		if immediate ~= true and gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
		finiGroup[unitID] = nil
	end
end

function widget:GetConfigData()
	local savePresets = {}
	for i = 0, 9 do
		local preset = presets[i]
		local groups = {}
		if persist then
			for id, gr in pairs(preset) do
				tableInsert(groups, { UnitDefs[id].name, gr })
			end
			for name, gr in pairs(rejectedUnits[i]) do
				tableInsert(groups, { name, gr })
			end
		end
		savePresets[i] = groups
	end
	local ret = {
		version = versionNum,
		presets = savePresets,
		immediate = immediate,
		persist = persist,
		verbose = verbose,
		addall = addall,
	}
	return ret
end

function widget:SetConfigData(data)
	if data and type(data) == 'table' and data.version and (data.version + 0) > 2.1 and (data.version + 0) < 5 then -- still use v4 saves
		if data.immediate ~= nil then
			immediate = data.immediate
			verbose = data.verbose
			addall = data.addall
		end
		if data.persist ~= nil then
			persist = data.persist
		end
		local groupData = data.groups
		if groupData and type(groupData) == 'table' then
			for _, nam in ipairs(groupData) do
				if type(nam) == 'table' then
					local gr = UnitDefNames[nam[1]]
					if gr ~= nil then
						unit2group[gr.id] = tonumber(nam[2])
					end
				end
			end
		end
		presets[1] = unit2group
	end
	if data and type(data) == 'table' and data.version and (data.version + 0) >= 5 then
		if data.immediate ~= nil then
			immediate = data.immediate
			verbose = data.verbose
			addall = data.addall
		end
		if data.persist ~= nil then
			persist = data.persist
		end
		local groupData = data.presets
		if groupData and type(groupData) == 'table' and groupData[1] and type(groupData[1]) == 'table' then
			for p, preset in pairs(groupData) do
				for _, group in ipairs(preset) do
					if type(group) == 'table' then
						local gr = UnitDefNames[group[1]]
						if gr then
							presets[p][gr.id] = tonumber(group[2])
						else
							rejectedUnits[p][group[1]] = tonumber(group[2])
						end
					end
				end
			end
		end
	end
	unit2group = presets[currPreset]
	if GetGameFrame() > 0 then
		addAllUnits()
	end
end
