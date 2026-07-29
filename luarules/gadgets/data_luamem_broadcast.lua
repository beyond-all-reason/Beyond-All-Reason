local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Lua mem Broadcast",
		desc = "Broadcasts Lua mem usage",
		author = "Floris",
		date = "June 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local sendPacketEvery = 10

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationLuaMem = validation

	local pct_b = string.byte("%") -- 37
	local vb1, vb2 = string.byte(validation, 1, 2)

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg >= 3 and string.byte(msg, 1) == pct_b and string.byte(msg, 2) == vb1 and string.byte(msg, 3) == vb2 then
			local um = tonumber(msg:sub(4))
			if um then
				SendToUnsynced("luamemBroadcast", playerID, um)
				return true
			end
		end
	end
else
	--------------------------------------------------------------------------------
	-- unsynced
	--------------------------------------------------------------------------------

	local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local GetLuaMemUsage = Spring.GetLuaMemUsage
	local validation = SYNCED.validationLuaMem
	local updateTimer = 0

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("luamemBroadcast", handleEvent)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("luamemBroadcast")
	end

	function handleEvent(_, playerID, um)
		if Script.LuaUI("LuaMemEvent") then
			Script.LuaUI.LuaMemEvent(playerID, um)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + GetLastUpdateSeconds()
		if updateTimer > sendPacketEvery then
			local _, _, _, _, um = GetLuaMemUsage()
			if type(um) == "number" then
				SendLuaRulesMsg("%" .. validation .. math.ceil(um / 1024))
				updateTimer = 0
			end
		end
	end
end
