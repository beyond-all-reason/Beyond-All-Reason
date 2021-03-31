local versionNum = '4.000'

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
local immediate = false
local verbose = true

local cutoffDistance = 3500
local falloffDistance = 2500

local debug = false --of true generates debug messages

local vsx, vsy = Spring.GetViewGeometry()

local unit2group = {} -- list of unit types to group

local groupableBuildingTypes = { 'tacnuke', 'empmissile', 'napalmmissile', 'seismic' }

local groupableBuildings = {}
for _, v in ipairs(groupableBuildingTypes) do
	if UnitDefNames[v] then
		groupableBuildings[UnitDefNames[v].id] = true
	end
end

local finiGroup = {}
local myTeam = Spring.GetMyTeamID()
local createdFrame = {}
local textSize = 13

local font, dlists, gameStarted, chobbyInterface

-- gr = groupe selected/wanted

-- speedups
local SetUnitGroup = Spring.SetUnitGroup
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitHealth = Spring.GetUnitHealth
local GetMouseState = Spring.GetMouseState
local SelectUnitArray = Spring.SelectUnitArray
local TraceScreenRay = Spring.TraceScreenRay
local GetUnitPosition = Spring.GetUnitPosition
local UDefTab = UnitDefs
local GetGroupList = Spring.GetGroupList
local GetGroupUnits = Spring.GetGroupUnits
local GetGameFrame = Spring.GetGameFrame
local IsGuiHidden = Spring.IsGUIHidden
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetCameraPosition = Spring.GetCameraPosition
local Echo = Spring.Echo
local diag = math.diag
local min = math.min

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	font = WG['fonts'].getFont(nil, 1.4, 0.35, 1.4)

	if dlists then
		for i, _ in ipairs(dlists) do
			gl.DeleteList(dlists[i])
		end
	end
	dlists = {}
	for i = 0, 9 do
		dlists[i] = gl.CreateList(function()
			font:Begin()
			font:Print("\255\200\255\200" .. i, 20.0, -10.0, textSize, "cno")
			font:End()
		end)
	end
end

function widget:GameStart()
	gameStarted = true
	widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget(self)
		return
	end
	myTeam = Spring.GetMyTeamID()
end

function widget:Initialize()
	widget:ViewResize()
	widget:PlayerChanged()

	WG['autogroup'] = {}
	WG['autogroup'].getImmediate = function()
		return immediate
	end
	WG['autogroup'].setImmediate = function(value)
		immediate = value
	end
end

function widget:Shutdown()
	WG['autogroup'] = nil
	if dlists then
		for i, _ in ipairs(dlists) do
			gl.DeleteList(dlists[i])
		end
		dlists = {}
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then
		return
	end
	if not IsGuiHidden() then
		local existingGroups = GetGroupList()
		local camX, camY, camZ = spGetCameraPosition()
		local camDistance
		for inGroup, _ in pairs(existingGroups) do
			local units = GetGroupUnits(inGroup)
			for i = 1, #units do
				local unitID = units[i]
				if spIsUnitInView(unitID) then
					local ux, uy, uz = spGetUnitViewPosition(unitID)
					local camDistance = diag(camX - ux, camY - uy, camZ - uz)
					if camDistance < cutoffDistance then
						local scale = min(1, 1 - (camDistance - falloffDistance) / cutoffDistance)
						gl.PushMatrix()
						gl.Translate(ux, uy, uz)
						if scale <=1 then
							gl.Scale(scale, scale, scale)
						end
						gl.Billboard()
						gl.CallList(dlists[inGroup])
						gl.PopMatrix()
					end
				end
			end
		end
	end
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
		if gr ~= nil then
			SetUnitGroup(unitID, gr)
		end
		finiGroup[unitID] = nil
	end
end

function widget:KeyPress(key, modifier, isRepeat)
	if modifier.alt and not modifier.meta then
		local gr
		if key == KEYSYMS.N_0 then
			gr = 0
		end
		if key == KEYSYMS.N_1 then
			gr = 1
		end
		if key == KEYSYMS.N_2 then
			gr = 2
		end
		if key == KEYSYMS.N_3 then
			gr = 3
		end
		if key == KEYSYMS.N_4 then
			gr = 4
		end
		if key == KEYSYMS.N_5 then
			gr = 5
		end
		if key == KEYSYMS.N_6 then
			gr = 6
		end
		if key == KEYSYMS.N_7 then
			gr = 7
		end
		if key == KEYSYMS.N_8 then
			gr = 8
		end
		if key == KEYSYMS.N_9 then
			gr = 9
		end
		if key == KEYSYMS.BACKQUOTE then
			gr = -1
		end
		if gr ~= nil then
			if gr == -1 then
				gr = nil
			end
			local selUnitDefIDs = {}
			local unit2groupDeleted = {}
			local exec = false --set to true when there is at least one unit to process
			local units = GetSelectedUnits()
			for i = 1, #units do
				local unitID = units[i]
				local udid = GetUnitDefID(unitID)
				if not UDefTab[udid]["isFactory"] and (groupableBuildings[udid] or not UDefTab[udid]["isBuilding"]) then
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
						Echo('Added ' .. UnitDefs[udid].humanName .. ' to autogroup #' .. gr .. '.')
					else
						Echo('Removed ' .. UnitDefs[udid].humanName .. ' from autogroups.')
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
			return true    --key was processed by widget
		end

	elseif modifier.ctrl and not modifier.meta then
		if key == KEYSYMS.BACKQUOTE then
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
		end
	end
	return false
end

function widget:GetConfigData()
	local groups = {}
	for id, gr in pairs(unit2group) do
		table.insert(groups, { UnitDefs[id].name, gr })
	end
	local ret = {
		version = versionNum,
		groups = groups,
		immediate = immediate,
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
