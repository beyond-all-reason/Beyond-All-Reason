ShardSpringDamage = class(function(a)
   --
end)

local spGetGameFrame = Spring.GetGameFrame
local spGetProjectileDirection = Spring.GetProjectileDirection
   
function ShardSpringDamage:Init( damage, weaponDefID, paralyzer, projectileID, engineAttacker )
	self.damage = damage
	self.weaponDefID = weaponDefID
	self.paralyzer = paralyzer
	self.projectileID = projectileID
	self.attacker = engineAttacker
	self.gameframe = spGetGameFrame()
	if projectileID then
		local dx, dy, dz = spGetProjectileDirection(projectileID)
		self.direction = {x=dx, y=dy, z=dz}
	end
	self.damageType = weaponDefID
	if weaponDefID then
		local weaponDef = WeaponDefs[weaponDefID]
		if weaponDef then
			self.weaponType = weaponDef.name
		end
	end
end

function ShardSpringDamage:Damage()
	return self.damage
end

function ShardSpringDamage:Attacker()
	return self.attacker
end

function ShardSpringDamage:Direction()
	return self.direction
end

function ShardSpringDamage:DamageType()
	return self.damageType
end

function ShardSpringDamage:WeaponType()
	return self.weaponType
end 