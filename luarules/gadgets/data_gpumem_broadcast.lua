local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "GPU mem Broadcast",
		desc = "Broadcasts GPU mem usage",
		author = "Floris",
		date = "May 2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local sendPacketEvery = 15

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationGpuMem = validation

	local at_b = string.byte("@") -- 64
	local vb1, vb2 = string.byte(validation, 1, 2)

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg >= 3 and string.byte(msg, 1) == at_b and string.byte(msg, 2) == vb1 and string.byte(msg, 3) == vb2 then
			SendToUnsynced("gpumemBroadcast", playerID, tonumber(msg:sub(4)))
			return true
		end
	end
else
	--------------------------------------------------------------------------------
	-- unsynced
	--------------------------------------------------------------------------------

	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local validation = SYNCED.validationGpuMem
	local updateTimer = 0

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("gpumemBroadcast", handleEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("gpumemBroadcast")
	end

	function handleEvent(_, playerID, mem)
		if Script.LuaUI("GpuMemEvent") then
			Script.LuaUI.GpuMemEvent(playerID, mem)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + GetLastUpdateSeconds()
		if updateTimer > sendPacketEvery then
			local used, max = Spring.GetVidMemUsage()
			if type(used) == "number" and used > 0 then
				SendLuaRulesMsg("@" .. validation .. math.ceil((used / max) * 100))
				updateTimer = 0
			end
		end
	end
end
