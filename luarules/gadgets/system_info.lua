
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "System info",
		desc	= "",
		author	= "Floris",
		date	= "July,2016",
		license = "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

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
	_G.validationSys = validation

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,3)=="$y$" and msg:sub(4,5)==validation then
			SendToUnsynced("systemBroadcast",playerID,msg:sub(6))
			return true
		end
	end

else

	local chobbyLoaded = (Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), 'chobby') ~= nil)

	local SendLuaRulesMsg = Spring.SendLuaRulesMsg
	local systems = {}
	local validation = SYNCED.validationSys

	local myPlayerID = Spring.GetMyPlayerID()
	local myPlayerName,_,_,_,_,_,_,_,_,_,accountInfo = Spring.GetPlayerInfo(myPlayerID)
	local accountID = (accountInfo and accountInfo.accountid) and tonumber(accountInfo.accountid) or -1
	local authorized = SYNCED.permissions.sysinfo[accountID]

	local function handleSystemEvent(_,playerID,system)
		if authorized then
			if Script.LuaUI("SystemEvent") then
				if systems[playerID] == nil and system ~= nil then
					systems[playerID] = system
				end
				Script.LuaUI.SystemEvent(playerID,systems[playerID])
			end
		end
	end

	local function lines(str)
		local t = {}
		local function helper(line) table.insert(t, line) return "" end
		helper((str:gsub("(.-)\r?\n", helper)))
		return t
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("systemBroadcast")
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("systemBroadcast", handleSystemEvent)
		Spring.Echo(string.format("infologVersionTags:engine=%s,game=%s,lobby=%s,map=%s",
			Engine.version or "",
			(Game.gameName or "") .. " " .. (Game.gameVersion or ""),
			(VFS and VFS.GetNameFromRapidTag and VFS.GetNameFromRapidTag("byar-chobby:test") or ""),
			Game.mapName or ""
		))

		local myvalidation = validation

		local s_cpu, s_gpu, s_gpuVram, s_ram, s_os, s_resolution, s_displaymode, s_displays, s_config, s_configs_os, s_cpuCoresLogical, s_cpuCoresPhysical, ds, nl, configEnd

		if Engine ~= nil and Platform ~= nil then	-- v104
			if Platform.gpu ~= nil then
				s_gpu = Platform.gpu
				s_gpu = string.gsub(s_gpu, "/PCIe", "")
				s_gpu = string.gsub(s_gpu, "/SSE2", "")
				s_gpu = string.gsub(s_gpu, " Series", "")
				s_gpu = string.gsub(s_gpu, "%((.*)%)", "")
				s_gpu = string.gsub(s_gpu, "Gallium ([0-9].*) on ", "")
				if Platform.gpuVendor == 'Nvidia' or Platform.gpuMemorySize and Platform.gpuMemorySize > 10 then
					s_gpuVram = math.floor(Platform.gpuMemorySize/1000)..'MB'
				end
			end
			if Platform.osFamily ~= nil then
				s_os = Platform.osFamily
				if Platform.osVersion ~= nil then
					s_os = s_os .. ' ' .. Platform.osVersion
				end
			end

			if Platform.hwConfig ~= nil then
				s_cpu = string.match(Platform.hwConfig, '([%+a-zA-Z0-9 ()@._-]*)')
				s_cpu = string.gsub(s_cpu, " Processor", "")
				s_cpu = string.gsub(s_cpu, " Eight[-]Core", "")
				s_cpu = string.gsub(s_cpu, " Six[-]Core", "")
				s_cpu = string.gsub(s_cpu, " Quad[-]Core", "")
				s_cpu = string.gsub(s_cpu, " CPU", "")
				s_cpu = string.gsub(s_cpu, "%((.*)%)", "")
				s_ram = string.match(Platform.hwConfig, '([0-9]*MB RAM)')
				if s_ram ~= nil then
					s_ram = string.gsub(s_ram, " RAM", "")
				end
			end
			if Platform.availableVideoModes then
				local maxheight = 0
				local maxwidth = 0
				for i, mode in pairs(Platform.availableVideoModes) do
					if mode.h > maxheight then maxheight = mode.h end
					if mode.w > maxwidth then maxwidth = mode.h end
				end
				s_resolution = tostring(maxwidth) .. 'x' .. tostring(maxheight)
			end
		end

		local infolog = VFS.LoadFile("infolog.txt")
		if infolog then

			local fileLines = lines(infolog)
			for i, line in ipairs(fileLines) do

				if string.sub(line, 1, 3) == '[F='  then
					break
				end

				-- Spring v104
				if s_gpu ~= nil and string.match(line, 'current=%{[0-9]*x[0-9]*') then
					s_resolution = string.sub(string.match(line, 'current=%{[0-9]*x[0-9]*'), 10)
				end

				if line:find('(display%-mode set to )') then
					s_displaymode = line:sub( line:find('(display%-mode set to )') + 20)
					if s_displaymode:find('%(') then
						local basepart = s_displaymode:sub(1, s_displaymode:find('%(')-1)
						if s_displaymode:find('windowed::borderless') then
							s_displaymode = basepart..'borderless'
						elseif s_displaymode:find('windowed::decorated') then
							s_displaymode = basepart..' windowed'
						elseif s_displaymode:find('fullscreen::decorated') then
							s_displaymode = basepart..' fullscreen'
						end
					end
				end

				if s_gpu == nil and string.find(line, '(Supported Video modes on Display )')  then
					if s_displays == nil then
						s_displays = ''
						ds = ''
					end
					s_displays = s_displays .. ds .. string.gsub(string.match(line, '([0-9].*)'), ':','')
					ds = '  |  '
				end
				if string.find(line, 'Physical CPU Cores') then
					s_cpuCoresPhysical = string.match(string.sub(line, string.len(line)-10), '([0-9].*)')
				end
				if string.find(line, 'Logical CPU Cores') then
					s_cpuCoresLogical = string.match(string.sub(line, string.len(line)-10), '([0-9].*)')
				end
				if string.find(line:lower(), 'hardware config: ') then
					s_cpu = string.sub(line, select(2, string.find(line:lower(), 'hardware config: ')))
					s_cpu = string.match(s_cpu, '([%+a-zA-Z0-9 ()@._-]*)')
					s_cpu = string.gsub(s_cpu, " Processor", "")
					s_cpu = string.gsub(s_cpu, " Eight[-]Core", "")
					s_cpu = string.gsub(s_cpu, " Six[-]Core", "")
					s_cpu = string.gsub(s_cpu, " Quad[-]Core", "")
					s_cpu = string.gsub(s_cpu, " CPU", "")
					s_cpu = string.gsub(s_cpu, "%((.*)%)", "")
					s_ram = string.match(line, '([0-9]*MB RAM)')
					if s_ram ~= nil then
						s_ram = string.gsub(s_ram, " RAM", "")
					end
				end
				if string.find(line:lower(), 'operating system: ') then
					s_os = string.sub(line, select(2, string.find(line:lower(), 'operating system: ')))
				end

				--if s_os == nil and s_configs_os == nil and string.find(line, 'Operating System:') then
				--	local charStart = string.find(line, 'Operating System:')
				--	s_os = string.sub(line, 18 + charStart)
				--end

				if s_config ~= nil and configEnd == nil and line == '============== </User Config> ==============' then
					configEnd = true
				end
				if  s_config ~= nil and configEnd == nil then
					s_config = s_config..nl..line
					nl = '\n'
				end
				if s_config == nil and line == '============== <User Config> ==============' then
					s_config = ''
					nl = ''
				end
			end
		end

		if s_os then
			if string.find(s_os, 'Windows') then	-- simplyfy, also for some privacy (hiding build number)
				s_os = string.match(s_os, "(Windows [0-9.]*)")
			elseif string.find(s_os, 'Linux') then	-- simplyfy, also for some privacy (hiding build number)
				s_os = 'Linux'
			end
		end

		local system = ''
		if s_cpu ~= nil then
			system = system..'\nCPU:  '..string.gsub(s_cpu, "  ", " ")
		end
		if s_cpuCoresPhysical ~= nil then
			system = system..'\nCPU cores:  '..s_cpuCoresPhysical..' / '..s_cpuCoresLogical
		end
		if s_ram ~= nil then
			system = system..'\nRAM:  '..string.gsub(s_ram, "  ", " ")
		end
		if s_gpu ~= nil then
			system = system..'\nGPU:  '..string.gsub(s_gpu, "  ", " ")
		end
		if s_gpuVram ~= nil then
			system = system..'\nGPU VRAM:  '..string.gsub(s_gpuVram, "  ", " ")
		end
		if s_resolution ~= nil then
			system = system..'\nDisplay max: '..string.gsub(s_resolution, "  ", " ")
		end
		if s_displaymode ~= nil then
			system = system..'\n'..s_displaymode
		end

		if s_os ~= nil then
			system = system..'\nOS:  '..s_os
		end

		if chobbyLoaded then
			system = system..'\nLobby:  Chobby'
		end

		system = string.sub(system, 2)
		if system ~= '' then
			SendLuaRulesMsg("$y$"..myvalidation..system)
		end
	end

	function gadget:MapDrawCmd(playerID, cmdType, px, py, pz, labelText)
		if playerID == myPlayerID and cmdType == 'point' and string.len(labelText) > 2 then
			local msg = string.format("m@pm@rk%s:%d:%d:%d:%d:%s:%s",
				validation,
				Spring.GetGameFrame(),
				playerID, px, pz,
				myPlayerName, labelText)
			SendLuaRulesMsg(msg)
		end
	end

	function gadget:GamePaused(playerID, isPaused)
		if playerID == myPlayerID then
			local msg = string.format("p@u$3:%s", tostring(isPaused))
			SendLuaRulesMsg(msg)
		end
	end

end

