function gadget:GetInfo()
	return {
		name         = "Advanced interceptor control",
		desc         = "Description as normally shown in tooltip",
		author       = "Yzch",
		date         = "28.03.2024",
		license      = "GNU GPL, v2 or later",
		layer        = 0,
		enabled      = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local t_target = {}; --Table that contains current target ID for every antinuke
local t_type = {}; --Table that contains current weapon type for every antinuke
local t_deactivate = {}; --Table that contains deactivate countdown for every antinuke
local debug_allowed = true; --Enables printing in console

function DebugEcho(ID, text)
	if debug_allowed then
		Spring.Echo("[" .. tostring(ID) .. "] " .. text);
	end
end

function SetAim(interceptorID, ready)
	if t_type[interceptorID] == "StarburstLauncher" then
		DebugEcho(interceptorID, "Weapon Aim: " .. tostring(ready));
		if ready then
			--Spring.SetUnitWeaponState(interceptorID, 1, "projectiles", 1);
			Spring.SetUnitWeaponState(interceptorID, 1, "range", 72000);
			--Spring.SetUnitUseWeapons(interceptorID, false, true);
		else
			--Spring.SetUnitUseWeapons(interceptorID, false, false);
			--Spring.SetUnitWeaponState(interceptorID, 1, "projectiles", 0);
			Spring.SetUnitWeaponState(interceptorID, 1, "range", 0);
		end
	elseif t_type[interceptorID] == "BeamLaser" then
		if ready then
			Spring.SetUnitWeaponState(interceptorID, 1, "projectiles", 1);
		else
			Spring.SetUnitWeaponState(interceptorID, 1, "projectiles", 0);
		end
	end
end

function AimPrimaryCheck(interceptorID, targetProjectileID)
	if t_type[interceptorID] == "StarburstLauncher" then --No restrictions, fire immediately
		--DebugEcho(interceptorID, "Prevailer fire!");
		SetAim(interceptorID, true);
	elseif t_type[interceptorID] == "BeamLaser" then --Restricted, fire later to avoid unwanted early damage on ground
		local velX, velY, velZ = Spring.GetProjectileVelocity(targetProjectileID);

		if velY == nil then
			t_target[interceptorID] = nil;
			DebugEcho(interceptorID, "Target lost!");
		else
			--Spring.SetUnitUseWeapons(interceptorID, false, false);
			local vel2d = math.abs(velX) + math.abs(velZ);

			if (vel2d <= 0.1) then -- Prevents interceptors from firing asceding missiles
				--DebugEcho(interceptorID, "Citadel's missile is ascending! |Vel2D: " .. tostring(vel2d));
				SetAim(interceptorID, false);
				--Spring.SetUnitUseWeapons(interceptorID, false, false);
			else
				--DebugEcho(interceptorID, "Citadel's missile is DESCENDING! |Vel2D: " .. tostring(vel2d));
				SetAim(interceptorID, true);
				--Spring.SetUnitUseWeapons(interceptorID, false, true);
			end
		end
	else
		DebugEcho(interceptorID, "No weapon found");
		DebugEcho(interceptorID, tostring(t_type[interceptorID]));
	end
end

function gadget:GameFrame(f)
	--Spring.Echo("Frame! " .. tostring(f));
	if f % 60 == 1 then
		for interceptorID, targetProjectileID in pairs(t_target) do
			AimPrimaryCheck(interceptorID, targetProjectileID);
		end

		for interceptorID, time in pairs(t_deactivate) do
			if t_target[interceptorID] == nil then
				time = time + 60;
				--DebugEcho(interceptorID, "Countdown: " .. tostring(time))
				if time >= 420 then
					Spring.CallCOBScript(interceptorID, "Deactivate", 0);
					SetAim(proOwnerID, true); --Unpause making stockpiles (For some units like StarburstLauncher)

					t_deactivate[interceptorID] = nil;
				else
					t_deactivate[interceptorID] = time;
				end
			end
		end
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if t_target[proOwnerID] == nil then
		return;
	end

	if (t_type[proOwnerID] == "StarburstLauncher") then
		local WeaponDef = WeaponDefs[weaponDefID]
		if WeaponDef.interceptor == 1 then
			Spring.SetProjectileTarget(proID, t_target[proOwnerID], string.byte('p')); --Set correct target (original target is buggy)
			DebugEcho(proOwnerID, "Antinuke fired missile! |TargetID: " .. tostring(t_target[proOwnerID]));
			SetAim(proOwnerID, false);
			t_target[proOwnerID] = nil;
			t_type[proOwnerID] = nil;
		end
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
	if t_target[AttackerID] == nil then
		return;
	end

	if (t_type[AttackerID] == "BeamLaser") then
		local WeaponDef = WeaponDefs[weaponDefID]
		if WeaponDef.interceptor == 1 then
			DebugEcho(AttackerID, "Antinuke fired missile! |TargetID: " .. tostring(t_target[AttackerID]));
			t_target[AttackerID] = nil;
			t_type[AttackerID] = nil;
		end
	end
end

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	local interp = Spring.GetProjectileIsIntercepted(targetProjectileID);

	if t_target[interceptorUnitID] ~= nil then
		--Spring.Echo("Oh no! Citadel is busy " .. tostring(interceptorUnitID) .. " | " .. tostring(table[interceptorUnitID] ));
		return false;
	end

	--local targetType, isUserTarget, target = Spring.GetUnitWeaponTarget(interceptorUnitID, interceptorWeaponID);
	--Spring.Echo(string.format("%d | %d | %d Intercepted: ", interceptorUnitID, targetProjectileID, target)  .. tostring(interp));

	if interp == false then
		local reloadState = Spring.GetUnitWeaponState(interceptorUnitID, interceptorWeaponID, "reloadState");
		reloadState = reloadState - Spring.GetGameFrame();
		if reloadState > 0 then --Interceptor not reloaded yet
			--DebugEcho(interceptorUnitID, "Reload state: " .. tostring(reloadState));
			return false;
		end

		local unitDefID = Spring.GetUnitDefID(interceptorUnitID);
		local unitType = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].type;
		if unitType == "StarburstLauncher" then --Ignore projectile, if it's too close
			local pX, pY, pZ = Spring.GetProjectilePosition(targetProjectileID);
			local uX, uY, uZ = Spring.GetUnitPosition(interceptorUnitID);

			local distance = math.distance2d(pX, pZ, uX, uZ);
			if distance <= 1200 then
				DebugEcho(interceptorUnitID, "Too close: " .. tostring(distance));
				return false;
			end
			DebugEcho(interceptorUnitID, "Distance ok: " .. tostring(distance));
		end

		t_target[interceptorUnitID] = targetProjectileID;
		t_type[interceptorUnitID] = unitType;
		t_deactivate[interceptorUnitID] = 0;

		--DebugEcho(interceptorUnitID, "Antinuke accepted missile! |TargetID: " .. tostring(t_target[interceptorUnitID]));
		AimPrimaryCheck(interceptorUnitID, targetProjectileID);
		Spring.SetProjectileIsIntercepted(targetProjectileID, true);
		return true;
	end

	return false;
end
