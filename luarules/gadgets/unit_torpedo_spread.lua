function gadget:GetInfo()
	return {
		name = "Torpedo Spread",
		desc = "Torpedo projectile explodes and spreads smaller tracking torpedos",
		author = "[Fx]Doo",
		date = "03/28/17",
		license = "Free",
		layer = 0,
		enabled = false
	}
end



if (gadgetHandler:IsSyncedCode()) then
function gadget:Initialize()
newProjTarget = {}
projTargetPosition = {}
	for name, wDef in pairs(WeaponDefNames) do
	if name == "corsub_torpedomain" then torpmainID = wDef.id end
	if name == "corsub_torpedomini" then torpminiID = wDef.id end
end
--Spring.Echo(torpmainID)
--Spring.Echo(torpminiID)
end
torpedoTarget= {}
proOwner = {}
function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
if proID and proOwnerID and weaponDefID then
proOwner[proID] = proOwnerID
if weaponDefID == torpmainID then
torpedoTarget[proID] = {}
local targetTypeInt = Spring.GetProjectileTarget(proID)
if targetTypeInt == string.byte('g') then 
torpedoTarget[proID].type = "ground" 
torpedoTarget[proID].target = {}
ttype, torpedoTarget[proID].target = Spring.GetProjectileTarget(proID)
end
if targetTypeInt == string.byte('u') then 
torpedoTarget[proID].type = "unit" 
ttype, torpedoTarget[proID].target = Spring.GetProjectileTarget(proID)
end
if targetTypeInt == string.byte('f') then 
torpedoTarget[proID].type = "feature" 
ttype, torpedoTarget[proID].target = Spring.GetProjectileTarget(proID)
end
if targetTypeInt == string.byte('p') then 
torpedoTarget[proID].type = "projectile" 
ttype, torpedoTarget[proID].target = Spring.GetProjectileTarget(proID)
end
end
end
end


function gadget:GameFrame(f)
--Spring.Echo("gameframe event triggered")
for proID,value in pairs(torpedoTarget) do
--Spring.Echo("cycling through proID table")
if proID and Spring.GetProjectilePosition(proID) then
--Spring.Echo("found valid proID")
local projPosition = {}
local xp, yp, zp = Spring.GetProjectilePosition(proID)
local projPosition = {xp, yp, zp}

if (torpedoTarget[proID].type) then
--Spring.Echo("ground target")
	if torpedoTarget[proID].type == "ground" then
	projTargetPosition[proID] = {}
	projTargetPosition[proID] = torpedoTarget[proID].target
	--Spring.Echo("Valid target position")
	end
	if torpedoTarget[proID].type == "feature" then
		if Spring.GetFeaturePosition(torpedoTarget[proID].target) then
			projTargetPosition[proID] = {}
			local x,y,z = Spring.GetFeaturePosition(torpedoTarget[proID].target)
			projTargetPosition[proID] = {x, y, z}
		end
	end
	if torpedoTarget[proID].type == "unit" then
		if Spring.GetUnitPosition(torpedoTarget[proID].target) then
			projTargetPosition[proID] = {}
			local x,y,z = Spring.GetUnitPosition(torpedoTarget[proID].target)
			projTargetPosition[proID] = {x, y, z}
		end
	end
	if torpedoTarget[proID].type == "projectile" then
		if Spring.GetProjectilePosition(torpedoTarget[proID].target) then
			projTargetPosition[proID] = {}
			local x,y,z = Spring.GetProjectilePosition(torpedoTarget[proID].target)
			projTargetPosition[proID] = {x, y, z}
		end
	end
end

local dx,dy,dz = math.abs(xp - projTargetPosition[proID][1]), math.abs(yp - projTargetPosition[proID][2]), math.abs (zp - projTargetPosition[proID][3])
local distance = math.sqrt(dx^2 + dy ^2 + dz^2)

if distance then
if proOwner[proID] then
	if distance <= 200 then

	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
		dirx, diry, dirz = vx/math.abs(vx), vy/math.abs(vy), vz/math.abs(vz)
	Spring.SpawnCEG("FLASH3", xp, yp, zp, vx/math.abs(vx), vy/math.abs(vy), vz/math.abs(vz), 128, 0)
	-- Spring.Echo(xp)
	-- Spring.Echo(yp)
	-- Spring.Echo(zp)
	for i = -0.5,0.5,1 do
		for j = -0.5,0.5,1 do
			for k = -0.05,0.05,0.1 do
					local projectileparamstable = {}
					local projectileparamstable = {  
					pos = {xp, yp, zp},
					gravity = 0,
					speed = {vx+i*5*dirx, vy+k, vz+j*5*dirz},
					owner = proOwner[proID],
					team = Spring.GetUnitTeam(proOwner[proID]),
					ttl = 60,
					tracking = 0.1,
					maxRange = 250,
					model = "minitorpedo",
					}
			local ID = Spring.SpawnProjectile(torpminiID, projectileparamstable)
			local targettype, target = Spring.GetProjectileTarget(proID)
			--Spring.Echo(targettype)
			--Spring.Echo(target)
			if targettype == string.byte('g') then 
			Spring.SetProjectileTarget(ID, projTargetPosition[proID][1], projTargetPosition[proID][2], projTargetPosition[proID][3])
			else
			Spring.SetProjectileTarget(ID, target, targettype)
			end

			newProjTarget[ID] = {}
			newProjTarget[ID].targettype = targettype
			newProjTarget[ID].target = target
			Spring.DeleteProjectile(proID)
			torpedoTarget[proID] = nil
			end
		end
	end
	end
end
end
end
end	
end


function gadget:ProjectileDestroyed(proID)
if (torpedoTarget[proID]) then 
torpedoTarget[proID] = nil
end
-- if newProjTarget[proID] then 
-- newProjTarget[proID] = nil
-- end
end
end