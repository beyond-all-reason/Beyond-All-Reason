local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function spawnExplosion(weaponDefName, position, direction)
	direction = direction or { x = 0, y = 0, z = 0 }
	local weaponDef = WeaponDefNames[weaponDefName]
	local params = {
		weaponDef = weaponDef.id,
		owner = -1,
		damages = weaponDef.damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = weaponDef.craterAreaOfEffect,
		damageAreaOfEffect = weaponDef.damageAreaOfEffect,
		edgeEffectiveness = weaponDef.edgeEffectiveness,
		explosionSpeed = weaponDef.explosionSpeed,
		impactOnly = weaponDef.impactOnly,
		ignoreOwner = weaponDef.noSelfDamage,
		damageGround = true,
	}
	Spring.SpawnExplosion(position.x, position.y, position.z, direction.x, direction.y, direction.z, params)
end

return {
	{
		type = 'SpawnExplosion',
		parameters = {
			{ name = 'weaponDefName', required = true, type = ParameterTypes.WeaponDefName },
			{ name = 'position', required = true, type = ParameterTypes.Position },
			{ name = 'direction', required = false, type = ParameterTypes.Position },
		},
		actionFunction = spawnExplosion,
	}
}
