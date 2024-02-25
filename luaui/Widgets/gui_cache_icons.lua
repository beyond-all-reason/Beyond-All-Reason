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

local startUnits = { UnitDefNames.armada_commander.id, UnitDefNames.cortex_commander.id }
if Spring.GetModOptions().experimentallegionfaction then
    startUnits[#startUnits+1] = UnitDefNames.legcom.id
end
local startBuildOptions = {}
for i, uDefID in pairs(startUnits) do
    startBuildOptions[#startBuildOptions+1] = uDefID
    for u, buildoptionDefID in pairs(UnitDefs[uDefID].buildOptions) do
        startBuildOptions[#startBuildOptions+1] = buildoptionDefID
    end
end
startUnits = nil

local iconTypes = VFS.Include("gamedata/icontypes.lua")

local vsx, vsy = Spring.GetViewGeometry()

-- load all icons to prevent briefly showing white unit icons (will happen due to the custom texture filtering options)
-- load time armada+cortex = 0.7 seconds (excluding legion,raptors,scavs) tested with Tracy (pc: RTX4070 + 7800X3D)
-- only loading armada/cortex start units buildoptions = 45ms, loading the rest gets delayed
local delayedCachePos = 0
local cacheIconsPerFrame = 3
local nonStartUnitCacheDelay = 6	-- apply delay or it will load during loadscreen still
local function cacheUnitIcons()
    local excludeScavs = not (Spring.Utilities.Gametype.IsScavengers() or Spring.GetModOptions().experimentalextraunits)
    local excludeRaptors = not Spring.Utilities.Gametype.IsRaptors()
    local excludeLegion = not Spring.GetModOptions().experimentallegionfaction
    gl.Translate(-vsx,0,0)
    gl.Color(1, 1, 1, 0.001)
    for id, unit in pairs(UnitDefs) do
        if not excludeScavs or not string.find(unit.name,'_scav') then
            if not excludeRaptors or not string.find(unit.name,'raptor') then
                if not excludeLegion or string.sub(unit.name, 1, 3) ~= 'leg' then
                    if startBuildOptions[id] then
                        gl.Texture('#'..id)
                        gl.TexRect(-1, -1, 0, 0)
                        if iconTypes[id] and iconTypes[id].bitmap then
                            gl.Texture(':l:' .. iconTypes[id].bitmap)
                            gl.TexRect(-1, -1, 0, 0)
                        end
                    else
                        if not delayedCacheUnitIcons then
                            delayedCacheUnitIcons = {}
                            delayedCacheUnitIconsTimer = os.clock() + nonStartUnitCacheDelay	-- apply delay or it will load during loadscreen still
                        end
                        delayedCacheUnitIcons[#delayedCacheUnitIcons+1] = id
                    end
                end
            end
        end
    end
    gl.Color(1, 1, 1, 1)
    gl.Translate(vsx,0,0)
end

function widget:DrawScreen()
    if not delayedCacheUnitIcons and Spring.GetGameFrame() > 0 then
        widgetHandler:RemoveWidget()
        return
    end
    if delayedCacheUnitIcons and os.clock() > delayedCacheUnitIconsTimer then
        gl.Translate(-vsx,0,0)
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
                gl.Texture('#'..id)
                gl.TexRect(-1, -1, 0, 0)
                if iconTypes[id] and iconTypes[id].bitmap then
                    gl.Texture(':l:' .. iconTypes[id].bitmap)
                    gl.TexRect(-1, -1, 0, 0)
                end
            end
        end
        gl.Color(1, 1, 1, 1)
        gl.Translate(vsx,0,0)
    end

    if (not cachedUnitIcons) and Spring.GetGameFrame() == 0 then
        cachedUnitIcons = true
        cacheUnitIcons()
    end
end
