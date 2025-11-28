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

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local screenshotWidthLq = 480
local screenshotWidth = 720	-- must be lower than screenshotWidthHq (else it gets higher color range too)
local screenshotWidthHq = 960 -- (gets higher color range)

--------------------------------------------------------------------------------
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

			SendToUnsynced("SendToReceiver", playerallowed .. name .. ";" .. data)
			return true
		elseif msg:sub(1, 2) == "ss" then
			-- Screenshot request from synced
			local screenshotData = string.sub(msg, 3)
			SendToUnsynced("StartScreenshot", screenshotData)
			return true
		end
	end

else

	local validation = SYNCED.validationPlayerData

	-- Screenshot capture variables
	local userconfigComplete, queueScreenshot, queueScreenShotHeight, queueScreenShotHeightBatch, queueScreenShotH, queueScreenShotHmax
	local queueScreenShotWidth, queueScreenshotGameframe, queueScreenShotPixels, queueScreenShotBroadcastChars, queueScreenShotCharsPerBroadcast, pixels
	local queueScreenShotTexture -- Texture to store the captured and downscaled framebuffer
	local queueScreenShotQuality -- Quality mode: 'hq' = 5+5+5 bits, 'normal' = 4+4+4 bits

	-- Screenshot display variables
	local screenshotVars = {} -- containing: finished, width, height, gameframe, data, dataLast, dlist, pixels, player, filename, saved, saveQueued, posX, posY, quality
	local totalTime = 0

	-- Font
	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local vsx, vsy = Spring.GetViewGeometry()
	local uiScale = math.max(vsy / 1080, 1)
	local fontfileSize = 26
	local fontfileOutlineSize = 9
	local fontfileOutlineStrength = 1.7

	local myPlayerID = Spring.GetMyPlayerID()
	local myPlayerName,_,_,_,_,_,_,_,_,_,accountInfo = Spring.GetPlayerInfo(myPlayerID)
	local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
	local authorized = SYNCED.permissions.playerdata[accountID]

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("SendToReceiver", SendToReceiver)
		gadgetHandler:AddSyncAction("StartScreenshot", StartScreenshot)
		gadget:ViewResize()
	end

	function gadget:Shutdown()
		if screenshotVars.dlist then
			gl.DeleteList(screenshotVars.dlist)
		end
		if font then
			gl.DeleteFont(font)
		end
	end

	function gadget:ViewResize()
		vsx, vsy = Spring.GetViewGeometry()
		uiScale = math.max(vsy / 1080, 1)

		-- Reload font
		if font then
			gl.DeleteFont(font)
		end
		font = gl.LoadFont(fontfile, fontfileSize * uiScale, fontfileOutlineSize * uiScale, fontfileOutlineStrength)
	end

	function gadget:Update(dt)
		totalTime = totalTime + (dt * 1000)
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
		if not authorized then
			return
		end
		if string.sub(msg, 1, 9) == "getconfig" then
			local playerName = string.sub(msg, 11)
			if playerName == myPlayerName then
				local data = VFS.LoadFile("LuaUI/Config/BYAR.lua")
				if data then
					data = string.sub(data, 1, 200000)
					local sendtoauthedplayer = '1'
					Spring.SendLuaRulesMsg('pd' .. validation .. sendtoauthedplayer .. 'config;' .. player .. ';' .. VFS.ZlibCompress(data))
				end
			end
		elseif string.sub(msg, 1, 10) == "getinfolog" then
			local playerName = string.sub(msg, 12)
			if playerName == myPlayerName then
				local userconfig
				local data = ''
				local skipline = false
				local fileLines = lines(VFS.LoadFile("infolog.txt"))
				local maxLines = 2000
				for i, line in ipairs(fileLines) do
					if i > maxLines then
						break
					end
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
			local _, _, mySpec = Spring.GetPlayerInfo(myPlayerID, false)
			if not mySpec and myPlayerName ~= 'Player' then
				Spring.SendMessageToPlayer(player, 'Taking screenshots is disabled when you are a player')
				return
			end
			local width = screenshotWidth
			local playerName = string.sub(msg, 15)
			if string.sub(msg, 1, 15) == 'getscreenshothq' then
				width = screenshotWidthHq
				playerName = string.sub(msg, 17)
			elseif string.sub(msg, 1, 15) == 'getscreenshotlq' then
				width = screenshotWidthLq
				playerName = string.sub(msg, 17)
			end
			if playerName == myPlayerName then
				-- Send message to synced code, which will forward to unsynced
				Spring.SendLuaRulesMsg("ss" .. width .. ";" .. player)
			end
		end
	end

	-- Optimized encoding using base64 charset (6 bits per char)
	local ENCODE_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"

	function DEC_CHAR(IN)
		-- Convert 0-63 range to single base64 character
		local idx = math.floor(IN) + 1
		if idx < 1 then idx = 1 end
		if idx > 64 then idx = 64 end
		return string.sub(ENCODE_CHARS, idx, idx)
	end

	function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
		return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
	end

	local sec = 0
	local screenshotInitialized = false
	local screenshotCaptured = false
	local totalBytesTransmitted = 0

	function StartScreenshot(_, msg)
		local parts = {}
		for part in string.gmatch(msg, "[^;]+") do
			parts[#parts + 1] = part
		end

		local vsx, vsy = Spring.GetViewGeometry()

		-- Clamp screenshot width to screen width
		queueScreenShotWidth = math.min(tonumber(parts[1]), vsx)
		queueScreenShotHeightBatch = 3
		local requestingPlayer = tonumber(parts[2])

		-- Set quality mode: HQ uses 5+5+5 bits (32 levels), normal uses 4+4+4 bits (16 levels)
		queueScreenShotQuality = (queueScreenShotWidth >= screenshotWidthHq) and 'hq' or 'normal'

		queueScreenshot = true
		queueScreenshotGameframe = Spring.GetGameFrame()
		queueScreenShotHeight = math.min(math.floor(queueScreenShotWidth * (vsy / vsx)), vsy)
		queueScreenShotH = 0
		queueScreenShotHmax = queueScreenShotH + queueScreenShotHeightBatch
		queueScreenShotPixels = {}
		queueScreenShotBroadcastChars = 0
		queueScreenShotCharsPerBroadcast = 9000
		screenshotInitialized = false
		screenshotCaptured = false
		totalBytesTransmitted = 0
		sec = 0
		--Spring.Echo("Starting screenshot capture: " .. queueScreenShotWidth .. "x" .. queueScreenShotHeight)
	end

	function gadget:DrawScreenPost()
		if not queueScreenshot then
			return
		end
		-- First frame: just prepare textures, don't capture yet
		if not screenshotInitialized then

			-- Create a downscaled texture with FBO support for later reading
			queueScreenShotTexture = gl.CreateTexture(queueScreenShotWidth, queueScreenShotHeight, {
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP,
				wrap_t = GL.CLAMP,
				fbo = true,
			})

			if not queueScreenShotTexture then
				--Spring.Echo("Failed to create texture for screenshot")
				queueScreenshot = false
				return
			end

			screenshotInitialized = true
			return
		end

		-- Second frame: now capture the framebuffer (which includes widgets from previous frame)
		if not screenshotCaptured then
			local vsx, vsy = Spring.GetViewGeometry()

			-- Create a full-size texture to capture the current framebuffer
			local fullSizeTexture = gl.CreateTexture(vsx, vsy, {
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP,
				wrap_t = GL.CLAMP,
			})

			-- Capture the framebuffer immediately (GPU operation, instant)
			-- This captures the PREVIOUS frame's complete render including widgets
			gl.CopyToTexture(fullSizeTexture, 0, 0, 0, 0, vsx, vsy)

			-- Calculate intermediate sizes (downscale by ~2x each pass)
			local passes = {}
			local currentW, currentH = vsx, vsy
			local targetW, targetH = queueScreenShotWidth, queueScreenShotHeight

			-- Build downscaling chain
			while currentW / targetW > 2 or currentH / targetH > 2 do
				currentW = math.max(targetW, math.floor(currentW / 2))
				currentH = math.max(targetH, math.floor(currentH / 2))
				table.insert(passes, {currentW, currentH})
			end

			-- Apply multi-pass downscaling
			if #passes > 0 then
				local sourceTexture = fullSizeTexture
				for i = 1, #passes do
					local w, h = passes[i][1], passes[i][2]
					local intermediateTexture = gl.CreateTexture(w, h, {
						border = false,
						min_filter = GL.LINEAR,
						mag_filter = GL.LINEAR,
						wrap_s = GL.CLAMP,
						wrap_t = GL.CLAMP,
						fbo = true,
					})

					gl.RenderToTexture(intermediateTexture, function()
						gl.BlendFunc(GL.ONE, GL.ZERO) -- Disable blending for accurate color copy
						gl.Color(1, 1, 1, 1)
						gl.Texture(sourceTexture)
						-- Use simple TexRect for intermediate passes
						gl.TexRect(-1, -1, 1, 1)
						gl.Texture(false)
						gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- Restore default blending
					end)						-- Clean up previous intermediate texture (but not the original)
					if sourceTexture ~= fullSizeTexture then
						gl.DeleteTexture(sourceTexture)
					end
				sourceTexture = intermediateTexture
			end

				-- Final pass - flip only if even number of passes (odd already flipped, even needs flip)
				local needsFlip = (#passes % 2 == 0)
				gl.RenderToTexture(queueScreenShotTexture, function()
					gl.BlendFunc(GL.ONE, GL.ZERO)
					gl.Color(1, 1, 1, 1)
					gl.Texture(sourceTexture)
					if needsFlip then
						gl.TexRect(-1, 1, 1, -1) -- Flip for even passes
					else
						gl.TexRect(-1, -1, 1, 1) -- Normal for odd passes
					end
					gl.Texture(false)
					gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				end)
				-- Clean up
				if sourceTexture ~= fullSizeTexture then
					gl.DeleteTexture(sourceTexture)
				end
			else
				-- No intermediate passes needed, direct downscale with flip (0 passes = even)
				gl.RenderToTexture(queueScreenShotTexture, function()
					gl.BlendFunc(GL.ONE, GL.ZERO)
					gl.Color(1, 1, 1, 1)
					gl.Texture(fullSizeTexture)
					gl.TexRect(-1, 1, 1, -1) -- Flip Y
					gl.Texture(false)
					gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				end)
			end
			-- Delete the full-size texture, we don't need it anymore
			gl.DeleteTexture(fullSizeTexture)

			screenshotCaptured = true
			return
		end

		sec = sec + Spring.GetLastUpdateSeconds()
		if sec > 0.01 then  -- Throttle to avoid too frequent reads
			sec = 0

			-- Read pixels from the downscaled texture in row chunks
			gl.RenderToTexture(queueScreenShotTexture, function()
				local rowsToRead = math.min(queueScreenShotHeightBatch, queueScreenShotHeight - queueScreenShotH)
				if rowsToRead > 0 then
					-- Read one row at a time for consistency
					for row = 0, rowsToRead - 1 do
						local currentRow = queueScreenShotH + row
						if currentRow < queueScreenShotHeight then
							-- Read single row with RGB format
							local pixelData = gl.ReadPixels(0, currentRow, queueScreenShotWidth, 1, GL.RGB)
							if pixelData then
								if queueScreenShotQuality == 'hq' then
									-- HQ mode: Pack 2 pixels into 5 chars using 5-bit values (32 color levels per channel)
									-- 2 pixels = 30 bits total, packed into 5 chars (30 bits)
									for pixelIdx = 1, #pixelData, 2 do
										local pixel1 = pixelData[pixelIdx]
										local r1 = math.floor((pixel1[1] or 0) * 31) -- 5 bits (0-31)
										local g1 = math.floor((pixel1[2] or 0) * 31) -- 5 bits (0-31)
										local b1 = math.floor((pixel1[3] or 0) * 31) -- 5 bits (0-31)

										if pixelIdx + 1 <= #pixelData then
									-- Two pixels: pack 30 bits into 5 chars
									local pixel2 = pixelData[pixelIdx + 1]
									local r2 = math.floor((pixel2[1] or 0) * 31) -- 5 bits (0-31)
									local g2 = math.floor((pixel2[2] or 0) * 31) -- 5 bits (0-31)
									local b2 = math.floor((pixel2[3] or 0) * 31) -- 5 bits (0-31)

									-- Wait, G2 is 5 bits, so char4 should be: R2[1:0] + G2[4:1] (2+4 bits)
									-- and char5 should be: G2[0] + B2[4:0] (1+5 bits)
									local packed1 = r1 * 2 + math.floor(g1 / 16)
									local packed2 = (g1 % 16) * 4 + math.floor(b1 / 8)
									local packed3 = (b1 % 8) * 8 + math.floor(r2 / 4)
									local packed4 = (r2 % 4) * 16 + math.floor(g2 / 2)
									local packed5 = (g2 % 2) * 32 + b2											queueScreenShotBroadcastChars = queueScreenShotBroadcastChars + 5
											queueScreenShotPixels[#queueScreenShotPixels + 1] = DEC_CHAR(packed1) .. DEC_CHAR(packed2) .. DEC_CHAR(packed3) .. DEC_CHAR(packed4) .. DEC_CHAR(packed5)
										else
										-- Odd pixel: encode as 3 chars (15 bits in 18 bits space)
										local packed1 = r1 * 2 + math.floor(g1 / 16)
										local packed2 = (g1 % 16) * 4 + math.floor(b1 / 8)
										local packed3 = (b1 % 8) * 8											queueScreenShotBroadcastChars = queueScreenShotBroadcastChars + 3
											queueScreenShotPixels[#queueScreenShotPixels + 1] = DEC_CHAR(packed1) .. DEC_CHAR(packed2) .. DEC_CHAR(packed3)
										end
									end
								else
									-- Normal mode: Pack 1 pixel into 2 chars using 4-bit values (16 color levels per channel)
									-- Format: char1 = RG (4+4 bits), char2 = B0 (4+2 unused bits)
									for pixelIdx = 1, #pixelData do
										local pixel = pixelData[pixelIdx]
										local r = math.floor((pixel[1] or 0) * 15) -- 4 bits (0-15)
										local g = math.floor((pixel[2] or 0) * 15) -- 4 bits (0-15)
										local b = math.floor((pixel[3] or 0) * 15) -- 4 bits (0-15)

										-- Pack into 2 chars: RG|B0
										local packed1 = r * 4 + math.floor(g / 4) -- Upper 6 bits: RRRR GG
										local packed2 = (g % 4) * 16 + b -- Lower 6 bits: GG BBBB

										queueScreenShotBroadcastChars = queueScreenShotBroadcastChars + 2
										queueScreenShotPixels[#queueScreenShotPixels + 1] = DEC_CHAR(packed1) .. DEC_CHAR(packed2)
									end
								end
							end
						end
					end
					queueScreenShotH = queueScreenShotH + rowsToRead
				end
			end)

			queueScreenShotHmax = queueScreenShotH + queueScreenShotHeightBatch
			if queueScreenShotHmax > queueScreenShotHeight then
				queueScreenShotHmax = queueScreenShotHeight
			end

			if queueScreenShotBroadcastChars >= queueScreenShotCharsPerBroadcast or queueScreenShotH >= queueScreenShotHeight then
				local finished = '0'
				if queueScreenShotH >= queueScreenShotHeight then
					finished = '1'
				end
				local data = finished .. ';' .. queueScreenShotWidth .. ';' .. queueScreenShotHeight .. ';' .. queueScreenshotGameframe .. ';' .. queueScreenShotQuality .. ';' .. table.concat(queueScreenShotPixels)
				local sendtoauthedplayer = '0'
				local message = 'pd' .. validation .. sendtoauthedplayer .. 'screenshot;' .. VFS.ZlibCompress(data)
				local messageBytes = string.len(message)
				totalBytesTransmitted = totalBytesTransmitted + messageBytes
				Spring.SendLuaRulesMsg(message)
				queueScreenShotBroadcastChars = 0
				queueScreenShotPixels = {}
				pixels = nil
				data = nil
				if finished == '1' then
					-- Clean up the texture
					if queueScreenShotTexture then
						gl.DeleteTexture(queueScreenShotTexture)
						queueScreenShotTexture = nil
					end
					queueScreenshot = nil
					screenshotInitialized = false
					screenshotCaptured = false
					local kilobytes = totalBytesTransmitted / 1024
					--Spring.Echo(string.format("Completed screenshot capture and sending. Total transmitted: %.2f KB (%d bytes)", kilobytes, totalBytesTransmitted))
				end
			end
		end
	end

	function SendToReceiver(_, msg)
		local _, _, mySpec = Spring.GetPlayerInfo(myPlayerID, false)
		if authorized and (mySpec or myPlayerName == 'Player' or string.sub(msg, 1, 1) == '1') then
			PlayerDataBroadcast(myPlayerName, string.sub(msg, 2))
		end
	end

	local function math_isInRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
		return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
	end

	function toPixels(str, quality)
		local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"
		local pixels = {}
		local pixelsCount = 0

		if quality == 'hq' then
			-- HQ mode: Decode 5-bit color channels (32 levels)
			local i = 1
			while i <= string.len(str) do
				if i + 4 <= string.len(str) then
					local val = {}
					for j = 0, 4 do
						local c = string.sub(str, i + j, i + j)
						for ci = 1, string.len(chars) do
							if c == string.sub(chars, ci, ci) then
								val[j + 1] = ci - 1
								break
							end
						end
					end

					if val[1] and val[2] and val[3] and val[4] and val[5] then
						local r1 = math.floor(val[1] / 2)
						local g1 = (val[1] % 2) * 16 + math.floor(val[2] / 4)
						local b1 = (val[2] % 4) * 8 + math.floor(val[3] / 8)
						local r2 = (val[3] % 8) * 4 + math.floor(val[4] / 16)
						local g2 = (val[4] % 16) * 2 + math.floor(val[5] / 32)
						local b2 = (val[5] % 32)

						pixelsCount = pixelsCount + 1
						pixels[pixelsCount] = {r1 / 31, g1 / 31, b1 / 31}
						pixelsCount = pixelsCount + 1
						pixels[pixelsCount] = {r2 / 31, g2 / 31, b2 / 31}
					end
					i = i + 5
				elseif i + 2 <= string.len(str) then
					local val = {}
					for j = 0, 2 do
						local c = string.sub(str, i + j, i + j)
						for ci = 1, string.len(chars) do
							if c == string.sub(chars, ci, ci) then
								val[j + 1] = ci - 1
								break
							end
						end
					end

					if val[1] and val[2] and val[3] then
						local r = math.floor(val[1] / 2)
						local g = (val[1] % 2) * 16 + math.floor(val[2] / 4)
						local b = (val[2] % 4) * 8 + math.floor(val[3] / 8)

						pixelsCount = pixelsCount + 1
						pixels[pixelsCount] = {r / 31, g / 31, b / 31}
					end
					i = i + 3
				else
					break
				end
			end
		else
			-- Normal mode: Decode 4-bit color channels (16 levels)
			local i = 1
			while i + 1 <= string.len(str) do
				local char1 = string.sub(str, i, i)
				local char2 = string.sub(str, i + 1, i + 1)

				local val1, val2
				for ci = 1, string.len(chars) do
					local c = string.sub(chars, ci, ci)
					if char1 == c then
						val1 = ci - 1
					end
					if char2 == c then
						val2 = ci - 1
					end
				end

				if val1 and val2 then
					local r = math.floor(val1 / 4)
					local g = (val1 % 4) * 4 + math.floor(val2 / 16)
					local b = val2 % 16

					pixelsCount = pixelsCount + 1
					pixels[pixelsCount] = {r / 15, g / 15, b / 15}
				end

				i = i + 2
			end
		end
		return pixels
	end

	function PlayerDataBroadcast(playerName, msg)
		local data = ''
		local count = 0
		local startPos = 0
		local msgType

		for i = 1, string.len(msg) do
			if string.sub(msg, i, i) == ';' then
				count = count + 1
				if count == 1 then
					startPos = i + 1
					playerName = string.sub(msg, 1, i - 1)
				elseif count == 2 then
					msgType = string.sub(msg, startPos, i - 1)
					data = string.sub(msg, i + 1)
					break
				end
			end
		end

		if data then
			if msgType == 'screenshot' then
				data = VFS.ZlibDecompress(data)
				count = 0
				for i = 1, string.len(data) do
					if string.sub(data, i, i) == ';' then
						count = count + 1
						if count == 1 then
							local finished = string.sub(data, 1, i - 1)
							screenshotVars.finished = (finished == '1')
							startPos = i + 1
						elseif count == 2 then
							screenshotVars.width = tonumber(string.sub(data, startPos, i - 1))
							startPos = i + 1
						elseif count == 3 then
							screenshotVars.height = tonumber(string.sub(data, startPos, i - 1))
							startPos = i + 1
						elseif count == 4 then
							screenshotVars.gameframe = tonumber(string.sub(data, startPos, i - 1))
							startPos = i + 1
						elseif count == 5 then
							screenshotVars.quality = string.sub(data, startPos, i - 1)
							if not screenshotVars.data then
								screenshotVars.data = string.sub(data, i + 1)
							else
								screenshotVars.data = screenshotVars.data .. string.sub(data, i + 1)
							end
							break
						end
					end
				end
				data = nil
				screenshotVars.dataLast = totalTime

				if screenshotVars.finished or totalTime - 4000 > screenshotVars.dataLast then
					screenshotVars.finished = true
					local minutes = math.floor((screenshotVars.gameframe / 30 / 60))
					local seconds = math.floor((screenshotVars.gameframe - ((minutes * 60) * 30)) / 30)
					if seconds == 0 then
						seconds = '00'
					elseif seconds < 10 then
						seconds = '0' .. seconds
					end
					screenshotVars.pixels = toPixels(screenshotVars.data, screenshotVars.quality)
					screenshotVars.player = playerName
					screenshotVars.filename = "gameframe_" .. screenshotVars.gameframe .. "_" .. minutes .. '.' .. seconds .. "_" .. playerName

					-- Get team color for player name
					local playerList = Spring.GetPlayerList()
					local teamID, r, g, b
					for _, pID in ipairs(playerList) do
						local name = Spring.GetPlayerInfo(pID, false)
						if name == playerName then
							teamID = select(4, Spring.GetPlayerInfo(pID, false))
							if teamID then
								r, g, b = Spring.GetTeamColor(teamID)
							end
							break
						end
					end
					screenshotVars.teamColor = (r and g and b) and {r, g, b} or {1, 1, 1}
					screenshotVars.saved = nil
					screenshotVars.saveQueued = true
					screenshotVars.posX = (vsx - screenshotVars.width * uiScale) / 2
					screenshotVars.posY = (vsy - screenshotVars.height * uiScale) / 2
					screenshotVars.dlist = gl.CreateList(function()
						gl.PushMatrix()
						gl.Translate(screenshotVars.posX, screenshotVars.posY, 0)
						gl.Scale(uiScale, uiScale, 0)

						gl.Color(0, 0, 0, 0.66)
						local margin = 2.6
						gl.Rect(-margin, -margin, screenshotVars.width + margin + margin, screenshotVars.height + 15 + margin + margin)
						gl.Color(1, 1, 1, 0.025)
						gl.Rect(0, 0, screenshotVars.width, screenshotVars.height + 12 + margin + margin)

						font:Begin()
						font:Print("\255\160\160\160"..screenshotVars.filename .. '.png', screenshotVars.width - 4, screenshotVars.height + 6.5, 11, "orn")
						local tc = screenshotVars.teamColor
						font:Print(string.char(255, math.floor(tc[1] * 255), math.floor(tc[2] * 255), math.floor(tc[3] * 255)) .. screenshotVars.player, 4, screenshotVars.height + 6.5, 11, "on")
						font:End()
						local row = 0
						local col = 0
						for p = 1, #screenshotVars.pixels do
							gl.Color(screenshotVars.pixels[p][1], screenshotVars.pixels[p][2], screenshotVars.pixels[p][3], 1)
							gl.Rect(col, row, col + 1, row + 1)
							col = col + 1
							if col >= screenshotVars.width then
								col = 0
								row = row + 1
							end
						end
						gl.PopMatrix()
					end)
					screenshotVars.pixels = nil
					screenshotVars.data = nil
					screenshotVars.finished = nil
				end
			elseif msgType == 'infolog' or msgType == 'config' then
				local playerID
				for i = 1, string.len(data) do
					if string.sub(data, i, i) == ';' then
						playerID = tonumber(string.sub(data, 1, i - 1))
						data = string.sub(data, i + 1)
						break
					end
				end

			if playerID == myPlayerID then
				local gameframe = Spring.GetGameFrame()					local filename = 'playerdata_' .. msgType .. 's.txt'
					local filedata = ''
					if VFS.FileExists(filename) then
						filedata = tostring(VFS.LoadFile(filename))
					end
					local file = assert(io.open(filename, 'w'), 'Unable to save ' .. filename)
					file:write(filedata .. '-----------------------------------------------------\n----  GameFrame: ' .. gameframe .. '  Player: ' .. playerName .. '\n-----------------------------------------------------\n' .. VFS.ZlibDecompress(data) .. "\n\n\n\n\n\n")
					file:close()
					Spring.Echo('Added ' .. msgType .. ' to ' .. filename)
				end
			end
		end
	end

	function gadget:DrawScreen()
		if screenshotVars.dlist then
			gl.CallList(screenshotVars.dlist)

			-- Handle screenshot saving (needs 2 frames to properly capture)
			local margin = 2 * uiScale
			local left = screenshotVars.posX - margin
			local bottom = screenshotVars.posY - margin
			local width = (screenshotVars.width * uiScale) + margin + margin + margin
			local height = (screenshotVars.height * uiScale) + margin + margin + margin + (15 * uiScale)

			if screenshotVars.saveQueued then
				if not screenshotVars.saved then
					screenshotVars.saved = 'next'
				elseif screenshotVars.saved == 'next' then
					screenshotVars.saved = 'done'
					local file = 'screenshots/' .. screenshotVars.filename .. '.png'
					gl.SaveImage(left, bottom, width, height, file)
					Spring.Echo('Screenshot saved to: ' .. file)
					screenshotVars.saveQueued = nil
				end
			end

			-- Handle mouse interaction (click to close)
			local mouseX, mouseY, mouseButtonL = Spring.GetMouseState()
			if screenshotVars.width and mouseButtonL and math_isInRect(mouseX, mouseY, screenshotVars.posX, screenshotVars.posY, screenshotVars.posX + (screenshotVars.width * uiScale), screenshotVars.posY + (screenshotVars.height * uiScale)) then
				gl.DeleteList(screenshotVars.dlist)
				screenshotVars = {}
			end
		end
	end
end
