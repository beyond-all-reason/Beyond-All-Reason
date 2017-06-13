function gadget:GetInfo()
	return {
		name = "ARMCYBR Weapon Behaviour",
		desc = "Slightly alters the weapon's behaviour so it only starts tracking after delay",
		author = "[Fx]Doo",
		date = "04th of June 2017",
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
	if name == "armcybr_arm_pidrbomb" then bombID = wDef.id end
	if name == "armcybr_arm_pidrmis" then misID = wDef.id end
end
--Spring.Echo(bombID)
--Spring.Echo(misID)
end
atomicTarget= {}
proOwner = {}
atomicFrame = {}
function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
if proID and proOwnerID and weaponDefID then
proOwner[proID] = proOwnerID
if weaponDefID == bombID then
atomicTarget[proID] = {}
atomicFrame[proID] = Spring.GetGameFrame() + 15
local targetTypeInt = Spring.GetProjectileTarget(proID)
if targetTypeInt == string.byte('g') then 
atomicTarget[proID].type = "ground" 
atomicTarget[proID].target = {}
-- Spring.Echo(atomicTarget[proID].target)
ttype, atomicTarget[proID].target = Spring.GetProjectileTarget(proID)--{x,y,z}
-- Spring.Echo(atomicTarget[proID].target)
end
if targetTypeInt == string.byte('u') then 
atomicTarget[proID].type = "unit" 
ttype, atomicTarget[proID].target = Spring.GetProjectileTarget(proID)
end
if targetTypeInt == string.byte('f') then 
atomicTarget[proID].type = "feature" 
ttype, atomicTarget[proID].target = Spring.GetProjectileTarget(proID)
end
if targetTypeInt == string.byte('p') then 
atomicTarget[proID].type = "projectile" 
ttype, atomicTarget[proID].target = Spring.GetProjectileTarget(proID)
end
end
end
end


function gadget:GameFrame(f)
--Spring.Echo("gameframe event triggered")
for proID,value in pairs(atomicTarget) do
--Spring.Echo("cycling through proID table")
if proID and Spring.GetProjectilePosition(proID) then
if f == atomicFrame[proID] then
--Spring.Echo("found valid proID")
local projPosition = {}
local xp, yp, zp = Spring.GetProjectilePosition(proID)
local projPosition = {xp, yp, zp}

if (atomicTarget[proID].type) then
--Spring.Echo("ground target")
	if atomicTarget[proID].type == "ground" then
	projTargetPosition[proID] = {}
	-- Spring.Echo(atomicTarget[proID].target)
	projTargetPosition[proID] = atomicTarget[proID].target
	--Spring.Echo("Valid target position")
	end
	if atomicTarget[proID].type == "feature" then
		if Spring.GetFeaturePosition(atomicTarget[proID].target) then
			projTargetPosition[proID] = {}
			local x,y,z = Spring.GetFeaturePosition(atomicTarget[proID].target)
			projTargetPosition[proID] = {x, y, z}
		end
	end
	if atomicTarget[proID].type == "unit" then
		if Spring.GetUnitPosition(atomicTarget[proID].target) then
			projTargetPosition[proID] = {}
			local x,y,z = Spring.GetUnitPosition(atomicTarget[proID].target)
			projTargetPosition[proID] = {x, y, z}
		end
	end
	if atomicTarget[proID].type == "projectile" then
		if Spring.GetProjectilePosition(atomicTarget[proID].target) then
			projTargetPosition[proID] = {}
			local x,y,z = Spring.GetProjectilePosition(atomicTarget[proID].target)
			projTargetPosition[proID] = {x, y, z}
		end
	end
end
if proOwner[proID] then
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	-- Spring.Echo(xp)
	-- Spring.Echo(yp)
	-- Spring.Echo(zp)
					local projectileparamstable = {}
					local projectileparamstable = {  
					pos = {xp, yp, zp},
					speed = {vx, vy, vz},
					owner = proOwner[proID],
					team = Spring.GetUnitTeam(proOwner[proID]),
					ttl = 60,
					tracking = 0.05,
					maxRange = 250,
					model = "plasmafire2",
					}
			local ID = Spring.SpawnProjectile(misID, projectileparamstable)
			local targettype, target = Spring.GetProjectileTarget(proID)
			--Spring.Echo(targettype)
			--Spring.Echo(target)
			-- Spring.Echo(projTargetPosition[proID])
			if targettype == string.byte('g') then 
			Spring.SetProjectileTarget(ID, projTargetPosition[proID][1], projTargetPosition[proID][2], projTargetPosition[proID][3])
			else
			Spring.SetProjectileTarget(ID, target, targettype)
			end

			newProjTarget[ID] = {}
			newProjTarget[ID].targettype = targettype
			newProjTarget[ID].target = target
			Spring.DeleteProjectile(proID)
			atomicTarget[proID] = nil
			end
		end
	end
	end
end


function gadget:ProjectileDestroyed(proID)
if (atomicTarget[proID]) then 
atomicTarget[proID] = nil
end
-- if newProjTarget[proID] then 
-- newProjTarget[proID] = nil
-- end
end
end