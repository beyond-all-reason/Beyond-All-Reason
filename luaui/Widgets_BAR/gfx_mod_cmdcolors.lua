function widget:GetInfo()
  return {
    name      = "BA cmdcolors",
    desc      = "Sets custom BA cmdcolors, disable to load engine defaults again",
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
end

function widget:Shutdown()
	local file = VFS.LoadFile("cmdcolors.txt")
	if file then
		Spring.LoadCmdColorsConfig(file)
	end
end
