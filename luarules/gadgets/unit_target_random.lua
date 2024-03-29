function gadget:GetInfo()
	return {
		name         = "Name as shown in widget list",
		desc         = "Description as normally shown in tooltip",
		author       = "It could be you!",
		date         = "now",
		license      = "PD", -- should be compatible with Spring
		layer        = 0,
		enabled      = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local table = {};

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
	for key, value in pairs(table) do
		if key == AttackerID then
			local WeaponDef = WeaponDefs[weaponDefID]
			if WeaponDef.interceptor == 1 then
				Spring.Echo("Citadel fired nuke! " .. tostring(AttackerID) .. " | " .. tostring(key) .. " | " .. tostring(table[AttackerID] ));
				table[AttackerID] = table[AttackerID] - 1;
			end
		end
	end
end

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	--return true;
	local interp = Spring.GetProjectileIsIntercepted(targetProjectileID);
	local velX, velY = Spring.GetProjectileVelocity(targetProjectileID);

	if (-1 >= 0) then -- TODO Prevent interceptors from firing asceding missiles
		Spring.Echo("Projectile ascending... " .. tostring(targetProjectileID) .. " | " .. tostring(velY));
		return false;
	end

	if (table[interceptorUnitID] >= 5) then
		--Spring.Echo("Oh no! Citadel is busy " .. tostring(interceptorUnitID) .. " | " .. tostring(table[interceptorUnitID] ));
		return false;
	end

	--local targetType, isUserTarget, target = Spring.GetUnitWeaponTarget(interceptorUnitID, interceptorWeaponID);
	--Spring.Echo(string.format("%d | %d | %d Intercepted: ", interceptorUnitID, targetProjectileID, target)  .. tostring(interp));

	if interp == false then
		table[interceptorUnitID] = table[interceptorUnitID] + 1;
		Spring.Echo("Citadel accepted nuke! " .. tostring(interceptorUnitID) .. " | " .. tostring(table[interceptorUnitID] ));
		Spring.SetProjectileIsIntercepted(targetProjectileID, true);
		return true;
	end

	return false;
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local weapons = UnitDefs[unitDefID].weapons
	for weaponNum = 1, #weapons do
		local WeaponDefID = weapons[weaponNum].weaponDef
		local WeaponDef = WeaponDefs[WeaponDefID]
		if WeaponDef.interceptor == 1 then
			table[unitID] = 0;
			Spring.Echo("Citadel registered! " .. tostring(unitID) .. " | " .. tostring(table[unitID] ));
		end
	end
end
