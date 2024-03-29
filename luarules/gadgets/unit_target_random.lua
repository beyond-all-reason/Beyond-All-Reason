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

local t_target = {}; --Table that contains current target for every antinuke

function gadget:GameFrame(f)
	--Spring.Echo("Frame! " .. tostring(f));
	if f % 20 == 1 then
		for interceptorID, targetProjectileID in pairs(t_target) do
			local velX, velY = Spring.GetProjectileVelocity(targetProjectileID);
			if velY == nil then
				t_target[interceptorID] = nil;
				Spring.Echo("Unknown target! " .. tostring(interceptorID));
			else
				--Spring.SetUnitUseWeapons(interceptorID, false, false);

				if (velY >= 0) then -- TODO Prevent interceptors from firing asceding missiles
					Spring.Echo("Citadel's missile is ascending! " .. tostring(interceptorID) .. " | " .. tostring(velY));
					Spring.SetUnitWeaponState(interceptorID, 1, "aimReady", 0);
					--Spring.SetUnitUseWeapons(interceptorID, false, false);
				else
					Spring.Echo("Citadel's missile is DESCENDING! " .. tostring(interceptorID) .. " | " .. tostring(velY));
					Spring.SetUnitWeaponState(interceptorID, 1, "aimReady", 1);
					--Spring.SetUnitUseWeapons(interceptorID, false, true);
				end
			end
		end
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
	for key, value in pairs(t_target) do
		if key == AttackerID then
			local WeaponDef = WeaponDefs[weaponDefID]
			if WeaponDef.interceptor == 1 then
				Spring.Echo("Citadel fired nuke! " .. tostring(AttackerID) .. " | " .. tostring(key) .. " | " .. tostring(t_target[AttackerID] ));
				t_target[AttackerID] = nil;
			end
		end
	end
end

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	--return true;
	local interp = Spring.GetProjectileIsIntercepted(targetProjectileID);

	if t_target[interceptorUnitID] ~= nil then
		--Spring.Echo("Oh no! Citadel is busy " .. tostring(interceptorUnitID) .. " | " .. tostring(table[interceptorUnitID] ));
		return false;
	end

	--local targetType, isUserTarget, target = Spring.GetUnitWeaponTarget(interceptorUnitID, interceptorWeaponID);
	--Spring.Echo(string.format("%d | %d | %d Intercepted: ", interceptorUnitID, targetProjectileID, target)  .. tostring(interp));

	if interp == false then
		t_target[interceptorUnitID] = targetProjectileID;
		--Spring.Echo("Citadel accepted nuke! " .. tostring(interceptorUnitID) .. " | " .. tostring(t_target[interceptorUnitID] ));
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
			--t_target[unitID] = 0;
			--Spring.Echo("Citadel registered! " .. tostring(unitID) .. " | " .. tostring(t_target[unitID] ));
		end
	end
end
