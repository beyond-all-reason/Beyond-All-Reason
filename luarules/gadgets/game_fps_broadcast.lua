local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "FPS Broadcast",
		desc = "Broadcasts FramesPerSecond",
		author = "Floris",
		date = "July,2016",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local sendPacketEvery = 2

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationFps = validation

	local at_b = string.byte("@") -- 64
	local vb1, vb2 = string.byte(validation, 1, 2)

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg >= 3 and string.byte(msg, 1) == at_b and string.byte(msg, 2) == vb1 and string.byte(msg, 3) == vb2 then
			SendToUnsynced("fpsBroadcast", playerID, tonumber(msg:sub(4)))
			return true
		end
	end
else
	--------------------------------------------------------------------------------
	-- unsynced
	--------------------------------------------------------------------------------

	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetFPS = Spring.GetFPS

	local updateTimer = 0
	local avgFps = GetFPS()
	local numFrames = 0
	local validation = SYNCED.validationFps

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("fpsBroadcast", handleFpsEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("fpsBroadcast")
	end

	function handleFpsEvent(_, playerID, fps)
		if Script.LuaUI("FpsEvent") then
			Script.LuaUI.FpsEvent(playerID, fps)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + GetLastUpdateSeconds()
		numFrames = numFrames + 1
		avgFps = ((avgFps * (numFrames - 1)) + GetFPS()) / numFrames
		if updateTimer > sendPacketEvery then
			SendLuaRulesMsg("@" .. validation .. math.floor(avgFps + 0.5))
			updateTimer = 0
			avgFps = 0
			numFrames = 0
		end
	end
end
