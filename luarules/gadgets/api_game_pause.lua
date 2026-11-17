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
		"gamePauseGeneration" the generation of the gadget pause in progress
		"gamePausePublished"  a JSON array of [source, generation] for unpausing named sources

	Each pause gets a new generation, which widgets send back with an unpause, so a late
	message can never release a later pause. Any active player can send one.

	Implementation notes:
	Only a client can pause, by sending NETMSG_PAUSE through Spring.SendCommands("pause").
	The synced code only records the sources and asks the unsynced side to send the command.
	
	Only one client (the host-controller player's, see playerFunctions.lua) sends a command,
	so the server gets a single request instead of one per client. Other clients are ignored.

	This code risks completely bricking a game as a result. Be cautious e.g. with disconnects.
]]

local RULESPARAM_PAUSED = "gamePaused"
local RULESPARAM_GENERATION = "gamePauseGeneration"
local RULESPARAM_PUBLISH = "gamePausePublished"
local SYNCACTION = "GamePause"
local MESSAGE_UNPAUSE = SYNCACTION .. "Unpause:"
local MESSAGE_WIDGETS_UNPAUSED = SYNCACTION .. "WidgetsUnpaused"

local getPauseControllerID = BAR.Utilities.GetHostCommandPlayerID

if gadgetHandler:IsSyncedCode() then
	local spSetGameRulesParam = Spring.SetGameRulesParam
	local spGetPlayerInfo = Spring.GetPlayerInfo

	local pauseSources = {} ---@type table<string, { generation: integer, publish: boolean }>
	local generation = 0
	local pausedGeneration = 0 -- first generation that began the current gadget paus

	local function publishSources()
		local published = {}
		for source, data in pairs(pauseSources) do
			if data.publish then
				published[#published + 1] = { source, data.generation }
			end
		end
		table.sort(published, function(a, b)
			return a[1] < b[1]
		end)
		spSetGameRulesParam(RULESPARAM_PUBLISH, Json.encode(published))
	end

	local function pause(source, publish)
		local held = pauseSources[source]
		if held then
			held.publish = publish == true
		else
			generation = generation + 1
			if next(pauseSources) == nil then
				pausedGeneration = generation -- start of a new paused gen
				spSetGameRulesParam(RULESPARAM_GENERATION, pausedGeneration)
				spSetGameRulesParam(RULESPARAM_PAUSED, 1)
				SendToUnsynced(SYNCACTION, true)
			end
			pauseSources[source] = { generation = generation, publish = publish == true }
		end
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

	-- A spectator can only release a pause by hosting a game with no players.
	local function canRelease(playerID)
		local _, active, spectator = spGetPlayerInfo(playerID, false)
		return (active and not spectator) or playerID == getPauseControllerID()
	end

	function gadget:RecvLuaMsg(message, playerID)
		if message:sub(1, #MESSAGE_WIDGETS_UNPAUSED) == MESSAGE_WIDGETS_UNPAUSED then
			local messageGeneration = tonumber(message:sub(#MESSAGE_WIDGETS_UNPAUSED + 2))
			if next(pauseSources) ~= nil and messageGeneration == pausedGeneration and canRelease(playerID) then
				SendToUnsynced(MESSAGE_WIDGETS_UNPAUSED)
			end
			return true
		end
		if message:sub(1, #MESSAGE_UNPAUSE) ~= MESSAGE_UNPAUSE then
			return
		end
		local generationText, source = message:match("^(%d+):(.*)$", #MESSAGE_UNPAUSE + 1)
		local held = source and pauseSources[source]
		if held and held.publish and held.generation == tonumber(generationText) and canRelease(playerID) then
			unpause(source)
		end
		return true -- consume
	end

	function gadget:Initialize()
		-- TODO: Are there pauses that should survive a resume? reload? luarules reload?
		spSetGameRulesParam(RULESPARAM_PAUSED, 0)
		spSetGameRulesParam(RULESPARAM_GENERATION, 0)
		spSetGameRulesParam(RULESPARAM_PUBLISH, "[]")
	end

	function gadget:Shutdown()
		GG.GamePause = nil
	end
else
	local spGetGameFrame = Spring.GetGameFrame
	local spGetGameSpeed = Spring.GetGameSpeed
	local spGetGameRulesParam = Spring.GetGameRulesParam
	local spGetMyPlayerID = Spring.GetMyPlayerID
	local spSendCommands = Spring.SendCommands

	local CATCH_UP_FRAMES = 11 * Game.gameSpeed -- same as gui_rejoinprogress.lua
	local CONTROLLER_CHECK_SECONDS = 1.0

	local pausedByGadget = false
	local gadgetResumePending = false -- unpaused by gadgets, but the game has not resumed yet
	local pausedByPlayer = false ---@type boolean a player had paused when the gadgets paused, and has not unpaused since
	local sentPaused -- the controller's last command, until the server echoes it back
	local serverFrame -- the live game frame, while this client replays a backlog
	local catchingUp = false
	local controllerID -- as of the last check, to hand pending requests to the next one
	local controllerCheckTimer = 0.0

	local function setGamePaused(paused)
		if catchingUp or getPauseControllerID() ~= spGetMyPlayerID() then
			return
		end
		local isPaused = sentPaused
		if isPaused == nil then
			isPaused = select(3, spGetGameSpeed())
		end
		if isPaused == paused then
			return
		end
		if not paused and Script.LuaUI("GameUnpausing") and Script.LuaUI.GameUnpausing() then
			return -- the widgets still hold their own pause, and they resume the game when they release it
		end
		sentPaused = paused
		spSendCommands(paused and "pause 1" or "pause 0")
	end

	local function onGamePause(_, paused)
		if paused then
			pausedByPlayer = select(3, spGetGameSpeed()) and not gadgetResumePending
		end
		pausedByGadget = paused
		gadgetResumePending = not paused and not pausedByPlayer
		if paused or gadgetResumePending then
			setGamePaused(paused)
		end
	end

	-- Widgets leave the game paused for the gadgets to resume.
	local function onWidgetsUnpaused()
		pausedByPlayer = false
	end

	function gadget:GamePaused(playerID, isPaused)
		if playerID == spGetMyPlayerID() and isPaused == sentPaused then
			sentPaused = nil
		end
		-- A pause from the controller can be its own request arriving late, so it leaves the gadgets' resume pending.
		if not isPaused or playerID ~= getPauseControllerID() then
			gadgetResumePending = false
		end
		if not isPaused then
			pausedByPlayer = false
		end
		if pausedByGadget and not isPaused then
			setGamePaused(true)
		end
	end

	local function applyPendingPause()
		-- The next pause controller takes over pending requests, as does one that caught up.
		if pausedByGadget or gadgetResumePending then
			setGamePaused(pausedByGadget)
		end
	end

	function gadget:PlayerChanged()
		applyPendingPause()
	end

	function gadget:PlayerRemoved()
		applyPendingPause()
	end

	function gadget:Update(deltaTime)
		-- The host controller changes whenever a client starts/stops lagging, so we poll.
		controllerCheckTimer = controllerCheckTimer - deltaTime
		if controllerCheckTimer > 0.0 then
			return
		end
		controllerCheckTimer = CONTROLLER_CHECK_SECONDS
		local currentID = getPauseControllerID()
		if currentID ~= controllerID then
			controllerID = currentID
			applyPendingPause()
		end
	end

	-- A client replaying a backlog would send its pauses to the live game.
	function gadget:GameProgress(serverFrameNum)
		serverFrame = serverFrameNum
		if spGetGameFrame() < serverFrame - CATCH_UP_FRAMES then
			catchingUp = true
		end
	end

	function gadget:GameFrame(frame)
		if catchingUp and frame >= serverFrame - CATCH_UP_FRAMES then
			catchingUp = false
			applyPendingPause()
		end
	end

	function gadget:Initialize()
		pausedByGadget = (spGetGameRulesParam(RULESPARAM_PAUSED) or 0) == 1
		controllerID = getPauseControllerID()
		gadgetHandler:AddSyncAction(SYNCACTION, onGamePause)
		gadgetHandler:AddSyncAction(MESSAGE_WIDGETS_UNPAUSED, onWidgetsUnpaused)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNCACTION)
		gadgetHandler:RemoveSyncAction(MESSAGE_WIDGETS_UNPAUSED)
	end
end
