function widget:GetInfo()
  return {
    name      = "Logo adjuster",
    desc      = "Changes taskbar logo",
    author    = "Floris",
    date      = "June 2021",
    layer     = 0,
    enabled   = true,
  }
end

function widget:Initialize()
    Spring.SetWMIcon("bitmaps/logo_battle.png")
end

function widget:Shutdown()
    Spring.SetWMIcon("bitmaps/logo.png")
end
