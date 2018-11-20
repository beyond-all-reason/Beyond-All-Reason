
----------------------------------------------------------------
-- global variables
----------------------------------------------------------------
local versionNumber = "v1.3"
local delay = 8
local mousemovedDelay = 60
local endTime
local mx,my
local mousemoved = false

----------------------------------------------------------------
-- speedups
----------------------------------------------------------------
local DiffTimers = Spring.DiffTimers
local GetTimer = Spring.GetTimer
local SendCommands = Spring.SendCommands
local Echo = Spring.Echo
local GetMouseState = Spring.GetMouseState

----------------------------------------------------------------
-- callins
----------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Autoquit",
    desc      = versionNumber .. " Automatically quits "..delay.."s after the game ends. Move mouse to postpone. (every "..mousemovedDelay.." seconds) ",
    author    = "Evil4Zerggin & zwzsg",
    date      = "25 December 2008",
    license   = "GNU LGPL, v2.1 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

function widget:Initialize()
  endTime = false
end

function widget:GameOver()
  endTime = GetTimer()
  mx,my = GetMouseState()
  Echo("<autoquit> Automatically exiting in " .. delay .. " seconds. Move mouse to postpone the quit for "..mousemovedDelay.." seconds")
end

function widget:Update(dt)
  if endTime then
    local nmx,nmy = GetMouseState()
    if nmx~=mx or nmy~=my then
      mousemoved = true
      endTime = GetTimer()  -- set new endtime, because I've had times that game was running for ages because i wasnt attending pc but somehow it detect a move
      mx,my = GetMouseState()
    elseif not mousemoved and DiffTimers(GetTimer(), endTime) > delay then
      Echo("<autoquit> Autoquit sending quit command.")
      SendCommands("quitforce")
    elseif mousemoved and DiffTimers(GetTimer(), endTime) > mousemovedDelay then
      Echo("<autoquit> Autoquit sending quit command.")
      SendCommands("quitforce")
    end
  end
end
