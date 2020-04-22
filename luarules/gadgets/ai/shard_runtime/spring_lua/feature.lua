
ShardSpringFeature = class(function(a)
   --
end)


function ShardSpringFeature:Init( id )
	self.id = id
	self.defID = Spring.GetFeatureDefID(id)
	self.def = FeatureDefs[self.defID]
	self.name = self.def.name
end

function ShardSpringFeature:ID()
	return self.id
end

function ShardSpringFeature:Name()
	return self.name
end

function ShardSpringFeature:GetPosition()
	local x, y, z = Spring.GetFeaturePosition(self.id)
	return {x=x, y=y, z=z}
end