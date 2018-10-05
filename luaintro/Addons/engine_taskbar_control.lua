--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
function addon:Initialize()
	local name = Game.modName
    if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 then
        Spring.SetWMIcon("bitmaps/barlogo.png")
    else
	    Spring.SetWMIcon("bitmaps/balogo.png")
    end
	Spring.SetWMCaption(name .. " (Spring " .. ((Game and Game.version) or (Engine and Engine.version) or "") .. ")", name)
end