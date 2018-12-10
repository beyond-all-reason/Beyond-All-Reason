if not gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo() return {
	name    = "Global LoS modoption", -- in case somebody didnt realize
	enabled = Spring.GetModOptions().globallos == "1",
} end

function gadget:Initialize()
	for i, allyTeamID in pairs (Spring.GetAllyTeamList()) do
		Spring.SetGlobalLos (allyTeamID, true)
	end
end