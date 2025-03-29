local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Persistent Build Spacing",
    desc      = "Recalls last build spacing set for each building and game [v2.0]",
    author    = "Niobium & DrHash",
    date      = "Sep 6, 2011",
    license   = "GNU GPL, v3 or later",
    layer     = 0,
    enabled   = true
  }
end

local defaultSpacing = 0
local maxBuildSpacing = 16 -- you can still increase build spacing, it just will clamp the remembrance of it

local lastCmdID = nil
local buildSpacing = {}

local spGetActiveCommand = Spring.GetActiveCommand
local spGetBuildSpacing = Spring.GetBuildSpacing
local spSetBuildSpacing = Spring.SetBuildSpacing

local unitNames = {}
for udid, ud in pairs(UnitDefs) do
    unitNames[udid] = ud.name
end

function widget:Update()
    local _, cmdID = spGetActiveCommand()
    if cmdID and cmdID < 0 then
        if cmdID ~= lastCmdID then
            spSetBuildSpacing(math.min(maxBuildSpacing, buildSpacing[unitNames[-cmdID]] or defaultSpacing))
            lastCmdID = cmdID
        end
		buildSpacing[unitNames[-cmdID]] = spGetBuildSpacing()
    end
end

function widget:GetConfigData()
    return { buildSpacing = buildSpacing }
end

function widget:SetConfigData(data)
    buildSpacing = data.buildSpacing or {}
    for k,v in pairs(buildSpacing) do
        if tonumber(v) == 0 then
            buildSpacing[k] = nil
        end
    end
end
