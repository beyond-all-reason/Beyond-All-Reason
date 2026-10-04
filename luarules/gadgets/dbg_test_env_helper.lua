local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Test Environment Helper",
		desc = "Helper to setup test environment conditions",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		handler = true,
		enabled = true,
	}
end

local ENABLED_RULES_PARAM = 'isTestEnvironmentHelperEnabled'

if not Spring.Utilities.IsDevMode() or not Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

if gadgetHandler:IsSyncedCode() then

	local removeGadgets = {'Team Com Ends', 'Game End'}

	Spring.SetGameRulesParam(ENABLED_RULES_PARAM, true)

	local function SetTestEndConditionsCmd(cmd, line, words, playerID)
		if not Spring.IsCheatingEnabled() then
			return
		end
		for _, gadgetName in pairs(removeGadgets) do
			local g = gadgetHandler:FindGadget(gadgetName)
			gadgetHandler:RemoveGadget(g)
		end

		Spring.SetGameRulesParam("testEndConditionsOverride", true)
	end

	local function SetTestReadyPlayersCmd(cmd, line, words, playerID)
		if not Spring.IsCheatingEnabled() then
			return
		end
		local playerList = Spring.GetPlayerList()
		for _, playerID in pairs(playerList) do
			Spring.SetGameRulesParam("player_" .. playerID .. "_readyState", 1)
		end
	end

	function gadget:Initialize()
		gadgetHandler.actionHandler.AddChatAction(gadget, 'setTestEndConditions', SetTestEndConditionsCmd)
		gadgetHandler.actionHandler.AddChatAction(gadget, 'setTestReadyPlayers', SetTestReadyPlayersCmd)
		if Spring.GetGameRulesParam("testEndConditionsOverride") then
			SetTestEndConditionsCmd()
		end
	end

	function gadget:Shutdown()
		gadgetHandler.actionHandler.RemoveChatAction(gadget, 'setTestEndConditions')
		gadgetHandler.actionHandler.RemoveChatAction(gadget, 'setTestReadyPlayers')
		Spring.SetGameRulesParam(ENABLED_RULES_PARAM, false)
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg == 'testEnvironmentStarting' then
			Spring.SetGameRulesParam('testEnvironmentStarting', true)
			gadgetHandler:RemoveGadgetCallIn('RecvLuaMsg', self)
		end
	end
else
	-- taken from gui_pregameui.lua, check there for more information
	local NETMSG_STARTPLAYING = 4
	local SYSTEM_ID = -1

	function gadget:Update(n)
		if (Spring.GetPlayerTraffic(SYSTEM_ID, NETMSG_STARTPLAYING) or 0) > 0 then
			Spring.SendLuaRulesMsg('testEnvironmentStarting')
			gadgetHandler:RemoveGadget(self)
		end
	end
end
