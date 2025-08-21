function widget:GetInfo()
  return {
    name    = "Reclaim Overlay",
    desc    = "Highlights high metal-value features in view",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 1,
    enabled = true,
  }
end

local spGetAllFeatures   = Spring.GetAllFeatures
local spGetFeatureDefID  = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spIsSphereInView   = Spring.IsSphereInView
local glColor, glDrawGroundCircle = gl.Color, gl.DrawGroundCircle

-- Tunables
local minMetal   = 30     -- hide tiny scraps
local maxDraw    = 220    -- budget per frame
local ringBase   = 60
local ringScale  = 0.8
local alpha      = 0.22

local list = {}
local lastRefresh = 0

local function refreshList()
  list = spGetAllFeatures() or {}
end

function widget:Initialize()
  refreshList()
end

function widget:Update(dt)
  -- refresh feature list every second
  local f = Spring.GetGameFrame()
  if f - lastRefresh > 30 then
    refreshList()
    lastRefresh = f
  end
end

function widget:DrawWorld()
  if not list or #list == 0 then return end

  local drawn = 0
  for i=1,#list do
    if drawn >= maxDraw then break end
    local feat = list[i]
    local fdid = spGetFeatureDefID(feat)
    local fd = FeatureDefs[fdid]
    if fd and (fd.metal or 0) >= minMetal then
      local x,y,z = spGetFeaturePosition(feat)
      if x and spIsSphereInView(x,y,z, 50) then
        local m = fd.metal or 0
        local r = ringBase + math.sqrt(m) * (ringScale*10)
        local a = math.min(0.6, alpha + (m/300)*0.18)
        glColor(0.9, 0.85, 0.2, a)
        glDrawGroundCircle(x,y,z, r, 24)
        drawn = drawn + 1
      end
    end
  end
  glColor(1,1,1,1)
end
