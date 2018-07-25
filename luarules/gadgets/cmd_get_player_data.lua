--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Get Player Data",
    desc      = "",
    author    = "Floris",
    date      = "July 2018",
    license   = "GNU GPL, v2 or later",
    layer     = -math.huge,
    enabled   = true
  }
end

local devs = {
	["[teh]Flow"] = true,
	['FlowerPower'] = true,
	['Floris'] = true,
	['[Fx]Doo'] = true,
	['[PiRO]JiZaH'] = true,
	['Player'] = true,
}

if (gadgetHandler:IsSyncedCode()) then
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
	_G.validationPlayerData = validation

	function gadget:RecvLuaMsg(msg, player)
		if msg:sub(1,2)=="pd" and msg:sub(3,4)==validation then
			local name = Spring.GetPlayerInfo(player)
			local data = string.sub(msg, 5)

			SendToUnsynced("SendToWG", name..";"..data)
			return true
		end
	end

else

	local validation = SYNCED.validationPlayerData

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendToWG", SendToWG)
	end

	function gadget:GotChatMsg(msg, player)
		local playername = Spring.GetPlayerInfo(player)
		if not devs[playername] then
			return
		end
		if string.sub(msg,1,9) == "getconfig" then
			local playerName = string.sub(msg, 11)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) then
				local config = VFS.LoadFile("LuaUI/Config/BA.lua")
				if config then
					config = string.sub(config, 1, 60000)
					--config = VFS.ZlibCompress(config)
					Spring.SendLuaRulesMsg("pd"..validation.."config;"..config)
				end
			end
		elseif string.sub(msg,1,10) == "getinfolog" then
			local playerName = string.sub(msg, 12)
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) then
				local infolog = VFS.LoadFile("infolog.txt")
				if infolog then
					infolog = string.sub(infolog, 1, 30000)
					--infolog = VFS.ZlibCompress(infolog)
					Spring.SendLuaRulesMsg("pd"..validation.."infolog;"..infolog)
				end
			end
		elseif string.sub(msg,1,13) == "getscreenshot" then

			queueScreenShotGreyscale = false
			local playerName = string.sub(msg, 15)
			if string.sub(msg,1,17) == "getscreenshotgrey" then
				queueScreenShotGreyscale = true
				playerName = string.sub(msg, 19)
			end
			if playerName == select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID())) then
				local vsx, vsy = Spring.GetViewGeometry()
				if queueScreenShotGreyscale then
					queueScreenShotWidth = 260
					queueScreenShotHeightBatch = 3
				else
					queueScreenShotWidth = 150
					queueScreenShotHeightBatch = 3
				end
				queueScreenshot = true
				queueScreenShotHeight = math.floor(queueScreenShotWidth*(vsy/vsx))
				queueScreenShotStep = vsx/queueScreenShotWidth
				queueScreenShotH = 0
				queueScreenShotHmax = queueScreenShotH + queueScreenShotHeightBatch
				queueScreenShotPixels = {}
				queueScreenShotCamState = getCamStateStr()
			end
		end
	end

	local sec = 0
	function gadget:Update(dt)
		if queueScreenshot then
			sec = sec + Spring.GetLastUpdateSeconds()
			if sec > 0.0333 then
				sec = 0
				local r,g,b
				while queueScreenShotH < queueScreenShotHmax do
					queueScreenShotH = queueScreenShotH + 1
					for w=1, queueScreenShotWidth do
						r,g,b = gl.ReadPixels(math.floor(queueScreenShotStep*(w-0.5)),math.floor(queueScreenShotStep*(queueScreenShotH-0.5)),1,1)
						if queueScreenShotGreyscale then
							queueScreenShotPixels[#queueScreenShotPixels+1] = DEC_AZ((r + g + b )*94/3)	-- greyscale
						else
							queueScreenShotPixels[#queueScreenShotPixels+1] = DEC_AZ(r*94)..DEC_AZ(g*94)..DEC_AZ(b*94)
						end
					end
				end
				queueScreenShotHmax = queueScreenShotHmax + queueScreenShotHeightBatch
				if queueScreenShotHmax > queueScreenShotHeight then
					queueScreenShotHmax = queueScreenShotHeight
				end
				if queueScreenShotH >= queueScreenShotHeight then
					local rgb = '1'
					if queueScreenShotGreyscale then
						rgb = '0'
					end
					local camchanged = '0'
					if queueScreenShotCamState ~= getCamStateStr() then
						camchanged = '1'
					end
					local data = queueScreenShotWidth .. ';' .. queueScreenShotHeight .. ';' ..rgb.. ';' .. camchanged .. ';' .. table.concat(queueScreenShotPixels)
					pixels = nil
					data = VFS.ZlibCompress(data)
					Spring.SendLuaRulesMsg("pd"..validation.."screenshot;"..data)
					queueScreenshot = nil
					data = nil
				end
			end
		end
	end

	function getCamStateStr()
		local camstate = Spring.GetCameraState()
		local str = ''
		for k,v in pairs(camstate) do
			str = str .. v
		end
		return str
	end

	function DEC_AZ(IN)
		local B,K,OUT,I,D=95,"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ !@#$%^&*()_+-=[]{};:,./<>?~|`'\"\\","",0
		while IN>0 do
			I=I+1
			IN,D=math.floor(IN/B),math.modf(IN,B)+1
			OUT=string.sub(K,D,D)..OUT
		end
		if OUT == '' then OUT = '0' end	-- somehow sometimes its empty
		return OUT
	end

	function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)

		-- check if the mouse is in a rectangle
		return x >= BLcornerX and x <= TRcornerX
				and y >= BLcornerY
				and y <= TRcornerY
	end

	function SendToWG(_,msg)
		local myplayername = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
		if Script.LuaUI("PlayerDataBroadcast") then
			Script.LuaUI.PlayerDataBroadcast(myplayername, msg)
		end
		if devs[myplayername] then
			--Spring.Echo('PlayerDataBroadcast complete...')
		end
	end
end