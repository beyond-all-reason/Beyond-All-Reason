local versionNum = '4.010'

function widget:GetInfo()
	return {
		name = "Auto Group",
		desc = "v" .. (versionNum) .. " Alt+0-9 sets autogroup# for selected unit type(s). Newly built units get added to group# equal to their autogroup#. Alt BACKQUOTE (~) remove units. Type '/luaui autogroup help' for help or view settings at: Settings/Interface/AutoGroup'.",
		author = "Licho",
		date = "Mar 23, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true  --loaded by default?
	}
end

include("keysym.h.lua")

---- CHANGELOG -----
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

local addall = true
local immediate = true
local persist = true
local verbose = true

local unit2group = {} -- list of unit types to group

local groupableBuildingTypes = { 'tacnuke', 'empmissile', 'napalmmissile', 'seismic' }
local groupableBuildings = {}
for _, v in ipairs(groupableBuildingTypes) do
	if UnitDefNames[v] then
		groupableBuildings[UnitDefNames[v].id] = true
	end
end

local unitShowGroup = {}
for udefID, def in ipairs(UnitDefs) do
	if not def.isFactory and (groupableBuildings[udefID] or not def.isBuilding) then
		unitShowGroup[udefID] = true
	end
end

local finiGroup = {}
local myTeam = Spring.GetMyTeamID()
local createdFrame = {}

local gameStarted

local SetUnitGroup = Spring.SetUnitGroup
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetMouseState = Spring.GetMouseState
local SelectUnitArray = Spring.SelectUnitArray
local TraceScreenRay = Spring.TraceScreenRay
local GetUnitPosition = Spring.GetUnitPosition
local GetGameFrame = Spring.GetGameFrame
local Echo = Spring.Echo


function widget:GameStart()
	gameStarted = true
	widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
		return
	end
	myTeam = Spring.GetMyTeamID()
end

local function ChangeUnitTypeAutogroupHandler(_, _, args, data)
	local gr = args[1]
	local removeAll = data and data['removeAll']

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
		if unitShowGroup[udid] then
			selUnitDefIDs[udid] = true
			unit2group[udid] = gr
			exec = true
			if gr == nil then
				SetUnitGroup(unitID, -1)
			else
				SetUnitGroup(unitID, gr)
			end
		end
	end
	if exec == false then
		return false --nothing to do
	end
	for udid, _ in pairs(selUnitDefIDs) do
		if verbose then
			if gr then
				Echo( Spring.I18N('ui.autogroups.unitAdded', { unit = UnitDefs[udid].humanName, groupNumber = gr }) )
			else
				Echo( Spring.I18N('ui.autogroups.unitRemoved', { unit = UnitDefs[udid].humanName }) )
			end
		end
	end
	if addall then
		local myUnits = Spring.GetTeamUnits(myTeam)
		for i = 1, #myUnits do
			local unitID = myUnits[i]
			local curUnitDefID = GetUnitDefID(unitID)
			if selUnitDefIDs[curUnitDefID] then
				if gr then
					local _, _, _, _, buildProgress = GetUnitHealth(unitID)
					if buildProgress == 1 then
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

local function RemoveOneUnitFromGroupHandler(_, _, args)
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

function widget:Initialize()
	widget:PlayerChanged()

	widgetHandler:AddAction("add_to_autogroup", ChangeUnitTypeAutogroupHandler, nil, "p") -- With a parameter, adds all units of this type to a specific autogroup
	widgetHandler:AddAction("remove_from_autogroup", ChangeUnitTypeAutogroupHandler, { removeAll = true }, "p") -- Without a parameter, removes all units of this type from autogroups
	widgetHandler:AddAction("remove_one_unit_from_group", RemoveOneUnitFromGroupHandler, nil, "p") -- Removes the closest of selected units from groups and selects only it

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
end

function widget:Shutdown()
	WG['autogroup'] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam and unitID ~= nil then
		if createdFrame[unitID] == GetGameFrame() then
			local gr = unit2group[unitDefID]
			if gr ~= nil then
				SetUnitGroup(unitID, gr)
			end
		else
			finiGroup[unitID] = 1
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam == myTeam then
		createdFrame[unitID] = GetGameFrame()
	end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam)
	if immediate or groupableBuildings[unitDefID] then
		if unitTeam == myTeam then
			createdFrame[unitID] = GetGameFrame()
			local gr = unit2group[unitDefID]
			if gr ~= nil then
				SetUnitGroup(unitID, gr)
			end
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	finiGroup[unitID] = nil
	createdFrame[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeamID, teamID)
	if newTeamID == myTeam then
		local gr = unit2group[unitDefID]
		if gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
	end
	createdFrame[unitID] = nil
	finiGroup[unitID] = nil
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
	if teamID == myTeam then
		local gr = unit2group[unitDefID]
		if gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
	end
	createdFrame[unitID] = nil
	finiGroup[unitID] = nil
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
	local groups = {}
	if persist then
		for id, gr in pairs(unit2group) do
			table.insert(groups, { UnitDefs[id].name, gr })
		end
	end
	local ret = {
		version = versionNum,
		groups = groups,
		immediate = immediate,
		persist = persist,
		verbose = verbose,
		addall = addall,
	}
	return ret
end

function widget:SetConfigData(data)
	if data and type(data) == 'table' and data.version and (data.version + 0) > 2.1 then
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
						unit2group[gr.id] = nam[2]
					end
				end
			end
		end
	end
end
