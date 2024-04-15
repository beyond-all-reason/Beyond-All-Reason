
function widget:GetInfo()
	return {
		name      = "Show Orders (RML)",
		desc      = "Hold shift+meta to show allied units orders",
		author    = "Hobo Joe",
		date      = "April 2024",
		version   = 1.0,
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end


local spGetModKeyState = Spring.GetModKeyState
local spDrawUnitCommands = Spring.DrawUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetSpecState = Spring.GetSpectatingState
local spGetAllUnits = Spring.GetAllUnits
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spGetTeamUnitsSorted = Spring.GetTeamUnitsSorted
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spWorldToScreenCoords	= Spring.WorldToScreenCoords
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitStates = Spring.GetUnitStates
local GaiaTeamID  = Spring.GetGaiaTeamID()
local myTeamID = Spring.GetMyTeamID()
local vsx, vsy = Spring.GetViewGeometry()

local document
local context
local dataModelHandle
local dataModel = {
	unitQueues = {},
}



local isFactory = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end
end


local function getBuildQueue(unitID)
	local uCmds = spGetFactoryCommands(unitID,-1)
	local queue = {}
	local prevId = 0
	local count = 0
	local currentId = 0
	for i, cmd in pairs(uCmds) do
		if cmd.id < 0 then -- is a build cmd
			if -cmd.id == prevId then
				queue[#queue].count = queue[#queue].count + 1
			else
				queue[#queue + 1] = {
					id = -cmd.id,
					count = 1
				}
			end
			prevId = -cmd.id

		end
	end
	Spring.Echo("factory queue", table.toString(queue))
	return queue
end


function widget:DrawScreen()
	local alt, control, meta, shift = spGetModKeyState()
	if not (shift and meta) then
		dataModelHandle.unitQueues = {}
		return
	end

	-- data format
	-- 	cons [
	-- 		unitPos (sx, sy)
	-- 		queue {
	--			unitDefID
	-- 			count
	--		}
	--	]
	--
	-- own team only for now
	local myUnits = spGetTeamUnitsSorted(myTeamID)
	local queues = {}
	for unitDefID, units in pairs(myUnits) do
		if type(units) == 'table' then
			if isFactory[unitDefID] then
				for count, unitID in pairs(units) do
					if count ~= 'n' then

						local builder = {}

						local x, y, z = Spring.GetUnitPosition(unitID)
						local sx, sy = Spring.WorldToScreenCoords(x, y, z)
						builder.sx = math.floor(sx)
						builder.sy = math.floor(vsy - sy)
						builder.queue = getBuildQueue(unitID)

						if #builder.queue > 0 then
							queues[#queues + 1] = builder
						end
					end
				end
			end
		end
	end
	dataModelHandle.unitQueues = queues
end


-------------------------------------------------------
--- Boilerplate
-------------------------------------------------------
function widget:Initialize()
	context = RmlUi.GetContext("shared")

	dataModelHandle = context:OpenDataModel("unit_queue_data", dataModel)

	document = context:LoadDocument("LuaUi/Widgets/rml_widget_assets/show_queue.rml", widget)
	document:ReloadStyleSheet()
	document:Show()
end


function widget:Shutdown()
	if document then
		document:Close()
	end
	if context then
		context:RemoveDataModel("unit_queue_data")
	end
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		document:Show()
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		document:Hide()
	end
end
