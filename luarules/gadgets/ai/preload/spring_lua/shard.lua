local Shard = {}

Shard.resourceIds = { "metal", "energy" }
Shard.resourceKeyAliases = {
	currentLevel = "reserves",
	storage = "capacity",
	expense = "usage",
}
Shard.unitsByID = {}
Shard.unittypesByID = {}
Shard.featuresByID = {}

function Shard:shardify_resource(luaResource)
	local shardResource = {}
	for key, value in pairs(luaResource) do
		local newKey = self.resourceKeyAliases[key] or key
		shardResource[newKey] = value
	end
	return shardResource
end

function Shard:shardify_unit( unitID )
	if not unitID then return end
	if not self.unitsByID[unitID] then
		local unit = ShardSpringUnit()
		unit:Init(unitID)
		self.unitsByID[unitID] = unit
	end
	return self.unitsByID[unitID]
end

function Shard:unshardify_unit( unitID )
	if not unitID then return end
	self.unitsByID[unitID] = nil
end

function Shard:shardify_unittype( unitDefID )
	if not unitDefID then return end
	if not self.unittypesByID[unitDefID] then
		local unittype = ShardSpringUnitType()
		unittype:Init(unitDefID)
		self.unittypesByID[unitDefID] = unittype
	end
	return self.unittypesByID[unitDefID]
end

function Shard:shardify_damage( damage, weaponDefID, paralyzer, projectileID, engineAttacker )
 	local sharddamage = ShardSpringDamage()
	sharddamage:Init(damage, weaponDefID, paralyzer, projectileID, engineAttacker)
 	return sharddamage
end

function Shard:shardify_feature( featureID )
	if not featureID then return end
	if not self.featuresByID[featureID] then
		local shardfeature = ShardSpringFeature()
		shardfeature:Init(featureID)
		self.featuresByID[featureID] = shardfeature
	end
	return self.featuresByID[featureID]
end

function Shard:unshardify_feature( featureID )
	if not featureID then return end
	self.featuresByID[featureID] = nil
end

return Shard