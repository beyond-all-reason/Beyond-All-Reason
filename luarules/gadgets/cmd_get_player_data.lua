--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Get Player Data",
		desc = "",
		author = "Floris",
		date = "July 2018",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = true
	}
end


if gadgetHandler:IsSyncedCode() then

	local charset = {}
	do
		-- [0-9a-zA-Z]
		for c = 48, 57 do
			table.insert(charset, string.char(c))
		end
		for c = 65, 90 do
			table.insert(charset, string.char(c))
		end
		for c = 97, 122 do
			table.insert(charset, string.char(c))
		end
	end
	local function randomString(length)
		if not length or length <= 0 then
			return ''
		end
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end
	local validation = randomString(2)
	_G.validationPlayerData = validation

	function gadget:RecvLuaMsg(msg, player)
		if msg:sub(1, 2) == "pd" and msg:sub(3, 4) == validation then
			local name = Spring.GetPlayerInfo(player, false)
			local data = string.sub(msg, 6)
			local playerallowed = string.sub(msg, 5, 5)

			SendToUnsynced("SendToWG", playerallowed .. name .. ";" .. data)
			return true
		end
	end

else

	local validation = SYNCED.validationPlayerData

	local userconfigComplete, queueScreenshot, queueScreenShotHeight, queueScreenShotHeightBatch, queueScreenShotH, queueScreenShotHmax, queueScreenShotStep
	local queueScreenShotWidth, queueScreenshotGameframe, queueScreenShotPixels, queueScreenShotBroadcastChars, queueScreenShotCharsPerBroadcast, pixels

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendToWG", SendToWG)
	end

	function lines(str)
		local t = {}
		local function helper(line)
			table.insert(t, line)
			return ""
		end
		helper((str:gsub("(.-)\r?\n", helper)))
		return t
	end

	function gadget:GotChatMsg(msg, player)
		local myPlayerName, _, mySpec = Spring.GetPlayerInfo(player, false)
		if not SYNCED.permissions.playerdata[myPlayerName] then
			return
		end
		if string.sub(msg, 1, 9) == "getconfig" then
			local playerName = string.sub(msg, 11)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)) then
				local data = VFS.LoadFile("LuaUI/Config/BAR.lua")
				if data then
					data = string.sub(data, 1, 200000)
					local sendtoauthedplayer = '1'
					Spring.SendLuaRulesMsg('pd' .. validation .. sendtoauthedplayer .. 'config;' .. player .. ';' .. VFS.ZlibCompress(data))
				end
			end
		elseif string.sub(msg, 1, 10) == "getinfolog" then
			local playerName = string.sub(msg, 12)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)) then
				local userconfig
				local data = ''
				local skipline = false
				local fileLines = lines(VFS.LoadFile("infolog.txt"))
				for i, line in ipairs(fileLines) do
					if not userconfig and string.find(line, '============== <User Config> ==============', nil, true) then
						userconfig = ''
					end
					if not userconfigComplete then
						if userconfig then
							if string.find(line, '============== </User Config> ==============', nil, true) then
								userconfig = userconfig .. '============== </User Config> ==============\n'
								userconfigComplete = true
							else
								userconfig = userconfig .. line .. '\n'
							end
						end
					else
						skipline = false
						-- filter paths for privacy reasons
						if string.find(line, 'Using read-', nil, true) or
							string.find(line, 'Scanning: ', nil, true) or
							string.find(line, 'Recording demo to: ', nil, true) or
							string.find(line, 'Loading StartScript from: ', nil, true) or
							string.find(line, 'Writing demo: ', nil, true) or
							string.find(line, 'command-line args: ', nil, true) or
							string.find(line, 'Using configuration source: ', nil, true)
						then
							skipline = true
						end
						if not skipline then
							data = data .. line .. '\n'
						end
					end
				end
				data = userconfig .. data
				if data then
					data = string.sub(data, 1, 250000)
					local sendtoauthedplayer = '1'
					Spring.SendLuaRulesMsg('pd' .. validation .. sendtoauthedplayer .. 'infolog;' .. player .. ';' .. VFS.ZlibCompress(data))
				end
			end
		elseif string.sub(msg, 1, 13) == 'getscreenshot' then
			if not mySpec and myPlayerName ~= 'Player' then
				Spring.SendMessageToPlayer(player, 'Taking screenshots is disabled when you are a player')
				return
			end
			queueScreenShotWidth = 200
			queueScreenShotHeightBatch = 4

			local playerName = string.sub(msg, 15)
			if string.sub(msg, 1, 15) == 'getscreenshothq' then
				queueScreenShotWidth = 300
				queueScreenShotHeightBatch = 3
				playerName = string.sub(msg, 17)
			end
			if string.sub(msg, 1, 15) == 'getscreenshotlq' then
				queueScreenShotWidth = 140
				queueScreenShotHeightBatch = 5
				playerName = string.sub(msg, 17)
			end
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)) then
				local vsx, vsy = Spring.GetViewGeometry()
				queueScreenshot = true
				queueScreenshotGameframe = Spring.GetGameFrame()
				queueScreenShotHeight = math.floor(queueScreenShotWidth * (vsy / vsx))
				queueScreenShotStep = vsx / queueScreenShotWidth
				queueScreenShotH = 0
				queueScreenShotHmax = queueScreenShotH + queueScreenShotHeightBatch
				queueScreenShotPixels = {}
				--queueScreenShotBroadcastDelay = 1
				queueScreenShotBroadcastChars = 0
				queueScreenShotCharsPerBroadcast = 7500        -- in practice this will be a bit higher because it finishes adding a whole row of pixels
			end
		end
	end

	local sec = 0
	function gadget:Update(dt)
		if queueScreenshot then
			sec = sec + Spring.GetLastUpdateSeconds()
			if sec > 0.03 then
				sec = 0
				local r, g, b
				while queueScreenShotH < queueScreenShotHmax do
					queueScreenShotH = queueScreenShotH + 1
					for w = 1, queueScreenShotWidth do
						r, g, b = gl.ReadPixels(math.floor(queueScreenShotStep * (w - 0.5)), math.floor(queueScreenShotStep * (queueScreenShotH - 0.5)), 1, 1)
						queueScreenShotBroadcastChars = queueScreenShotBroadcastChars + 3
						queueScreenShotPixels[#queueScreenShotPixels + 1] = DEC_CHAR(r * 94) .. DEC_CHAR(g * 94) .. DEC_CHAR(b * 94)
					end
				end

				queueScreenShotHmax = queueScreenShotHmax + queueScreenShotHeightBatch
				if queueScreenShotHmax > queueScreenShotHeight then
					queueScreenShotHmax = queueScreenShotHeight
				end
				if queueScreenShotBroadcastChars >= queueScreenShotCharsPerBroadcast or queueScreenShotH >= queueScreenShotHeight then
					local finished = '0'
					if queueScreenShotH >= queueScreenShotHeight then
						finished = '1'
					end
					local data = finished .. ';' .. queueScreenShotWidth .. ';' .. queueScreenShotHeight .. ';' .. queueScreenshotGameframe .. ';' .. table.concat(queueScreenShotPixels)
					local sendtoauthedplayer = '0'
					Spring.SendLuaRulesMsg('pd' .. validation .. sendtoauthedplayer .. 'screenshot;' .. VFS.ZlibCompress(data))
					queueScreenShotBroadcastChars = 0
					queueScreenShotPixels = {}
					pixels = nil
					data = nil
					if finished == '1' then
						queueScreenshot = nil
					end
				end
			end
		end
	end

	function DEC_CHAR(IN)
		local B, K, OUT, I, D = 95, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ !@#$%^&*()_+-=[]{};:,./<>?~|`'\"\\", "", 0
		while IN > 0 do
			I = I + 1
			IN, D = math.floor(IN / B), math.modf(IN, B) + 1
			OUT = string.sub(K, D, D) .. OUT
		end
		if OUT == '' then
			OUT = '0'
		end -- somehow sometimes its empty
		return OUT
	end

	function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
		return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
	end

	function SendToWG(_, msg)
		local myPlayerName, _, mySpec = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
		if Script.LuaUI("PlayerDataBroadcast") and (mySpec or myPlayerName == 'Player' or string.sub(msg, 1, 1) == '1') and SYNCED.permissions.playerdata[myPlayerName] then
			Script.LuaUI.PlayerDataBroadcast(myPlayerName, string.sub(msg, 2))
		end
	end
end
