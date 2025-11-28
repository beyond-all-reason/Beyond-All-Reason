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

local screenshotWidthLq = 360
local screenshotWidth = 640
local screenshotWidthHq = 960

--------------------------------------------------------------------------------

local isSingleplayer = Spring.Utilities.Gametype.IsSinglePlayer()


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
			-- Format: "ss" + width + ";" + requestingPlayerID
			local screenshotData = string.sub(msg, 3)
			SendToUnsynced("StartScreenshot", screenshotData .. ";" .. player)
			return true
		end
	end

else

	local validation = SYNCED.validationPlayerData

	-- Screenshot capture variables
	local userconfigComplete, queueScreenshot, queueScreenShotHeight, queueScreenShotHeightBatch, queueScreenShotH, queueScreenShotHmax
	local queueScreenShotWidth, queueScreenshotGameframe, queueScreenShotPixels, queueScreenShotBroadcastChars, queueScreenShotCharsPerBroadcast, pixels
	local queueScreenShotTexture -- Texture to store the captured and downscaled framebuffer

	-- Screenshot display variables
	local screenshotVars = {} -- containing: finished, width, height, gameframe, data, dataLast, dlist, texture, player, filename, saved, saveQueued, posX, posY, quality
	local totalTime = 0
	local screenshotCompressedBytes = 0

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

		-- Check if requesting player is authorized spectator
		local _, _, requestingSpec = Spring.GetPlayerInfo(requestingPlayer, false)
		local _, _, mySpec = Spring.GetPlayerInfo(myPlayerID, false)

		-- Allow screenshot if: singleplayer OR (I'm a spec) OR (requesting player is authorized spec)
		if not isSingleplayer and not mySpec and not (requestingSpec and authorized) then
			return  -- Silently reject if conditions not met
		end

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
								-- 4:2:0 chroma subsampling with 5-bit precision
								for pixelIdx = 1, #pixelData, 2 do
									local pixel1 = pixelData[pixelIdx]
									local r1, g1, b1 = pixel1[1] or 0, pixel1[2] or 0, pixel1[3] or 0
									local y1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
									local y1_q = math.floor(y1 * 31 + 0.5) -- 5 bits

									if pixelIdx + 1 <= #pixelData then
										local pixel2 = pixelData[pixelIdx + 1]
										local r2, g2, b2 = pixel2[1] or 0, pixel2[2] or 0, pixel2[3] or 0
										local y2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
										local y2_q = math.floor(y2 * 31 + 0.5) -- 5 bits

										-- Average RGB for chroma
										local r_avg = (r1 + r2) * 0.5
										local g_avg = (g1 + g2) * 0.5
										local b_avg = (b1 + b2) * 0.5
										local y_avg = 0.299 * r_avg + 0.587 * g_avg + 0.114 * b_avg
										local u = (b_avg - y_avg) * 0.492 + 0.5
										local v = (r_avg - y_avg) * 0.877 + 0.5
										local u_q = math.floor(u * 31 + 0.5) -- 5 bits
										local v_q = math.floor(v * 31 + 0.5) -- 5 bits

										-- Pack as 4 chars: Y1, Y2, U, V (each 5-bit)
										queueScreenShotBroadcastChars = queueScreenShotBroadcastChars + 4
										queueScreenShotPixels[#queueScreenShotPixels + 1] = DEC_CHAR(y1_q) .. DEC_CHAR(y2_q) .. DEC_CHAR(u_q) .. DEC_CHAR(v_q)
									else
										-- Odd pixel: Y, U, V in 3 chars
										local u = (b1 - y1) * 0.492 + 0.5
										local v = (r1 - y1) * 0.877 + 0.5
										local u_q = math.floor(u * 31 + 0.5)
										local v_q = math.floor(v * 31 + 0.5)

										queueScreenShotBroadcastChars = queueScreenShotBroadcastChars + 3
										queueScreenShotPixels[#queueScreenShotPixels + 1] = DEC_CHAR(y1_q) .. DEC_CHAR(u_q) .. DEC_CHAR(v_q)
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
				local data = finished .. ';' .. queueScreenShotWidth .. ';' .. queueScreenShotHeight .. ';' .. queueScreenshotGameframe .. ';' .. table.concat(queueScreenShotPixels)
				local sendtoauthedplayer = '0'
				local message = 'pd' .. validation .. sendtoauthedplayer .. 'screenshot;' .. VFS.ZlibCompress(data)
				Spring.SendLuaRulesMsg(message)
				queueScreenShotBroadcastChars = 0
				queueScreenShotPixels = {}
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
				end
			end
		end
	end

	function SendToReceiver(_, msg)
		local _, _, mySpec = Spring.GetPlayerInfo(myPlayerID, false)
		if authorized and (mySpec or isSingleplayer or string.sub(msg, 1, 1) == '1') then
			PlayerDataBroadcast(myPlayerName, string.sub(msg, 2))
		end
	end

	local function math_isInRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
		return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
	end

	function toPixels(str)
		local chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"
		local pixels = {}
		local pixelsCount = 0

		-- Build reverse lookup table for faster character decoding
		local charLookup = {}
		for ci = 1, 64 do
			charLookup[string.sub(chars, ci, ci)] = ci - 1
		end

		-- Decode 4:2:0 chroma subsampling with 5-bit precision
		local i = 1
		local strLen = string.len(str)
		while i <= strLen do
			if i + 3 <= strLen then
				-- Decode 4 chars = Y1, Y2, U, V (2 pixels)
				local c1, c2, c3, c4 = string.byte(str, i, i + 3)
				local val1 = charLookup[string.char(c1)]
				local val2 = charLookup[string.char(c2)]
				local val3 = charLookup[string.char(c3)]
				local val4 = charLookup[string.char(c4)]

				if val1 and val2 and val3 and val4 then
					-- Extract Y, U, V (5-bit each)
					local y1 = val1 / 31
					local y2 = val2 / 31
					local u = val3 / 31 - 0.5
					local v = val4 / 31 - 0.5

					-- YUV to RGB for pixel 1
					local v_r = v / 0.877
					local u_b = u / 0.492
					local u_g = 0.395 * u / 0.492
					local v_g = 0.581 * v / 0.877

					local r1 = y1 + v_r
					local g1 = y1 - u_g - v_g
					local b1 = y1 + u_b

					-- YUV to RGB for pixel 2
					local r2 = y2 + v_r
					local g2 = y2 - u_g - v_g
					local b2 = y2 + u_b

					-- Clamp values to [0,1]
					r1 = r1 < 0 and 0 or (r1 > 1 and 1 or r1)
					g1 = g1 < 0 and 0 or (g1 > 1 and 1 or g1)
					b1 = b1 < 0 and 0 or (b1 > 1 and 1 or b1)
					r2 = r2 < 0 and 0 or (r2 > 1 and 1 or r2)
					g2 = g2 < 0 and 0 or (g2 > 1 and 1 or g2)
					b2 = b2 < 0 and 0 or (b2 > 1 and 1 or b2)

					pixelsCount = pixelsCount + 1
					pixels[pixelsCount] = {r1, g1, b1}
					pixelsCount = pixelsCount + 1
					pixels[pixelsCount] = {r2, g2, b2}
				end
				i = i + 4
			elseif i + 2 <= strLen then
				-- Odd pixel: Y, U, V in 3 chars
				local c1, c2, c3 = string.byte(str, i, i + 2)
				local val1 = charLookup[string.char(c1)]
				local val2 = charLookup[string.char(c2)]
				local val3 = charLookup[string.char(c3)]

				if val1 and val2 and val3 then
					local y = val1 / 31
					local u = val2 / 31 - 0.5
					local v = val3 / 31 - 0.5

					local r = y + v / 0.877
					local g = y - 0.395 * u / 0.492 - 0.581 * v / 0.877
					local b = y + u / 0.492

					r = r < 0 and 0 or (r > 1 and 1 or r)
					g = g < 0 and 0 or (g > 1 and 1 or g)
					b = b < 0 and 0 or (b > 1 and 1 or b)

					pixelsCount = pixelsCount + 1
					pixels[pixelsCount] = {r, g, b}
				end
				i = i + 3
			else
				break
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
				local compressedSize = string.len(data)
				screenshotCompressedBytes = screenshotCompressedBytes + compressedSize
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
					local compressedKB = screenshotCompressedBytes / 1024
					Spring.Echo(string.format("Received screenshot from %s (%.0f KB, increased replay size)", playerName, compressedKB))
					screenshotCompressedBytes = 0

					local minutes = math.floor((screenshotVars.gameframe / 30 / 60))
					local seconds = math.floor((screenshotVars.gameframe - ((minutes * 60) * 30)) / 30)
					if seconds == 0 then
						seconds = '00'
					elseif seconds < 10 then
						seconds = '0' .. seconds
					end

					screenshotVars.pixels = toPixels(screenshotVars.data)					screenshotVars.player = playerName
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
					-- Pixels will be converted to texture in DrawScreen()
					screenshotVars.needsTextureCreation = true
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
					local gameframe = Spring.GetGameFrame()
					local filename = 'playerdata_' .. msgType .. 's.txt'
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
		-- Create display list on first draw after receiving data
		if screenshotVars.needsTextureCreation and screenshotVars.pixels then
			screenshotVars.dlist = gl.CreateList(function()
				gl.PushMatrix()
				gl.Translate(screenshotVars.posX, screenshotVars.posY, 0)
				gl.Scale(uiScale, uiScale, 0)

				gl.Color(0, 0, 0, 0.66)
				local margin = 2.6
				gl.Rect(-margin, -margin, screenshotVars.width + margin + margin, screenshotVars.height + 15 + margin + margin)
				gl.Color(1, 1, 1, 0.025)
				gl.Rect(0, 0, screenshotVars.width, screenshotVars.height + 12 + margin + margin)

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

				font:Begin()
				font:Print("\255\160\160\160"..screenshotVars.filename .. '.png', screenshotVars.width - 4, screenshotVars.height + 6.5, 11, "orn")
				local tc = screenshotVars.teamColor
				font:Print(string.char(255, math.floor(tc[1] * 255), math.floor(tc[2] * 255), math.floor(tc[3] * 255)) .. screenshotVars.player, 4, screenshotVars.height + 6.5, 11, "on")
				font:End()

				gl.PopMatrix()
			end)

			screenshotVars.needsTextureCreation = nil
		end

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

			-- Handle mouse interaction (click anywhere to close)
			local mouseX, mouseY, mouseButtonL = Spring.GetMouseState()
			if screenshotVars.width and mouseButtonL then
				gl.DeleteList(screenshotVars.dlist)
				screenshotVars = {}
			end
		end
	end

	function gadget:KeyPress(key, mods, isRepeat)
		if screenshotVars.dlist and key == 27 then -- 27 is Escape key
			gl.DeleteList(screenshotVars.dlist)
			screenshotVars = {}
			return true -- Consume the key event
		end
	end
end
