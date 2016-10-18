-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local versionNum = '2.22'

function widget:GetInfo()
  return {
    name      = "Auto group",
    desc      = "v".. (versionNum) .." Alt+0-9 sets autogroup# for selected unit type(s). Newly built units get added to group# equal to their autogroup#. Type '/luaui autogroup help' for help.",
	author    = "Licho",
    date      = "Mar 23, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

include("keysym.h.lua")

---- CHANGELOG -----
-- very_bad_solider, v2.22:
--		-- Ignores buildings and factories
--		-- Does not react when META (+ALT) is pressed
--	CarRepairer, v2:
--		-- Autogroups key is alt instead of alt+ctrl.
--		-- Added commands: help, loadgroups, cleargroups, verboseMode, addall

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local finiGroup = {}
local unit2group = {}
local myTeam
local selUnitDefs = {}
local loadGroups = false
local verboseMode = true
local addAll = false
local createdFrame = {}

local helpText = {
	'Alt+0-9 sets autogroup# for selected unit type(s). Newly built units get added to group# equal to their autogroup#.',
	'Alt+\~ deletes autogrouping for selected unit type(s).',
	'Ctrl+~ removes nearest selected unit from its group and selects it. ',
	'/luaui autogroup cleargroups -- Clears your autogroupings.',
	'/luaui autogroup loadgroups -- Toggles whether your groups are re-loaded for all future games.',
	'/luaui autogroup verbose -- Toggle whether a notification is made when adding/removing autogroups.',
	'/luaui autogroup addall -- Toggle whether existing units are added to group# when setting autogroup#.',
	--'Extra function: Ctrl+q picks single nearest unit from current selection.',
}
		

-- speedups
local SetUnitGroup 		= Spring.SetUnitGroup
local GetSelectedUnits 	= Spring.GetSelectedUnits
local GetUnitDefID 		= Spring.GetUnitDefID
local Echo 				= Spring.Echo
local GetAllUnits		= Spring.GetAllUnits
local GetUnitHealth		= Spring.GetUnitHealth
local GetMouseState		= Spring.GetMouseState
local GetUnitTeam		= Spring.GetUnitTeam
local SelectUnitArray	= Spring.SelectUnitArray
local TraceScreenRay	= Spring.TraceScreenRay
local GetUnitPosition	= Spring.GetUnitPosition
local UDefTab			= UnitDefs


function widget:Initialize() 
	local _, _, spec, team = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
	if spec then
		widgetHandler:RemoveWidget()
		return false
	end
  myTeam = team
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if (unitTeam == myTeam and unitID ~= nil) then
	if (createdFrame[unitID] == Spring.GetGameFrame()) then
		local gr = unit2group[unitDefID]
		if gr ~= nil then SetUnitGroup(unitID, gr) end
	else 
		finiGroup[unitID] = 1
	end
  end
end



function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID) 
	if (unitTeam == myTeam) then
		createdFrame[unitID] = Spring.GetGameFrame()
	end
end


function widget:UnitDestroyed(unitID, unitDefID, teamID)
  finiGroup[unitID] = nil
  createdFrame[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeamID, teamID)
  if (newTeamID == myTeam) then
    local gr = unit2group[unitDefID]
    if gr ~= nil then SetUnitGroup(unitID, gr) end
  end
  createdFrame[unitID] = nil
  finiGroup[unitID] = nil
end


function widget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
  if (teamID == myTeam) then
    local gr = unit2group[unitDefID]
    if gr ~= nil then SetUnitGroup(unitID, gr) end
  end
  createdFrame[unitID] = nil
  finiGroup[unitID] = nil
end


function widget:UnitIdle(unitID, unitDefID, unitTeam) 
  if (unitTeam == myTeam and finiGroup[unitID]~=nil) then
    local gr = unit2group[unitDefID]
    if gr ~= nil then SetUnitGroup(unitID, gr) end
    finiGroup[unitID] = nil
  end
end


