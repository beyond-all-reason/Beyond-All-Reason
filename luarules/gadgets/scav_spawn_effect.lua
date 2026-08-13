local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scav Spawn Effect",
		desc = "Handles picking Scav spawn effects so we don't need to figure that out everywhere",
		author = "Damgam",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then -- Synced
	local function getUnitSize(unitDefID)
		if UnitDefs[unitDefID] then
			local size = math.ceil((UnitDefs[unitDefID].xsize / 2 + UnitDefs[unitDefID].zsize / 2) / 2)
			if size > 4.5 then
				return "huge"
			elseif size > 3.5 then
				return "large"
			elseif size > 2.5 then
				return "medium"
			elseif size > 1.5 then
				return "small"
			else
				return "tiny"
			end
		else
			return "small"
		end
	end

	local function getFeatureSize(featureDefID)
		if FeatureDefs[featureDefID] then
			local size = math.ceil((FeatureDefs[featureDefID].xsize / 2 + FeatureDefs[featureDefID].zsize / 2) / 2)
			if size > 4.5 then
				return "huge"
			elseif size > 3.5 then
				return "large"
			elseif size > 2.5 then
				return "medium"
			elseif size > 1.5 then
				return "small"
			else
				return "tiny"
			end
		else
			return "small"
		end
	end

	---Plays the scavenger spawn explosion at a unit, sized from its unit definition.
	---@param unitID integer
	function ScavengersSpawnEffectUnitID(unitID)
		local posx, posy, posz = Spring.GetUnitPosition(unitID)
		local unitDefID = Spring.GetUnitDefID(unitID)
		local size = getUnitSize(unitDefID)
		Spring.SpawnCEG("scav-spawnexplo-" .. size, posx, posy, posz, 0, 0, 0)
	end
	GG.ScavengersSpawnEffectUnitID = ScavengersSpawnEffectUnitID

	---Plays the scavenger spawn explosion at a position, sized from a unit definition.
	---@param unitDefID integer
	---@param posx number
	---@param posy number
	---@param posz number
	function ScavengersSpawnEffectUnitDefID(unitDefID, posx, posy, posz)
		local size = getUnitSize(unitDefID)
		Spring.SpawnCEG("scav-spawnexplo-" .. size, posx, posy, posz, 0, 0, 0)
	end
	GG.ScavengersSpawnEffectUnitDefID = ScavengersSpawnEffectUnitDefID

	---Plays the scavenger spawn explosion at a feature, sized from its feature definition.
	---@param featureID integer
	function ScavengersSpawnEffectFeatureID(featureID)
		local posx, posy, posz = Spring.GetFeaturePosition(featureID)
		local featureDefID = Spring.GetFeatureDefID(featureID)
		local size = getFeatureSize(featureDefID)
		Spring.SpawnCEG("scav-spawnexplo-" .. size, posx, posy, posz, 0, 0, 0)
	end
	GG.ScavengersSpawnEffectFeatureID = ScavengersSpawnEffectFeatureID

	---Plays the scavenger spawn explosion at a position, sized from a feature definition.
	---@param featureDefID integer
	---@param posx number
	---@param posy number
	---@param posz number
	function ScavengersSpawnEffectFeatureDefID(featureDefID, posx, posy, posz)
		local size = getFeatureSize(featureDefID)
		Spring.SpawnCEG("scav-spawnexplo-" .. size, posx, posy, posz, 0, 0, 0)
	end
	GG.ScavengersSpawnEffectFeatureDefID = ScavengersSpawnEffectFeatureDefID
end
