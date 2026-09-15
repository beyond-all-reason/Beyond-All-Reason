local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scripted pause",
		desc = "Lets gadgets pause the game in a way players cannot undo",
		date = "2026.09.08",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[
	API (synced):
		GG.ScriptedPause.Pause()
		GG.ScriptedPause.Unpause()
		GG.ScriptedPause.IsPaused() -> boolean

	The game rules param "scriptedPause" is 1 while a scripted pause is active,
	so widgets can tell it apart from player, host and server pauses.

	Implementation notes:
	Synced code cannot pause the game; only a client can, by sending NETMSG_PAUSE
	through Spring.SendCommands("pause"). The synced side therefore records the
	state and asks the unsynced side to send the command. Only one client (the
	"pause controller": the lowest-numbered active, non-spectating player) sends
	it, so the server gets a single request instead of one per client.

	Players cannot undo the pause: whenever the game gets unpaused while a
	scripted pause is active, the controller pauses it again. A frame or two can
	slip through before the re-pause round-trips, which is acceptable.
	Spring.SetNoPause is deliberately not used: the server exempts the local
	(host) player from it, so it would not stop the singleplayer host, and on a
	dedicated server it would also block the controller's own pause requests.
]]

local RULES_PARAM = "scriptedPause"
local SYNC_ACTION = "ScriptedPause"

if gadgetHandler:IsSyncedCode() then
	local spSetGameRulesParam = Spring.SetGameRulesParam

	local scriptedPause = false

	GG.ScriptedPause = {}

	function GG.ScriptedPause.Pause()
		if scriptedPause then
			return
		end
		scriptedPause = true
		spSetGameRulesParam(RULES_PARAM, 1)
		SendToUnsynced(SYNC_ACTION, true)
	end

	function GG.ScriptedPause.Unpause()
		if not scriptedPause then
			return
		end
		scriptedPause = false
		spSetGameRulesParam(RULES_PARAM, 0)
		SendToUnsynced(SYNC_ACTION, false)
	end

	function GG.ScriptedPause.IsPaused()
		return scriptedPause
	end

	function gadget:Initialize()
		-- also drops a scripted pause across /luarules reload: the game then stays
		-- paused as a plain pause, which the player can undo
		spSetGameRulesParam(RULES_PARAM, 0)
	end

	function gadget:Shutdown()
		GG.ScriptedPause = nil
	end
else
	local spGetGameSpeed = Spring.GetGameSpeed
	local spGetGameRulesParam = Spring.GetGameRulesParam
	local spGetPlayerList = Spring.GetPlayerList
	local spGetPlayerInfo = Spring.GetPlayerInfo
	local spGetMyPlayerID = Spring.GetMyPlayerID
	local spSendCommands = Spring.SendCommands

	local scriptedPause = false

	-- The lowest-numbered active, non-spectating player. Falls back to the
	-- lowest-numbered active player when everybody spectates (the server only
	-- accepts a spectator's pause when they host, which covers watching a
	-- singleplayer mission).
	local function isPauseController()
		local playerIDs = spGetPlayerList(true)
		if not playerIDs or #playerIDs == 0 then
			return false
		end
		local myPlayerID = spGetMyPlayerID()
		for i = 1, #playerIDs do
			local playerID = playerIDs[i]
			local _, active, spectator = spGetPlayerInfo(playerID, false)
			if active and not spectator then
				return playerID == myPlayerID
			end
		end
		return playerIDs[1] == myPlayerID
	end

	local function setGamePaused(paused)
		if not isPauseController() then
			return
		end
		local _, _, isPaused = spGetGameSpeed()
		if isPaused ~= paused then
			spSendCommands(paused and "pause 1" or "pause 0")
		end
	end

	local function onScriptedPause(_, paused)
		scriptedPause = paused
		setGamePaused(paused)
	end

	function gadget:GamePaused(playerID, isPaused)
		if scriptedPause and not isPaused then
			setGamePaused(true)
		end
	end

	function gadget:Initialize()
		scriptedPause = (spGetGameRulesParam(RULES_PARAM) or 0) == 1
		gadgetHandler:AddSyncAction(SYNC_ACTION, onScriptedPause)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	end
end
