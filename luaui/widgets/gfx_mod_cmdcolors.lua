function widget:GetInfo()
  return {
    name      = "BA cmdcolors",
    desc      = "loads cmdcolors.txt from BA (loads at start, disable to have engine default for next launch)",
    author    = "Floris",
    date      = "2016",
    license   = "parrot",
    layer     = -100,
    enabled   = true,
	}
end

function widget:Initialize()
	local file = VFS.LoadFile("cmdcolors_mod.txt")
	if file then
		Spring.LoadCmdColorsConfig(file)
	end
	widgetHandler:RemoveWidget()
end
