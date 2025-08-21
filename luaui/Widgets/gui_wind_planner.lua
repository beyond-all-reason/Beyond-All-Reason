function widget:GetInfo()
  return {
    name    = "Wind Planner",
    desc    = "Shows wind min/max, estimated average and a quick recommendation",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 1,
    enabled = true,
  }
end

local spIsGUIHidden     = Spring.IsGUIHidden
local spGetActiveCommand= Spring.GetActiveCommand
local spGetMouseState   = Spring.GetMouseState
local glColor, glRect, glText = gl.Color, gl.Rect, gl.Text

local advice, avg, minW, maxW = "", 0, 0, 0
local mouseBuildWind = false
local mouseBuildSolar = false

local function computeAdvice()
  minW = Game.windMin or 0
  maxW = Game.windMax or 0
  avg  = (minW + maxW) * 0.5
  -- Simple thresholds tuned for BAR’s typical ranges:
  -- < 1.5 poor, 1.5..2.2 mixed, > 2.2 very good (these are *engine wind units*, not e/s)
  local idx = avg
  if idx >= 2.2 then advice = "Wind very strong — prioritize Wind"
  elseif idx >= 1.5 then advice = "Wind mixed — Wind+Solar"
  else advice = "Wind weak — prefer Solar/Geo" end
end

local function isBuildOf(ud)
  if not ud then return false,false end
  local name = (ud.name or ""):lower()
  local human = (ud.humanName or ""):lower()
  local isWind  = ud.windGenerator and ud.windGenerator > 0
  local isSolar = (ud.energyMake or 0) > 0 and (not ud.tidalGenerator) and (not ud.windGenerator)
  if (name:find("wind") or human:find("wind")) then isWind = true end
  if (name:find("solar") or human:find("solar")) then isSolar = true end
  return isWind, isSolar
end

function widget:Initialize()
  computeAdvice()
end

function widget:GameFrame(f)
  if (f % 60) == 0 then computeAdvice() end
end

function widget:DrawScreen()
  if spIsGUIHidden() then return end

  -- detect if player is currently placing a build command for wind/solar
  local cmdID = spGetActiveCommand()
  mouseBuildWind, mouseBuildSolar = false, false
  if cmdID and cmdID < 0 then
    local ud = UnitDefs[-cmdID]
    if ud then
      mouseBuildWind, mouseBuildSolar = isBuildOf(ud)
    end
  end

  local x,y,w,h = 8, 8, 320, 66
  glColor(0,0,0,0.55); glRect(x,y,x+w,y+h)
  glColor(1,1,1,1)
  glText(("Wind Min/Max: %0.1f / %0.1f"):format(minW, maxW), x+8, y+h-18, 13, "n")
  glText(("Est. Average: %0.1f"):format(avg), x+8, y+h-34, 12, "n")

  local r,g,b = 0.8,0.95,0.8
  if avg < 1.5 then r,g,b = 0.95,0.7,0.7 elseif avg < 2.2 then r,g,b = 0.95,0.95,0.75 end
  if mouseBuildWind then r,g,b = 0.7,1.0,0.7 end
  if mouseBuildSolar then r,g,b = 1.0,0.9,0.6 end
  glColor(r,g,b,1)
  glText(advice, x+8, y+h-52, 12, "n")

  glColor(1,1,1,1)
end
