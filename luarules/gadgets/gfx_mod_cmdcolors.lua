function gadget:GetInfo()
  return {
    name      = "load mod cmdcolors",
    desc      = "loads cmdcolors_mod.txt located in game/mod root folder",
    author    = "Floris",
    date      = "2016",
    license   = "duck",
    layer     = -100,
    enabled   = true,
	}
end

if (gadgetHandler:IsSyncedCode()) then
	return false
end

function gadget:Initialize()
	local file = VFS.LoadFile("cmdcolors_mod.txt")
	if file then
		Spring.LoadCmdColorsConfig(file)
	end
	gadgetHandler:RemoveGadget(self)
end
