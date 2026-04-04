local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Area Mex",
		desc = ".",
		author = "",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

function gadget:Initialize()
	SpringUnsynced.AssignMouseCursor("upgmex", "cursorupgmex", false)
	SpringUnsynced.AssignMouseCursor("areamex", "cursorareamex", false)
end
