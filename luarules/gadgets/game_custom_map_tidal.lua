if not gadgetHandler:IsSyncedCode() then return false end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Custom Map Tidal",
		desc = "Sets map tidal for modoption via engine call",
		author = "robert the pie",
		date = "December 2023",
		license = "GPLv2 or late",
		layer = 0,
		enabled = true
	}
end

function gadget:Initialize()
	local newTidal = Spring.GetModOptions().map_tidal
	local tidalSpeeds = {
		high=23,
		medium=18,
		low=13,
		unchanged=nil,
	}
	local newValue = tidalSpeeds[newTidal]
	if newValue then
		Spring.SetTidal(newValue)
	end
end