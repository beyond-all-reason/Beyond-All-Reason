
local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Cache Icons",
    desc      = "loads all icons to prevent briefly showing white unit icons in things like the buildmenu",
    author    = "Floris",
    date      = "June 2023",
    license   = "GNU GPL, v2 or later",
    layer     = -9999999,
    enabled   = true
  }
end


local iconTypes = VFS.Include("gamedata/icontypes.lua")
local vsx, vsy = Spring.GetViewGeometry()
local delayedCacheUnitIcons
local delayedCacheUnitIconsTimer = 0
local cachedUnitIcons = false


local startUnits = { UnitDefNames.armcom.id, UnitDefNames.corcom.id }
if Spring.GetModOptions().experimentallegionfaction then
	startUnits[#startUnits + 1] = UnitDefNames.legcom.id
end
local startBuildOptions = {}
for i, uDefID in pairs(startUnits) do
	startBuildOptions[#startBuildOptions + 1] = uDefID
	for u, buildoptionDefID in pairs(UnitDefs[uDefID].buildOptions) do
		startBuildOptions[#startBuildOptions + 1] = buildoptionDefID
	end
end
startUnits = nil


local function loadToTexture(id)
	gl.Texture('#' .. id)
	gl.TexRect(-1, -1, 0, 0)
	if iconTypes[id] and iconTypes[id].bitmap then
		gl.Texture(':l:' .. iconTypes[id].bitmap)
		gl.TexRect(-1, -1, 0, 0)
	end
end


-- load all icons to prevent briefly showing white unit icons (will happen due to the custom texture filtering options)
-- load time armada+cortex = 0.7 seconds (excluding legion,raptors,scavs) tested with Tracy (pc: RTX4070 + 7800X3D)
-- only loading armada/cortex start units buildoptions = 45ms, loading the rest gets delayed
local delayedCachePos = 0
local cacheIconsPerFrame = 3
local nonStartUnitCacheDelay = 6    -- apply delay or it will load during loadscreen still
local function cacheUnitIcons()
	gl.Translate(-vsx, 0, 0)
	gl.Color(1, 1, 1, 0.001)
	for id, unit in pairs(UnitDefs) do
		if startBuildOptions[id] then
			loadToTexture(id)  -- loading starting icons ASAP
		else
			if not delayedCacheUnitIcons then
				delayedCacheUnitIcons = {}
				delayedCacheUnitIconsTimer = os.clock() + nonStartUnitCacheDelay    -- apply delay or it will load during loadscreen still
			end
			delayedCacheUnitIcons[#delayedCacheUnitIcons + 1] = id
		end

	end
	gl.Color(1, 1, 1, 1)
	gl.Translate(vsx, 0, 0)
end


function widget:DrawScreen()
	if not delayedCacheUnitIcons and Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
		return
	end
	if delayedCacheUnitIcons and os.clock() > delayedCacheUnitIconsTimer then
		gl.Translate(-vsx, 0, 0)
		gl.Color(1, 1, 1, 0.001)
		local id
		for i = 1, cacheIconsPerFrame, 1 do
			delayedCachePos = delayedCachePos + 1
			id = delayedCacheUnitIcons[delayedCachePos]
			if not id then
				delayedCacheUnitIcons = nil
				widgetHandler:RemoveWidget()
				break
			else
				loadToTexture(id)
			end
		end
		gl.Color(1, 1, 1, 1)
		gl.Translate(vsx, 0, 0)
	end

	if (not cachedUnitIcons) and Spring.GetGameFrame() == 0 then
		cachedUnitIcons = true
		cacheUnitIcons()
	end
end
