function gadget:GetInfo()
	return {
		name         = "Interceptor Controller",
		desc         = "Controls Interceptors more precisely",
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

--Weapon types
local STARBUSTLAUNCHER = 1;
local BEAMLASER = 2;

local weaponTypes = {
	--Nothing = 0,
	StarburstLauncher = 1,
	BeamLaser = 2,
};

--Tables
local an_targetId = {}; 		--Table that contains current antinuke's target ID.
local an_wType = {};		 	--Table that contains current antinuke's weapon type.
local an_range = {}; 			--Table that contains original antinuke's range.
local an_deactivateTimer = {}; 	--Table that contains current antinuke's deactivate timer.

local debug_allowed = true; --Enables printing in console

function DebugEcho(ID, text)
	if debug_allowed then
		Spring.Echo("[" .. tostring(ID) .. "] " .. text);
	end
end

function SetAim(interceptorID, ready)
	if ready then
		--DebugEcho(interceptorID, "Weapon Range: " .. tostring(an_range[interceptorID]));
		Spring.SetUnitWeaponState(interceptorID, 1, "range", an_range[interceptorID]);
	else
		Spring.SetUnitWeaponState(interceptorID, 1, "range", 0);
	end
end

function AimPrimaryCheck(interceptorID, targetProjectileID)
	if an_wType[interceptorID] == STARBUSTLAUNCHER then --No restrictions, fire immediately
		SetAim(interceptorID, true);
	elseif an_wType[interceptorID] == BEAMLASER then --Restricted, fire later to avoid unwanted early damage on ground
		local velX, velY, velZ = Spring.GetProjectileVelocity(targetProjectileID);

		if velY == nil then
			an_targetId[interceptorID] = nil;
			DebugEcho(interceptorID, "Target lost!");
		else
			--local speed = math.speed3d(velX, velY, velZ);

			if velY > -5 then -- Prevents interceptors from firing missiles too early -> balance thing
				--DebugEcho(interceptorID, "Citadel's missile is ascending! |Vel2D: " .. tostring(vel2d));
				SetAim(interceptorID, false);
			else
				--DebugEcho(interceptorID, "Citadel's missile is DESCENDING! |Vel2D: " .. tostring(vel2d));
				SetAim(interceptorID, true);
			end
		end
	else
		DebugEcho(interceptorID, "No weapon found");
		DebugEcho(interceptorID, tostring(an_wType[interceptorID]));
	end
end

function gadget:GameFrame(f)
	if f % 60 == 1 then
		for interceptorID, targetProjectileID in pairs(an_targetId) do
			AimPrimaryCheck(interceptorID, targetProjectileID);
		end

		for interceptorID, time in pairs(an_deactivateTimer) do
			if an_targetId[interceptorID] == nil then
				time = time + 60;
				--DebugEcho(interceptorID, "Countdown: " .. tostring(time))
				if time >= 420 then
					Spring.CallCOBScript(interceptorID, "Deactivate", 0);
					SetAim(interceptorID, true); --Give back original range

					an_wType[interceptorID] = nil;
					an_range[interceptorID] = nil;
					an_deactivateTimer[interceptorID] = nil;
				else
					an_deactivateTimer[interceptorID] = time;
				end
			end
		end
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if an_targetId[proOwnerID] == nil then
		return;
	end

	if (an_wType[proOwnerID] == STARBUSTLAUNCHER) then
		local WeaponDef = WeaponDefs[weaponDefID]
		if WeaponDef.interceptor == 1 then
			Spring.SetProjectileTarget(proID, an_targetId[proOwnerID], string.byte('p')); --Set correct target (original target is buggy)
			DebugEcho(proOwnerID, "Antinuke fired missile! |TargetID: " .. tostring(an_targetId[proOwnerID]));
			SetAim(proOwnerID, false);
			an_targetId[proOwnerID] = nil;
			an_wType[proOwnerID] = nil;
		end
	end
end

function gadget:Explosion(weaponDefID, px, py, pz, AttackerID, ProjectileID)
	if an_targetId[AttackerID] == nil then
		return;
	end

	if (an_wType[AttackerID] == BEAMLASER) then
		local WeaponDef = WeaponDefs[weaponDefID]
		if WeaponDef.interceptor == 1 then
			DebugEcho(AttackerID, "Antinuke fired missile! |TargetID: " .. tostring(an_targetId[AttackerID]));
			an_targetId[AttackerID] = nil;
			an_wType[AttackerID] = nil;
		end
	end
end

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	if an_targetId[interceptorUnitID] ~= nil then
		return false;
	end

	local interp = Spring.GetProjectileIsIntercepted(targetProjectileID);
	if interp == false then
		local reloadState = Spring.GetUnitWeaponState(interceptorUnitID, interceptorWeaponID, "reloadState");
		reloadState = reloadState - Spring.GetGameFrame();
		if reloadState > 0 then --Interceptor not reloaded yet
			return false;
		end

		local unitDefID = Spring.GetUnitDefID(interceptorUnitID);
		local unitType = WeaponDefs[UnitDefs[unitDefID].weapons[1].weaponDef].type;
		local weaponTypeId = 0;

		for weaponName, weaponId in pairs(weaponTypes) do
			if weaponName == unitType then
				weaponTypeId = weaponId;
			end
		end

		if weaponTypeId == STARBUSTLAUNCHER then --Ignore projectile, if it's too close
			local velX, velY, velZ = Spring.GetProjectileVelocity(targetProjectileID);
			if velY < -2 then
				local pX, pY, pZ = Spring.GetProjectilePosition(targetProjectileID);
				--local uX, uY, uZ = Spring.GetUnitPosition(interceptorUnitID);
				local targetType, tarPos = Spring.GetProjectileTarget(targetProjectileID);

				local projSpeed = math.speed3d(velX, velY, velZ) * 5;
				local newX = pX + (velX * projSpeed);
				local newY = pY + (velY * projSpeed);
				local newZ = pZ + (velZ * projSpeed);
				local distance = math.diag(tarPos[1] - newX, tarPos[3] - newZ);

				if distance <= 1000 or newY < tarPos[2] then
					DebugEcho(interceptorUnitID, "Too close: " .. tostring(distance) .. " |S: " .. tostring(projSpeed) .. " |NX: " .. tostring(newX) .. " |NZ: " .. tostring(newZ) .. " |TarX: " .. tostring(tarPos[1]) .. " |tarZ: " .. tostring(tarPos[3]) .. " |X: " .. tostring(pX) .. " |Z: " .. tostring(pZ));
					return false;
				end
				DebugEcho(interceptorUnitID, "Distance ok: " .. tostring(distance) .. " |S: " .. tostring(projSpeed) .. " |NX: " .. tostring(newX) .. " |NZ: " .. tostring(newZ) .. " |TarX: " .. tostring(tarPos[1]) .. " |tarZ: " .. tostring(tarPos[3]) .. " |X: " .. tostring(pX) .. " |Z: " .. tostring(pZ));

				--local posYDifference = pY - uY;
				--local distance = math.diag(pX - uX, pZ - uZ);
				--local distance = math.diag(pX - uX, pY - uY, pZ - uZ)
				--if posYDifference <= 2000  then
				--	DebugEcho(interceptorUnitID, "Too close: " .. tostring(posYDifference));
				--	return false;
				--end
				--DebugEcho(interceptorUnitID, "Distance ok: " .. tostring(posYDifference));
			end
		end

		an_targetId[interceptorUnitID] = targetProjectileID;
		an_wType[interceptorUnitID] = weaponTypeId;
		if an_range[interceptorUnitID] == nil then
			an_range[interceptorUnitID] = Spring.GetUnitWeaponState(interceptorUnitID, 1, "range");
		end
		an_deactivateTimer[interceptorUnitID] = 0;

		--DebugEcho(interceptorUnitID, "Antinuke accepted missile! |TargetID: " .. tostring(t_target[interceptorUnitID]));
		AimPrimaryCheck(interceptorUnitID, targetProjectileID);
		Spring.SetProjectileIsIntercepted(targetProjectileID, true);
		return true;
	end

	return false;
end
