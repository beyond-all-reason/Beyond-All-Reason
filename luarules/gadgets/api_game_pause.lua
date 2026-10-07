local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Game Pause",
		desc = "Handle multiple pause sources and unpause attempts from within synced code",
		date = "2026-10",
		license = "GNU GPL, v2 or later",
		author = "efrec",
		layer = 0,
		enabled = true,
	}
end

--[[
	Provides the synced API:
		GG.GamePause.Pause(source, publish)
		GG.GamePause.Unpause(source)

	Pausing twice from one source pauses once. A source added with publish=true
	can also be unpaused from widgets, with `widgetHandler:Unpause(source)`.

	Game rulesparams (for widgets):
		"gamePaused"          `1` while any gadget source holds the game, so widgets can tell
		                      it apart from player, host, and server pauses. Lots of pausing.
		"gamePausePublished"  a JSON array of the publish sources

	Implementation notes:
	Only a client can pause, by sending NETMSG_PAUSE through Spring.SendCommands("pause").
	The synced code only records the sources and asks the unsynced side to send the command.
	
	Only one client (the pause controller, see include/pause_controller.lua) sends a command,
	so the server gets a single request instead of one per client. Other clients are ignored.

	This code risks completely bricking a game as a result. Be cautious e.g. with disconnects.
]]

local RULESPARAM_PAUSED = "gamePaused"
local RULESPARAM_PUBLISH = "gamePausePublished"
local SYNCACTION = "GamePause"
local MESSAGE_UNPAUSE = SYNCACTION .. "Unpause:"

local getPauseControllerID = VFS.Include("luarules/gadgets/include/pause_controller.lua").GetPauseControllerID

if gadgetHandler:IsSyncedCode() then
	local spSetGameRulesParam = Spring.SetGameRulesParam

	local pauseSources = {} -- source -> published

	local function publishSources()
		local published = {}
		for source, publish in pairs(pauseSources) do
			if publish then
				published[#published + 1] = source
			end
		end
		table.sort(published)
		spSetGameRulesParam(RULESPARAM_PUBLISH, Json.encode(published))
	end

	local function pause(source, publish)
		if next(pauseSources) == nil then
			spSetGameRulesParam(RULESPARAM_PAUSED, 1)
			SendToUnsynced(SYNCACTION, true)
		end
		pauseSources[source] = publish == true
		publishSources()
	end

	local function unpause(source)
		if pauseSources[source] == nil then
			return
		end
		pauseSources[source] = nil
		publishSources()
		if next(pauseSources) == nil then
			spSetGameRulesParam(RULESPARAM_PAUSED, 0)
			SendToUnsynced(SYNCACTION, false)
		end
	end

	GG.GamePause = {
		Pause = pause,
		Unpause = unpause,
	}

	function gadget:RecvLuaMsg(message, playerID)
		if message:sub(1, #MESSAGE_UNPAUSE) ~= MESSAGE_UNPAUSE then
			return
		end
		local source = message:sub(#MESSAGE_UNPAUSE + 1)
		if playerID == getPauseControllerID() and pauseSources[source] == true then
			unpause(source)
		end
		return true -- consume
	end

	function gadget:Initialize()
		-- TODO: Are there pauses that should survive a resume? reload? luarules reload?
		spSetGameRulesParam(RULESPARAM_PAUSED, 0)
		spSetGameRulesParam(RULESPARAM_PUBLISH, "[]")
	end

	function gadget:Shutdown()
		GG.GamePause = nil
	end
else
	local spGetGameSpeed = Spring.GetGameSpeed
	local spGetGameRulesParam = Spring.GetGameRulesParam
	local spGetMyPlayerID = Spring.GetMyPlayerID
	local spSendCommands = Spring.SendCommands

	local gadgetPaused = false
	local gadgetResumePending = false -- unpaused by gadgets, but the game has not resumed yet

	local function setGamePaused(paused)
		if getPauseControllerID() ~= spGetMyPlayerID() then
			return
		end
		local _, _, isPaused = spGetGameSpeed()
		if isPaused == paused then
			return
		end
		if not paused and Script.LuaUI("GameUnpausing") and Script.LuaUI.GameUnpausing() then
			return -- widgets can pause and resume the game
		end
		spSendCommands(paused and "pause 1" or "pause 0")
	end

	local function onGamePause(_, paused)
		gadgetPaused = paused
		gadgetResumePending = not paused
		setGamePaused(paused)
	end

	function gadget:GamePaused(playerID, isPaused)
		gadgetResumePending = false
		if gadgetPaused and not isPaused then
			setGamePaused(true)
		end
	end

	local function onPlayersChanged()
		-- The next pause controller takes over pending requests.
		if gadgetPaused or gadgetResumePending then
			setGamePaused(gadgetPaused)
		end
	end

	function gadget:PlayerChanged()
		onPlayersChanged()
	end

	function gadget:PlayerRemoved()
		onPlayersChanged()
	end

	function gadget:Initialize()
		gadgetPaused = (spGetGameRulesParam(RULESPARAM_PAUSED) or 0) == 1
		gadgetHandler:AddSyncAction(SYNCACTION, onGamePause)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNCACTION)
	end
end