function widget:KeyPress(key, modifier, isRepeat)
	if ( modifier.alt and not modifier.meta ) then
		local gr
		if (key == KEYSYMS.N_0) then gr = 0 end
		if (key == KEYSYMS.N_1) then gr = 1 end
		if (key == KEYSYMS.N_2) then gr = 2 end 
		if (key == KEYSYMS.N_3) then gr = 3 end
		if (key == KEYSYMS.N_4) then gr = 4 end
		if (key == KEYSYMS.N_5) then gr = 5 end
		if (key == KEYSYMS.N_6) then gr = 6 end
		if (key == KEYSYMS.N_7) then gr = 7 end
		if (key == KEYSYMS.N_8) then gr = 8 end
		if (key == KEYSYMS.N_9) then gr = 9 end
 		if (key == KEYSYMS.BACKQUOTE) then gr = -1 end
		if (gr ~= nil) then
				if (gr == -1) then gr = nil end
				selUnitDefIDs = {}
				local exec = false --set to true when there is at least one unit to process
				for _, uid in ipairs(GetSelectedUnits()) do
					local udid = GetUnitDefID(uid)
					if ( not UDefTab[udid]["isFactory"] and not UDefTab[udid]["isBuilding"] ) then
						selUnitDefIDs[udid] = true
						unit2group[udid] = gr
						exec = true
					end
				end
				
				if ( exec == false ) then
					return false --nothing to do
				end
				
				for udid,_ in pairs(selUnitDefIDs) do
					if verboseMode then
						if gr then
							Echo('Added '..  UnitDefs[udid].humanName ..' to autogroup #'.. gr ..'.')
						else
							Echo('Removed '..  UnitDefs[udid].humanName ..' from autogroups.')
						end
					end
				end
					
				if addAll then
					local allUnits = GetAllUnits()
					for _, unitID in pairs(allUnits) do
						local unitTeam = GetUnitTeam(unitID)
						if unitTeam == myTeam then
							local curUnitDefID = GetUnitDefID(unitID)
							if selUnitDefIDs[curUnitDefID] then
								if gr         then
									local _, _, _, _, buildProgress = GetUnitHealth(unitID)
									if buildProgress == 1 then
										SetUnitGroup(unitID, gr)
										SelectUnitArray({unitID}, true)
									end
								else
									SetUnitGroup(unitID, -1)
								end
							end
						end
					end
				end
				
				return true 	--key was processed by widget
			end
	elseif (modifier.ctrl and not modifier.meta) then	
		if (key == KEYSYMS.BACKQUOTE) then
		  local mx,my = GetMouseState()
		  local _,pos = TraceScreenRay(mx,my,true)     
		  local mindist = math.huge
		  local muid = nil
		  if (pos == nil) then return end
		  for _, uid in ipairs(GetSelectedUnits()) do  
			local x,_,z = GetUnitPosition(uid)
			dist = (pos[1]-x)*(pos[1]-x) + (pos[3]-z)*(pos[3]-z)
			if (dist < mindist) then
			  mindist = dist
			  muid = uid
			end
				end
		  if (muid ~= nil) then
		  
			SetUnitGroup(muid,-1)
			SelectUnitArray({muid})
		  end
		end
		--[[
		if (key == KEYSYMS.Q) then
		  for _, uid in ipairs(GetSelectedUnits()) do  
			SetUnitGroup(uid,-1)
		  end
		end
		--]]
	end
	
	return false
end


function widget:GetConfigData()
  local groups = {}
  for id, gr in pairs(unit2group) do 
    table.insert(groups, {UnitDefs[id].name, gr})
  end 
  local ret = 
  {
	  version 		= versionNum,
	  groups 		= groups,
	  loadGroups 	= loadGroups,
	  verboseMode	= verboseMode,
	  addAll		= addAll,
  }
  return ret
end
	
function widget:SetConfigData(data)
	if (data and type(data) == 'table' and data.version and (data.version+0) > 2.1) then
	loadGroups 	= data.loadGroups
	verbose 	= data.verboseMode
	addAll	 	= data.addAll
	local groupData = data.groups
	if loadGroups and groupData and type(groupData) == 'table' then
		for _, nam in ipairs(groupData) do
		  if type(nam) == 'table' then
			  local gr = UnitDefNames[nam[1]]
			  if (gr ~= nil) then
				unit2group[gr.id] = nam[2]
			  end
		  end
		end
	end
	
	
  else --older ver
	--[[
    if (data ~= nil) then
	    for _, nam in ipairs(data) do
	      local gr = UnitDefNames[nam[1] ]
	      if (gr ~= nil) then
	        unit2group[gr.id] = nam[2]
	      end
	    end
	end
	--]]
	
  end

end

function widget:TextCommand(command)
	if command == "autogroup loadgroups" then
		loadGroups = not loadGroups
		Echo('Autogroup: your autogroups will '.. (loadGroups and '' or 'NOT') ..' be preserved for future games') 
		return true
	elseif command == "autogroup cleargroups" then
		unit2group = {}
		Echo('Autogroup: All autogroups cleared.')
		return true
	elseif command == "autogroup verbose" then
		verboseMode = not verboseMode 
		Echo('Autogroup: verbose mode '.. (verboseMode and 'ON' or 'OFF') ..'.')
		return true
	elseif command == "autogroup addall" then
		addAll = not addAll
		Echo('Autogroup: Existing units will '.. (addAll and '' or 'NOT') ..' be added to group# when setting autogroup#.')
		return true
	elseif command == "autogroup help" then
		for i, text in ipairs(helpText) do
			Echo('['.. i ..'] Autogroup: '.. text)
		end
		return true
	end
	return false
end   

--------------------------------------------------------------------------------
