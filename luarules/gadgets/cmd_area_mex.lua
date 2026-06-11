local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Mex",
		desc = ".",
		author = "",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

function gadget:Initialize()
	Engine.Unsynced.AssignMouseCursor("upgmex", "cursorupgmex", false)
	Engine.Unsynced.AssignMouseCursor("areamex", "cursorareamex", false)
end
