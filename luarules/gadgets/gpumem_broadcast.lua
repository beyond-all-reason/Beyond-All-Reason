local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
	local function Split(s, separator)
		local results = {}
		for part in s:gmatch("[^"..separator.."]+") do
			results[#results + 1] = part
		end
		return results
	end
	engineVersion = Split(Engine.version, '-')
	if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
		engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
	else
		engineVersion = tonumber(Engine.version)
	end
elseif Game and Game.version then
	engineVersion = tonumber(Game.version)
end

if (engineVersion < 1000 and engineVersion >= 105) or engineVersion >= 10401138 then

	function gadget:GetInfo()
		return {
			name	= "GPU mem Broadcast",
			desc	= "Broadcasts GPU mem usage",
			author	= "Floris",
			date	= "May 2018",
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
			--math.randomseed(os.clock()^5)
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
end
