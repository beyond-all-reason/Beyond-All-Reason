-- How capable this machine is, which decides what the settings offer and what a first launch sets.
local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize or 0) / 1000 -- gpuMemorySize is in KB (only Nvidia reports nonzero), /1000 ≈ MB
local glRendererLower = Platform.glRenderer and string.lower(Platform.glRenderer) or ""

if not Platform.glHaveGL4 then
	-- No GL4 support means the engine can't use modern rendering paths
	isPotatoGpu = true
elseif Platform.glHaveNVidia then
	-- Nvidia reliably reports gpuMemorySize; < ~2.5 GB VRAM = low-end
	if gpuMem > 0 and gpuMem < 2500 then
		isPotatoGpu = true
	end
elseif Platform.glHaveIntel then
	-- All Intel GPUs are integrated except the Arc series (discrete)
	-- Integrated: "Intel(R) HD Graphics ...", "Intel(R) UHD Graphics ...", "Intel(R) Iris ..."
	-- Discrete:   "Intel(R) Arc(TM) A770", "Intel(R) Arc(TM) B580", etc.
	if not string.find(glRendererLower, "arc") then
		isPotatoGpu = true
	end
elseif Platform.glHaveAMD then
	-- AMD discrete GPUs contain "RX" (modern, 2016+) or "R9" (older high-end) in their name
	-- Integrated: "AMD Radeon(TM) Graphics", "AMD Radeon Vega 8", "AMD Radeon 780M", etc.
	-- gpuMemorySize is 0 for AMD so we can't use VRAM size
	if not (string.find(glRendererLower, "rx") or string.find(glRendererLower, "r9 ")) then
		isPotatoGpu = true
		gpuMem = 0 -- AMD integrated can report incorrect gpuMemorySize, so set to 0 to avoid false positives for low VRAM
	end
elseif string.find(glRendererLower, "apple m") then
	-- Apple Silicon via zink reports vendor Mesa: "zink Vulkan 1.3(Apple M3 Max (MESA_KOSMICKRISP))"
else
	-- Unknown/Mesa vendor without specific detection — assume low-end
	isPotatoGpu = true
end

local hardware = { isPotatoCpu = false, isPotatoGpu = isPotatoGpu, gpuMem = gpuMem }

-- the start of infolog.txt, which this reads, does not change while the game runs
local infologRead = false
function hardware.readInfolog()
	if infologRead then
		return
	end
	infologRead = true
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = string.lines(infolog)
		for i, line in ipairs(fileLines) do
			-- scan for shader version error
			if string.find(line, "error: GLSL 1.50 is not supported", nil, true) then
				Spring.SetConfigInt("LuaShaders", 0)
			end

			-- look for system hardware
			if string.find(line, "Physical CPU Cores", nil, true) then
				if tonumber(string.match(line, "([0-9].*)")) and tonumber(string.match(line, "([0-9].*)")) <= 2 then
					hardware.isPotatoCpu = true
				end
			end

			if string.find(line, "Logical CPU Cores", nil, true) then
				if tonumber(string.match(line, "([0-9].*)")) and tonumber(string.match(line, "([0-9].*)")) <= 2 then
					hardware.isPotatoCpu = true
				end
			end

			if string.find(line:lower(), "hardware config: ", nil, true) then
				local s_ram = string.match(line, "([0-9]*MB RAM)")
				if s_ram ~= nil then
					s_ram = string.gsub(s_ram, " RAM", "")
					if tonumber(s_ram) and tonumber(s_ram) > 0 and tonumber(s_ram) < 6500 then
						hardware.isPotatoCpu = true
					end
				end
			end

			if string.find(line, "Loading widget:", nil, true) then
				break
			end
		end
	end
end

return hardware
