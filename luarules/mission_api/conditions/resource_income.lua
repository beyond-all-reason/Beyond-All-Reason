local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Return value indices as on https://recoilengine.org/docs/lua-api/#Spring.GetTeamResources
local RESOURCE_INCOME_INDEX   = 4
local RESOURCE_RECEIVED_INDEX = 8  -- resources received from allied teams via sharing

local function getTeamResourceIncomeForSources(teamID, resourceType, sources, context)
	local extractorIncome  = 0
	local reclaimIncome    = 0
	local productionIncome = 0
	local transferIncome   = 0

	if (sources.extractor or sources.production) and resourceType ~= "energy" then
		for _, unitID in pairs(Spring.GetTeamUnits(teamID)) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			if UnitDefs[unitDefID].extractsMetal > 0 then
				-- Extraction is only based on unitDef and metal spot, but we don't have the rate for when energy is low
				extractorIncome = extractorIncome + (Spring.GetUnitMetalExtraction(unitID) or 0)
			end
		end
	end

	if sources.reclaim or sources.production then
		local snapshot = context.GetReclaimIncomeSnapshot(teamID)
		reclaimIncome = snapshot and (snapshot[resourceType] or 0) or 0
	end

	if sources.production then
		local totalIncome = select(RESOURCE_INCOME_INDEX, Spring.GetTeamResources(teamID, resourceType)) or 0
		productionIncome = totalIncome - extractorIncome - reclaimIncome
	end

	if sources.transfer then
		transferIncome = select(RESOURCE_RECEIVED_INDEX, Spring.GetTeamResources(teamID, resourceType)) or 0
	end

	return (sources.extractor  and extractorIncome  or 0)
		 + (sources.reclaim    and reclaimIncome    or 0)
		 + (sources.production and productionIncome or 0)
		 + (sources.transfer   and transferIncome   or 0)
end

return {
	type = 'ResourceIncome',
	kind = 'metric',
	parameters = {
		{ name = 'teamID',   required = true, type = ParameterTypes.TeamID },
		{ name = 'resource', required = true, type = ParameterTypes.Resource },
		-- Filter income by sources: 'extractor' (metal only), 'reclaim' (features + units), 'transfer' (shared), 'production' (everything else)
		-- Example: sources = { 'extractor', 'production' }
		{ name = 'sources', required = false, type = ParameterTypes.ResourceIncomeSources },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			-- Income is accounted once per second.
			if frameNumber % Game.gameSpeed ~= 0 then
				return
			end

			local resource = trigger.parameters.resource
			local sources = trigger.parameters.sources
			local income

			if sources == nil then
				-- Unfiltered: use the engine's total income (index 4).
				income = select(RESOURCE_INCOME_INDEX, Spring.GetTeamResources(trigger.parameters.teamID, resource)) or 0
			else
				income = getTeamResourceIncomeForSources(trigger.parameters.teamID, resource, sources, context)
			end

			context.EvaluateMetric(trigger, income)
		end,
	},
}
