function widget:GetInfo()
	return {
		name = "Idle Builders (RMLUI)",
		desc = "Interface to display idle builders",
		author = "Hobo Joe",
		date = "March 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true
	}
end


local spGetMouseState = Spring.GetMouseState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetFullBuildQueue = Spring.GetFullBuildQueue
local spGetUnitHealth = Spring.GetUnitHealth
local spGetCommandQueue = Spring.GetCommandQueue
local spGetTeamUnitsSorted = Spring.GetTeamUnitsSorted
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local myTeamID = Spring.GetMyTeamID()
local spec = Spring.GetSpectatingState()
local vsx, vsy = Spring.GetViewGeometry()

local document
local context

--- Config variables
local showWhenSpec = false
local soundVolume = 0.5
local maxGroups = 9
local showRez = true
local nearIdle = 0 -- this means that factories with only X build items left will be shown as idle
local idleList = {}

-- Cache unit types that show up in this widget
local isBuilder = {}
local isFactory = {}
local isResurrector = {}
local unitHumanName = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1]) and not unitDef.customParams.isairbase then
		isBuilder[unitDefID] = true
	end
	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end
	if unitDef.canResurrect then
		isResurrector[unitDefID] = true
	end
	if unitDef.translatedHumanName then
		unitHumanName[unitDefID] = unitDef.translatedHumanName
	end
end


local function selectBuilderType(event, unitDefID)
	local mx,my = Spring.GetMouseState()
	local t, center = Spring.TraceScreenRay(math.floor(vsx / 2), math.floor(vsy / 2), true)
	if idleList[unitDefID] then
		local udef = idleList[unitDefID]
		local nearest = math.huge
		local nearestIndex = 0
		for i = 1, #udef do
			local x,y,z = Spring.GetUnitPosition(udef[i])
			local dist = math.distance2dSquared(center[1], center[3], x, z)
			if dist < nearest then
				nearest = dist
				nearestIndex = i
			end
		end
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		Spring.SelectUnitArray({udef[nearestIndex]}, shift)
	end
end


-- When updating the data model, update the handler instead of the original table
local dataModelHandle
-- Data model format
local dataModel = {
	selectBuilderType = selectBuilderType,
	idleUnitTypes = {},
	count = 0,
}


---Returns true if the unit is a builder and is currently idle
---@param unitID number
local function isIdleBuilder(unitID)
	local udef = spGetUnitDefID(unitID)
	if isBuilder[udef] or (showRez and isResurrector[udef]) then
		--- can build
		local buildQueue = spGetFullBuildQueue(unitID)
		if not buildQueue[1] then
			--- has no build queue
			local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
			if buildProgress == 1 then
				--- isnt under construction
				if isFactory[udef] then
					return true
				elseif (spGetCommandQueue(unitID, 0) == 0) and not(spGetUnitMoveTypeData(unitID).aircraftState == "crashing") then
					return true
				end
			end
		elseif isFactory[udef] then
			if #buildQueue == 0 then
				return true
			end
		end
	end
	return false
end


local function updateList()
	idleList = {}
	local myUnits = spGetTeamUnitsSorted(myTeamID)
	for unitDefID, units in pairs(myUnits) do
		if type(units) == 'table' then
			for count, unitID in pairs(units) do
				if count ~= 'n' and isIdleBuilder(unitID) then
					if idleList[unitDefID] then
						idleList[unitDefID][#idleList[unitDefID] + 1] = unitID
					else
						idleList[unitDefID] = { unitID }
					end
				end
			end
		end
	end

	local uiList = {}
	for unitDefID, units in pairs(idleList) do
		local type = {}
		type.unitDefID = unitDefID
		type.count = #units
		uiList[#uiList + 1] = type
		if #uiList >= maxGroups then
			break
		end
	end

	dataModelHandle.idleUnitTypes = uiList
	dataModelHandle.count = #uiList
end


local sec = 0
local doUpdate = true
local timerStart = Spring.GetTimer()
function widget:Update()
	if Spring.GetGameFrame() <= 0 then return end
	if not (not spec or showWhenSpec) then
		return
	end

	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end
	local now = Spring.GetTimer()
	local dt = Spring.DiffTimers(now, timerStart)
	timerStart = now

	doUpdate = false
	sec = sec + dt

	if sec > 0.05 then
		sec = 0
		doUpdate = true
	end

	if doUpdate then
		updateList()
	end
end


-------------------------------------------------------
--- Boilerplate
-------------------------------------------------------
function widget:Initialize()
	context = RmlUi.GetContext("shared")

	dataModelHandle = context:OpenDataModel("idle_unit_data", dataModel)

	document = context:LoadDocument("LuaUi/Widgets/rml_widget_assets/idle_builders.rml", widget)
	document:ReloadStyleSheet()
	document:Show()
end


function widget:Shutdown()
	if document then
		document:Close()
	end
	if context then
		context:RemoveDataModel("idle_unit_data")
	end
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		document:Show()
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		document:Hide()
	end
end
