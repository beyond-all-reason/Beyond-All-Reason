local widget = widget

function widget:GetInfo()
	return {
		name = "Pregame builder selection",
		desc = "Selects the engine builder used for the pregame command queue",
		author = "BAR contributors",
		layer = 0,
		enabled = true,
	}
end

local playerID, teamID, proxyID
local refreshTime = 0
local previews, previewFrame = {}, -1
local substitution = VFS.Include("luaui/Include/blueprint_substitution/logic.lua")
local started = false
local replacedCommand, lastActiveCommand, pendingCommand
local removeAfterSelection = false

local function acknowledgeBuilder(unitID)
	if not unitID or not Spring.ValidUnitID(unitID) then
		return
	end
	local generation = Spring.GetUnitRulesParam(unitID, "pregame_generation")
	if generation then
		Spring.SendLuaRulesMsg("pregameQueueAck:" .. unitID .. ":" .. generation)
	end
end

function widget:Initialize()
	if Spring.GetSpectatingState() or not Game.allowPreGameCommands then
		widgetHandler:RemoveWidget()
		return
	end
	playerID, teamID = Spring.GetMyPlayerID(), Spring.GetMyTeamID()
	if Spring.GetGameFrame() > 0 then
		-- Reconnecting clients also need to acknowledge the queue they just loaded.
		acknowledgeBuilder(Spring.GetTeamRulesParam(teamID, "pregameQueueTarget_" .. playerID))
		widgetHandler:RemoveWidget()
		return
	end
	-- Quick Start needs build tuples; commands are always read from the engine.
	WG.pregameQueue = {
		getBuildQueue = function()
			local result = {}
			for _, command in ipairs(proxyID and Spring.GetUnitCommands(proxyID, -1) or {}) do
				local item = { -command.id, unpack(command.params) }
				item.commandOptions = command.options.coded
				item.quickStartGenerated = Spring.GetUnitRulesParam(proxyID, "pregame_generated_" .. command.tag) == 1
				result[#result + 1] = item
			end
			return result
		end,
		setBuildQueue = function(queue)
			if not proxyID then
				return
			end
			-- One synced update preserves metadata on the actual command tags, including shared teams.
			local commands = {}
			for _, item in ipairs(queue) do
				local params = {}
				for i = 2, #item do
					params[#params + 1] = item[i]
				end
				commands[#commands + 1] =
					{ -item[1], params, item.commandOptions or 0, item.quickStartGenerated == true }
			end
			Spring.SendLuaRulesMsg("pregameQueueSet:" .. Json.encode(commands))
		end,
		getBuildPositions = function()
			return Spring.GetDrawFrame() - previewFrame <= 1 and previews or {}
		end,
	}
end

local function selectBuilder(unitID)
	local _, command = Spring.GetActiveCommand()
	command = command or replacedCommand
	replacedCommand = nil
	Spring.SelectUnitArray({ unitID })
	proxyID = unitID
	if command and command < 0 then
		local side = substitution.getSideFromUnitName(UnitDefs[Spring.GetUnitDefID(unitID)].name)
		pendingCommand = -substitution.getEquivalentUnitDefID(-command, side)
	end
	acknowledgeBuilder(unitID)
end

function widget:Update(dt)
	-- Selection changes rebuild command descriptions later in the frame.
	if pendingCommand then
		local index = Spring.GetCmdDescIndex(pendingCommand)
		if index then
			Spring.SetActiveCommand(index)
		end
		pendingCommand = nil
	end
	if removeAfterSelection then
		widgetHandler:RemoveWidget()
		return
	end
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	teamID = Spring.GetMyTeamID()
	if started then
		local target = Spring.GetTeamRulesParam(teamID, "pregameQueueTarget_" .. playerID)
		if target and Spring.ValidUnitID(target) then
			selectBuilder(target)
			removeAfterSelection = true
		elseif Spring.GetGameFrame() > 2 then
			widgetHandler:RemoveWidget()
		end
		return
	end
	local currentProxy = Spring.GetTeamRulesParam(teamID, "pregameQueue_" .. playerID)
	if currentProxy and currentProxy >= 0 and Spring.ValidUnitID(currentProxy) then
		Spring.SetUnitCommandDrawStart(currentProxy, Spring.GetUnitRulesParam(currentProxy, "pregame_positioned") == 1)
	end
	if currentProxy and currentProxy >= 0 and currentProxy ~= proxyID and Spring.ValidUnitID(currentProxy) then
		selectBuilder(currentProxy)
	end
	refreshTime = refreshTime + dt
	if refreshTime < 0.5 then
		return
	end
	refreshTime = 0
	-- Coop start positions and faction choices are authoritative in synced Lua.
	Spring.SendLuaRulesMsg("pregameQueueRefresh")
end

function widget:ActiveCommandChanged(command)
	if command or (proxyID and Spring.ValidUnitID(proxyID) and not Spring.GetUnitIsDead(proxyID)) then
		lastActiveCommand = command
	end
end

function widget:UnitDestroyed(unitID)
	if unitID == proxyID then
		local _, command = Spring.GetActiveCommand()
		replacedCommand = command or lastActiveCommand
		proxyID = nil
	end
end

function widget:GameStart()
	started = true
end

function widget:DrawBuildSquare(unitDefID, x, z, facing)
	local frame = Spring.GetDrawFrame()
	if previewFrame ~= frame then
		previews, previewFrame = {}, frame
	end
	previews[#previews + 1] = { x = x, y = Spring.GetGroundHeight(x, z), z = z, facing = facing }
end

function widget:Shutdown()
	WG.pregameQueue = nil
end
