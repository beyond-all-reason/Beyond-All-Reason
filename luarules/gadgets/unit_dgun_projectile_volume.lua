function gadget:GetInfo()
    return {
        name      = "Dgun projectile volume",
        desc      = "Damages units close around/inside the dgun projectile (so it has volume instead of a hitscan dot)",
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

local damagedelay = 0 -- number of frames before the damage starts to kick in
local additionalradius = 10 -- extra radius above the units standard radius to scan for
local damageAmount = 9999 -- amount of damage, applied only once per projectile per unit
local dGunRange = 250 -- This is so that we dont deal 'extra' damage outside of the range of the unit
local killfriendly = true -- only different allyteams get hit


local projectiles = {} -- {owner = proOwnerID, gameframe = Spring.GetGameFrame(), alreadydamaged = {}}
local commanders = {}

local weapons = {}
local dgunProjectileWeaponID
for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'DGun' and weaponDef.damages  then -- to filter out decoy comm -- and weaponDef.damage.default > 5000
		for _, v in pairs(weaponDef.damages) do
			if v > 99000 then
				weapons[weaponDef.id] = true
			end
		end
    end
	if weaponDef.name == 'dgun_projectile' then
		dgunProjectileWeaponID = weaponID
	end
end
if not dgunProjectileWeaponID then
	Spring.Echo('Dgun projectile volume: -=== dgun projectile weapon not found ===-')
	return
end

local isCommander = {} -- all dgun type weapon wield units are considered commanders, including decoys and scavbosses


for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander == true then
		isCommander[unitDefID] = true
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
        local ownerallyteam = Spring.GetUnitAllyTeam(proOwnerID)
        local x,y,z = Spring.GetProjectilePosition(proID)
        projectiles[proID] = {owner = proOwnerID, gameframe = Spring.GetGameFrame(), alreadydamaged = {}, ownerallyteam = ownerallyteam, startx = x, starty = y , startz = z}
    end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
end

local function distancesq(x1,y1,z1,x2,y2,z2)
	local x = (x1-x2)
	local y = (y1-y2)
	local z = (z1-z2)
	return (x*x + y*y + z*z)
end

function gadget:GameFrame(gf)
	for projectileID, projectile in pairs(projectiles) do
		if projectile.gameframe <= Spring.GetGameFrame() + damagedelay then

			local x,y,z = Spring.GetProjectilePosition(projectileID)
			-- find commander that fired it so it can become immune to its damage
			local units = Spring.GetUnitsInSphere(x,y,z, 80)	-- set a little wider than needed to be sure its sufficient for all dgun angles
			-- seems that one can find my (-2), ally (-3), and enemy ( -4) units too with 5th param to GetUnitsInSphere! (but probably abad idea in synced!
			for i, unitID in pairs(units) do
				local ux, uy, uz = Spring.GetUnitPosition(unitID, true) -- get mid pos
				local radius = Spring.GetUnitRadius(unitID) + additionalradius

				-- order by likelyhood
				if commanders[unitID] == nil
					and (killfriendly or Spring.GetUnitAllyTeam(unitID) ~= projectile.ownerallyteam) -- dont kill friendlies
					and projectile.alreadydamaged[unitID] == nil  -- only once per unit
					and distancesq(x,y,z,ux,uy,uz) < radius * radius   -- its inside the units radius
        			and distancesq(projectile.startx, projectile.starty, projectile.startz, ux, uy, uz) < dGunRange*dGunRange
				then -- so they dont damage too far outside of their range
					Spring.AddUnitDamage(unitID, damageAmount, 0, projectile.owner, dgunProjectileWeaponID)
					projectile.alreadydamaged[unitID] = true
				end
			end
		end
	end
end


