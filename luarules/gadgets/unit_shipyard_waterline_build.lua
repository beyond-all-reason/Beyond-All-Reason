function gadget:GetInfo()
	return {
		name = "Shipyards Build at Waterline",
		desc = "Move the build position depending on unit needs.",
		author = "robert the pie",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return false end


local shipyardsDefIDPads	= {}
local shipyardsDefIDWaterlines	= {}
local subDefIDs		= {}
do
	local shipyardsNamesToPads = {
		corsy = 4,
		corasy = 8,
		armsy = 14,
		armasy = 2,
	}
	for name, pad in pairs(shipyardsNamesToPads) do
		if UnitDefNames[name] then
			shipyardsDefIDPads[UnitDefNames[name].id] = pad
			shipyardsDefIDWaterlines[UnitDefNames[name].id] = UnitDefNames[name].waterline
		end
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.waterline and unitDef.minWaterDepth and unitDef.waterline >= 30 then
		subDefIDs[unitDefID] = (unitDef.waterline)
	end
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
-- allow unit creation is called before and not after, otherwise only consecutive builds are adjusted, for some reason
--function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local builderDefID = Spring.GetUnitDefID(builderID)
	if shipyardsDefIDPads[builderDefID] then
		local piece = shipyardsDefIDPads[builderDefID]
		local waterDebth = subDefIDs[unitDefID]
		if waterDebth then
			waterDebth = waterDebth + shipyardsDefIDWaterlines[builderDefID]
			waterDebth = waterDebth / 8
		else
			waterDebth = 0
		end
		Spring.SetUnitPieceMatrix(builderID, piece, {
			1,0,0,0,
			0,1,0,0,
			0,0,1,0,
			0,waterDebth,0,1}
		)
	end
	return true
end
