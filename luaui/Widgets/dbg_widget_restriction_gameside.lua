local side = "Gameside" -- copy to local luaui and rename to test this userside

function widget:GetInfo()
  return {
    name      = "Widget Restricton "..side,
    desc      = "Tests for widget restrictions on "..side,
    author    = "Beherith",
    date      = "2023.07.19",
    license   = "GNU GPL v2",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end
-- the test case will be the usage of GetProjectilesInRectangle
local sp = Spring.Utilities.Gametype.IsSinglePlayer()

local spGetProjectilesInRectangle  = SpringRestricted.GetProjectilesInRectangle
SpringRestricted = nil -- for some reason, sprung knows that this is a good idea, 
-- See: https://github.com/ZeroK-RTS/Zero-K/commit/c918d87822f0e1d36ae513253d4d6a6d5210c9b9

function widget:Initialize()
	Spring.Echo(side,sp, "Spring.GetProjectilesInRectangle",Spring.GetProjectilesInRectangle)
	Spring.Echo(side,sp, "SpringRestricted.GetProjectilesInRectangle", spGetProjectilesInRectangle)
end
