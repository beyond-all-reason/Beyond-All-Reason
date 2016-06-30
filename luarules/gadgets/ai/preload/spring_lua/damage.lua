SpringDamage = class(function(a)
   --
end)


function ShardSpringDamage:Init( damage, weaponDefId, paralyzer )
	self.damage = damage
	self.weaponDefId = weaponDefId
	self.paralyzer = paralyzer
	self.gameframe = Spring.GetGameFrame()
end

function ShardSpringDamage:Damage()
	return self.damage
end