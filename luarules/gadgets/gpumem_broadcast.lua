local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "GPU mem Broadcast",
		desc	= "Broadcasts GPU mem usage",
		author	= "Floris",
		date	= "May 2018",
		license = "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local sendPacketEvery	= 15

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end
	local function randomString(length)
		if not length or length <= 0 then return '' end
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end

	local validation = randomString(2)
	_G.validationGpuMem = validation

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,1)=="@" and msg:sub(2,3)==validation then
			SendToUnsynced("gpumemBroadcast",playerID,tonumber(msg:sub(4)))
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

	function handleEvent(_,playerID,mem)
		if Script.LuaUI("GpuMemEvent") then
			Script.LuaUI.GpuMemEvent(playerID,mem)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + GetLastUpdateSeconds()
		if updateTimer > sendPacketEvery then
			local used, max = Spring.GetVidMemUsage()
			if type(used) == 'number' and used > 0 then
				SendLuaRulesMsg("@"..validation..math.ceil((used/max)*100))
				updateTimer = 0
			end
		end
	end

end
