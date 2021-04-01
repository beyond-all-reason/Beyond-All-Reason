function gadget:GetInfo()
    return {
        name      = "Dgun projectile volume",
        desc      = "Adds explosions to the dgun projectile (so it has volume)",
        version   = "1.0",
        author    = "Floris",
        date      = "April 2021",
        license   = "GNU GPL, v3 or later",
        layer     = 0,
        enabled   = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local projectiles = {}
local commanders = {}

local weapons = {}
local dgunProjectileWeaponID
for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'DGun' then
		weapons[weaponDef.id] = true
    end
	if weaponDef.name == 'dgun_projectile' then
		dgunProjectileWeaponID = weaponID
	end
end
if not dgunProjectileWeaponID then
	Spring.Echo('-=== dgun projectile weapon not found ===-')
	return
end

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

function gadget:Initialize()
    for weaponDefID,_ in pairs(weapons) do
        Script.SetWatchProjectile(weaponDefID, true)
    end
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		commanders[unitID] = true
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		commanders[unitID] = nil
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if weapons[weaponDefID] then
        projectiles[proID] = true
    end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
end

function gadget:GameFrame(gf)
	for projectileID, projectile in pairs(projectiles) do
		local x,y,z = Spring.GetProjectilePosition(projectileID)

		-- find commander that fired it so it can become immune to its damage
		if type(projectiles[projectileID]) ~= 'number' then
			local units = Spring.GetUnitsInSphere(x,y,z, 45)	-- set a little wider than needed to be sure its sufficient for all dgun angles
			for i, unitID in pairs(units) do
				if commanders[unitID] then
					projectiles[projectileID] = unitID
					break
				end
			end
		end
		if type(projectiles[projectileID]) == 'number' then
			--local dirX,dirY,dirZ = Spring.GetProjectileDirection(projectileID)
			Spring.SpawnExplosion( x,y,z, nil,nil,nil, {weaponDef=dgunProjectileWeaponID, owner=projectiles[projectileID]} )
		else
			-- give up
			projectiles[projectileID] = nil
			--Spring.Echo('-=== dgun projectile owner not found ===-')
		end
	end
end


