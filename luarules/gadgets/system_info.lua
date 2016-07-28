
function gadget:GetInfo()
	return {
		name	= "System info",
		desc	= "",
		author	= "Floris",
		date	= "July,2016",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local sendPacketEvery = 300

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,3)=="$y$" then
			SendToUnsynced("systemBroadcast",playerID,msg:sub(4))
			return true
		end
	end
	
else
	--------------------------------------------------------------------------------
	-- unsynced
	--------------------------------------------------------------------------------

	local SendLuaRulesMsg				= Spring.SendLuaRulesMsg
	local GetMyPlayerID					= Spring.GetMyPlayerID
	local myPlayerID						= GetMyPlayerID()
	local systems								= {}
	
	function lines(str)
	  local t = {}
	  local function helper(line) table.insert(t, line) return "" end
	  helper((str:gsub("(.-)\r?\n", helper)))
	  return t
	end

	function gadget:Initialize()
		local infolog = VFS.LoadFile("infolog.txt")
		if infolog then
			
			-- store changelog into array
			fileLines = lines(infolog)
			
			for i, line in ipairs(fileLines) do
				if s_os ~= nil then
				
					if s_gpu ~= nil and string.find(line, '^Video RAM:') and not string.find(line, 'unknown') then
						s_gpuVram = string.sub(line, 14)
					end
					if s_gpu == nil and string.find(line, '^GL renderer:')  then
						s_gpu = string.sub(line, 14)
					end
					if s_gpu == nil and string.find(line, '^(Supported Video modes on Display )')  then
						if s_displays == nil then 
							s_displays = ''
							ds = ''
						end
						s_displays = s_displays .. ds .. string.gsub(string.match(line, '([0-9].*)'), ':','')
						ds = '  |  '
					end
					if string.find(line, '^Physical CPU Cores:') then
						s_cpuCoresPhysical = string.match(line, '([0-9].*)')
					end
					if string.find(line, '^ Logical CPU Cores:') then
						s_cpuCoresLogical = string.match(line, '([0-9].*)')
					end
					if s_osVersion ~= nil and s_cpu == nil and s_cpuCoresPhysical == nil and (string.find(line:lower(), 'intel') or string.find(line:lower(), 'amd')) then
						s_cpu = string.match(line, '^([\+a-zA-Z0-9 ()@._-]*)')
						s_ram = string.match(line, '([0-9]*MB RAM)')
					end
					if s_osVersion == nil and cpu == nil and s_cpuCoresPhysical == nil and (string.find(line:lower(), 'microsoft') or string.find(line:lower(), 'linux') or string.find(line:lower(), 'unix')) then
						s_osVersion = line
					end
				end
				if s_configs_os == nil and string.find(line, '^Operating System:') then
					s_os = string.sub(line, 19)
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
			
			if s_os == nil then s_os = '' end
			if s_osVersion == nil then s_osVersion = '' end
			if s_cpu == nil then s_cpu = '' end
			if s_ram == nil then s_ram = '' end
			if s_cpuCoresPhysical == nil then s_cpuCoresPhysical = '' end
			if s_cpuCoresLogical == nil then s_cpuCoresLogical = '' end
			if s_displays == nil then s_displays = '' end
			if s_gpu == nil then s_gpu = '' end
			if s_gpuVram == nil then s_gpuVram = '' end
			if s_config == nil then s_config = '' end
			
			local system = 'CPU:  '..s_cpu..'\nCPU cores:  '..s_cpuCoresPhysical..' / '..s_cpuCoresLogical..'\nRAM:  '..s_ram..'\nGPU:  '..s_gpu..'\nGPU VRAM:  '..s_gpuVram..'\nDisplays:  '..s_displays..'\nOS:  '..s_os..'\nOS version:  '..s_osVersion
			
			SendLuaRulesMsg("$y$"..system)
		end
		gadgetHandler:AddSyncAction("systemBroadcast", handleSystemEvent)
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

