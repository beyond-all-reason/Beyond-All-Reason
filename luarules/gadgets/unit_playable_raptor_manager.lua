local modoptions = Spring.GetModOptions()
if modoptions.playablerapotrs ~= true and modoptions.forceallunits ~= true then
	return false
end

function gadget:GetInfo()
	return {
		name = "Playable Raptor Manager",
		desc = "Manages gameplay mechanics/behaviors unique to Playable Raptors",
		author = "robert the pie",
		date = "9th of March, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local foundling			= {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.prap_foundling then
		foundling[unitDefID] = true
	end
end
if gadgetHandler:IsSyncedCode() then
-- Synced Space
function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
		local builderDefID = builderID and Spring.GetUnitDefID(builderID)
		if foundling[builderDefID] then
			Spring.SetUnitHealth(unitID, {health=2,build=1})
			Spring.DestroyUnit(builderID, false, true)
		end
end
else
-- Unsynced Space

end