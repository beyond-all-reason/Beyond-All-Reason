
function addon:GetInfo()
  return {
    name      = "Engine Taskbar Stuff",
    desc      = 'Icon, name',
    author    = "KingRaptor",
    date      = "13 July 2011",
    license   = "Public Domain",
    layer     = -math.huge,
    enabled   = true,
  }
end

function addon:Initialize()
	SpringUnsynced.SetWMIcon("bitmaps/logo.png", true)
	SpringUnsynced.SetWMCaption(Game.gameName .. " (Spring " .. ((Game and Game.version) or (Engine and Engine.version) or "") .. ")", Game.modName)
end
