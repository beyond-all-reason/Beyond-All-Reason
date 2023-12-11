function gadget:GetInfo()
	return {
		name = "Custom Map Tidal",
		desc = "Sets map tidal for modoption via engine call",
		author = "",
		date = "",
		license = "Horses",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

if gadgetHandler:IsSyncedCode() then

function gadget:Initialize()
	local newTidal = Spring.GetModOptions().map_tidal
	-- set tidal doesn't u
	local tidalSpeeds = {high=23,medium=18,low=13,off=0}
	local newValue = tidalSpeeds[newTidal]
	if newValue then
		Spring.SetTidal(newValue)
	end
end

end