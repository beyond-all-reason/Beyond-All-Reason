
function gadget:GetInfo()
	return {
		name	= "System info",
		desc	= "",
		author	= "Floris",
		date	= "July,2016",
		layer	= 0,
		enabled = true,
	}
end

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
	_G.validationSys = validation

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,3)=="$y$" and msg:sub(4,5)==validation then
			SendToUnsynced("systemBroadcast",playerID,msg:sub(6))
			return true
		end
	end
	
else
	--------------------------------------------------------------------------------
	-- unsynced
	--------------------------------------------------------------------------------

	local SendLuaRulesMsg				= Spring.SendLuaRulesMsg
	local GetMyPlayerID					= Spring.GetMyPlayerID
	local myPlayerID					= GetMyPlayerID()
	local systems						= {}
	local validation = SYNCED.validationSys
	
	function lines(str)
	  local t = {}
	  local function helper(line) table.insert(t, line) return "" end
	  helper((str:gsub("(.-)\r?\n", helper)))
	  return t
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("systemBroadcast", handleSystemEvent)

		if (Spring.GetConfigInt("SystemPrivacy",0) or 0) == 1 then
			return
		end

		if Engine ~= nil and Platform ~= nil then	-- v104
			if Platform.gpu ~= nil then
				s_gpu = Platform.gpu
				if Platform.gpuVendor == 'Nvidia' then
					s_gpuVram = Platform.gpuMemorySize
				end
			end
			if Platform.osFamily ~= nil then
				s_os = Platform.osFamily
				if Platform.osVersion ~= nil then
					s_os = s_os .. ' ' .. Platform.osVersion
				end
			end
		end

		local infolog = VFS.LoadFile("infolog.txt")
		if infolog then

			-- store changelog into array
			fileLines = lines(infolog)

			for i, line in ipairs(fileLines) do

				if string.sub(line, 1, 3) == '[F='  then
					break
				end

				-- Spring v104
				if s_gpu ~= nil and string.match(line, 'current=\{[0-9]*x[0-9]*') then
					s_resolution = string.sub(string.match(line, 'current=\{[0-9]*x[0-9]*'), 10)
				end
				if s_gpu ~= nil and string.find(line, 'GPU memory') and not string.find(line, 'unknown') then
					s_gpuVram = string.match(line, '[0-9]*MB')
					s_gpuVram = string.gsub(s_gpuVram, "MB ", "")
					if string.find(s_gpuVram, ',') then
						s_gpuVram = string.sub(s_gpuVram, 0, string.find(s_gpuVram, ',')-1)
					end
				end

				if s_gpu == nil and string.find(line, 'GL renderer')  then
					s_gpu = string.sub(line, 14)
					s_gpu = string.gsub(s_gpu, "/PCIe", "")
					s_gpu = string.gsub(s_gpu, "/SSE2", "")
					s_gpu = string.gsub(s_gpu, " Series", "")
					s_gpu = string.gsub(s_gpu, "%((.*)%)", "")
					s_gpu = string.gsub(s_gpu, "Gallium ([0-9].*) on ", "")
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
					s_cpuCoresPhysical = string.match(line, '([0-9].*)')
				end
				if string.find(line, 'Logical CPU Cores') then
					s_cpuCoresLogical = string.match(line, '([0-9].*)')
				end
				if (string.find(line:lower(), 'hardware config')) then
					s_cpu = string.sub(line, 23)
					s_cpu = string.match(s_cpu, '([\+a-zA-Z0-9 ()@._-]*)')
					s_cpu = string.gsub(s_cpu, " Processor", "")
					s_cpu = string.gsub(s_cpu, " Eight[-]Core", "")
					s_cpu = string.gsub(s_cpu, " Six[-]Core", "")
					s_cpu = string.gsub(s_cpu, " Quad[-]Core", "")
					s_cpu = string.gsub(s_cpu, "%((.*)%)", "")
					s_ram = string.match(line, '([0-9]*MB RAM)')
					s_ram = string.gsub(s_ram, " RAM", "")
				end
				if (string.find(line:lower(), 'operating system')) then
					s_os = string.sub(line, 23)
				end
			end


			if s_os == nil and s_configs_os == nil and string.find(line, 'Operating System:') then
				local charStart = string.find(line, 'Operating System:')
				s_os = string.sub(line, 18 + charStart)
			end

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

		if string.find(s_os, 'Windows') then	-- simplyfy, also for some privacy (hiding build number)
			s_os = string.match(s_os, "(Windows [0-9.]*)")
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
			system = system..'\n'..string.gsub(s_resolution, "  ", " ")
		end
		if s_os ~= nil then
			system = system..'\nOS:  '..s_os
		end

		system = string.sub(system, 2)
		if system ~= '' then
			SendLuaRulesMsg("$y$"..validation..system)
		end
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("systemBroadcast")
	end

	function handleSystemEvent(_,playerID,system)
		if Script.LuaUI("SystemEvent") then
			if systems[playerID] == nil and system ~= nil then systems[playerID] = system end
			Script.LuaUI.SystemEvent(playerID,systems[playerID])
		end
	end

end

