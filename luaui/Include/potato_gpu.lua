-- Detects low-end graphics: no GL4 support, little video memory, or an integrated GPU.

local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize or 0) / 1000 -- gpuMemorySize is in KB. Only Nvidia reports nonzero.
local glRendererLower = Platform.glRenderer and string.lower(Platform.glRenderer) or ""

if not Platform.glHaveGL4 then
	isPotatoGpu = true
elseif Platform.glHaveNVidia then
	-- ~2.5 GB VRAM = low-end
	isPotatoGpu = gpuMem > 0 and gpuMem < 2500
elseif Platform.glHaveIntel then
	-- Discrete:   "Intel(R) Arc(TM) A770", "Intel(R) Arc(TM) B580", etc.
	-- Integrated: "Intel(R) HD Graphics ...", "Intel(R) UHD Graphics ...", "Intel(R) Iris ..."
	isPotatoGpu = not string.find(glRendererLower, "arc")
elseif Platform.glHaveAMD then
	-- Discrete:   "RX" (2016+) or "R9" (older high-end)
	-- Integrated: "AMD Radeon(TM) Graphics", "AMD Radeon Vega 8", "AMD Radeon 780M", etc.
	-- gpuMemorySize is 0 for AMD so we can't use VRAM size
	if not (string.find(glRendererLower, "rx") or string.find(glRendererLower, "r9 ")) then
		isPotatoGpu = true
		gpuMem = 0 -- AMD integrated reports incorrect gpuMemorySize, so set to 0 to ignore.
	end
elseif string.find(glRendererLower, "apple m") then
	-- Apple Silicon via zink reports vendor Mesa: "zink Vulkan 1.3(Apple M3 Max (MESA_KOSMICKRISP))"
else
	isPotatoGpu = true
end

return {
	isPotatoGpu = isPotatoGpu,
	gpuMem = gpuMem,
}
