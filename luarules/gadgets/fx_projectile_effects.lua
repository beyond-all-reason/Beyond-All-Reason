local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Projectile Effects",
        desc      = "Unifies projectile effect CEG spawning",
        version   = "1",
        author    = "Beherith, Floris, Bluestone",
        date      = "2023.11.13",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true,
    }
end

--- This gadget replaces: -----
-- luarules\gadgets\fx_depthcharge_splash.lua
-- luarules\gadgets\fx_missile_smoke.lua
-- luarules\gadgets\fx_missile_starburst_liftoff.lua
-- luarules\gadgets\fx_submissile_splash.lua -- which was off anyway
-- Also, it should check wether water is even possibly present on the map, and not even check for those

if not gadgetHandler:IsSyncedCode() then
    return false
end

local GetProjectilePosition = Spring.GetProjectilePosition
local GetProjectileDirection = Spring.GetProjectileDirection
local GetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local GetGroundHeight = Spring.GetGroundHeight
local GetGameFrame = Spring.GetGameFrame

local SpawnCEG = Spring.SpawnCEG
-- Helpful debug wrapper:
-- SpawnCEG = function(ceg,x,y,z,dx,dy,dz) Spring.Echo(ceg,x,y,z); Spring.SpawnCEG(ceg,x,y,z,dx,dy,dz) end

local random = math.random

local gameFrame = 0
local mapHasWater = true

-----------------------------------------------------------------------------------------
local depthCharges = {} --Depthcharges that are above the surface still
local depthChargeWeapons = {} -- initialized conditionally on mapHasWater

-----------------------------------------------------------------------------------------

local missileIDtoProjType = {}
local missileIDtoLifeEnd = {}

local missileWeapons = {}
for weaponID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.type == 'MissileLauncher' then
        if weaponDef.cegTag == 'missiletrailsmall' then
            missileWeapons[weaponDef.id] = 'missiletrailsmall-smoke'
        elseif weaponDef.cegTag == 'missiletrailsmall-simple' then
            missileWeapons[weaponDef.id] = 'missiletrailsmall-simple-smoke'
        elseif weaponDef.cegTag == 'missiletrailsmall-red' then
            missileWeapons[weaponDef.id] = 'missiletrailsmall-red-smoke'
        elseif weaponDef.cegTag == 'missiletrailmedium' then
            missileWeapons[weaponDef.id] = 'missiletrailmedium-smoke'
        elseif weaponDef.cegTag == 'missiletrailmedium-red' then
            missileWeapons[weaponDef.id] = 'missiletrailmedium-smoke'
        elseif weaponDef.cegTag == 'missiletraillarge' then
            missileWeapons[weaponDef.id] = 'missiletraillarge-smoke'
        elseif weaponDef.cegTag == 'missiletraillarge-red' then
            missileWeapons[weaponDef.id] = 'missiletraillarge-smoke'
        elseif weaponDef.cegTag == 'missiletrailtiny' then
            missileWeapons[weaponDef.id] = 'missiletrailtiny-smoke'
        elseif weaponDef.cegTag == 'missiletrailaa' then
            missileWeapons[weaponDef.id] = 'missiletrailaa-smoke'
        --elseif weaponDef.cegTag == 'missiletrailfighter' then
        --    missileWeapons[weaponDef.id] = 'missiletrailfighter-smoke'
        end
    end
end

-----------------------------------------------------------------------------------------
local starbursts = {} 
local starburstWeapons = {} -- {wDID = {startHeight, cegName, nofueltime, maxtime,  }}

for weaponID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == 'StarburstLauncher' then
		if weaponDef.cegTag == 'missiletrailsmall-starburst' then
			starburstWeapons[weaponDef.id] = {
				0,
				'missiletrailsmall-starburst-vertical', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundsmall-liftoff', 60, 90,
				'missilegroundsmall-liftoff-fire', 25, 45
			}
		elseif weaponDef.cegTag == 'missiletrailmedium-starburst' then
			starburstWeapons[weaponDef.id] = {
				0,
				'missiletrailmedium-starburst-vertical', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundmedium-liftoff', 40, 60,
				'missilegroundmedium-liftoff-fire', 30, 40
			}
		elseif weaponDef.cegTag == 'missiletrail-juno' then
			starburstWeapons[weaponDef.id] = {
				0,
				'missiletrail-juno-starburst', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundlarge-liftoff', 80, 120,
				'missilegroundlarge-liftoff-fire', 40, 80
			}
		elseif weaponDef.cegTag == 'antimissiletrail' then
			starburstWeapons[weaponDef.id] = {
				0,
				'antimissiletrail-starburst', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundlarge-liftoff', 80, 120,
				'missilegroundlarge-liftoff-fire', 40, 80
			}
		elseif weaponDef.cegTag == 'cruisemissiletrail-emp' then
			starburstWeapons[weaponDef.id] = {
				0,
				'cruisemissiletrail-starburst', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundlarge-liftoff', 90, 166,
				'missilegroundlarge-liftoff-fire', 55, 120
			}
		elseif weaponDef.cegTag == 'cruisemissiletrail-tacnuke' then
			starburstWeapons[weaponDef.id] = {
				15,
				'cruisemissiletrail-starburst', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundlarge-liftoff', 90, 166,
				'missilegroundlarge-liftoff-fire', 55, 120
			}
		elseif weaponDef.cegTag == 'NUKETRAIL' then
			starburstWeapons[weaponDef.id] = {
				0,
				'nuketrail-starburst', ((weaponDef.uptime + 0.1) * 30), ((weaponDef.uptime + 0.6) * 30),
				'missilegroundhuge-liftoff', 120, 180,
				'missilegroundhuge-liftoff-fire', 60, 150
			}
		end
	end
end

-----------------------------------------------------------------------------------------
local allWatchedWeaponDefIDs = {}
local allWatchedProjectileIDs = {}


function gadget:Initialize()
	local minheight, maxheight = Spring.GetGroundExtremes()
	if minheight > 100 then 
		mapHasWater = false
	end
	if mapHasWater then 
		for weaponID, weaponDef in pairs(WeaponDefs) do
			if weaponDef.type == 'TorpedoLauncher' then
				if weaponDef.visuals.modelName == 'objects3d/torpedo.s3o' or weaponDef.visuals.modelName == 'objects3d/cordepthcharge.s3o'
				or weaponDef.visuals.modelName == 'objects3d/torpedo.3do' or weaponDef.visuals.modelName == 'objects3d/depthcharge.3do' then
					depthChargeWeapons[weaponID] = 'splash-torpedo'
				elseif weaponDef.visuals.modelName == 'objects3d/coradvtorpedo.s3o' or weaponDef.visuals.modelName == 'objects3d/Advtorpedo.3do' then
					depthChargeWeapons[weaponID] = 'splash-tiny'
				else
					depthChargeWeapons[weaponID] = 'splash-torpedo'
				end
			end
		end
		for wDID,_ in pairs(depthChargeWeapons) do
			Script.SetWatchProjectile(wDID, true)
			allWatchedWeaponDefIDs[wDID] = "depthCharge"
		end
	end
	
		
	for wDID,_ in pairs(missileWeapons) do
        Script.SetWatchProjectile(wDID, true)
		allWatchedWeaponDefIDs[wDID] = "missile"
		--Spring.Echo("Watching for missile",WeaponDefs[wDID].name, wDID)
    end
	
	for wDID, _ in pairs(starburstWeapons) do
		Script.SetWatchProjectile(wDID, true)
		allWatchedWeaponDefIDs[wDID] = "starburst"
	end   
	
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID) --pre-opt mean 3.7 us
	--Spring.Echo("gadget:ProjectileCreated",proID, proOwnerID, weaponDefID)
	local watchedWeaponType = allWatchedWeaponDefIDs[weaponDefID]
	if watchedWeaponType == nil then return end
	allWatchedProjectileIDs[proID] = watchedWeaponType
	if mapHasWater and watchedWeaponType == "depthCharge" then 
        local _,y,_ = GetProjectilePosition(proID)
        if y > 0 then
            depthCharges[proID] = depthChargeWeapons[weaponDefID]
        end
	elseif watchedWeaponType == "missile" then 
			missileIDtoProjType[proID] = missileWeapons[weaponDefID]
			missileIDtoLifeEnd[proID] = gameFrame-4 + GetProjectileTimeToLive(proID)
	elseif watchedWeaponType == "starburst" then 
		local x, y, z = GetProjectilePosition(proID)
		local groundHeight = GetGroundHeight(x, z)
		if groundHeight < 0 then
			groundHeight = 0
		end
		local gf = GetGameFrame()
		starbursts[proID] = {
			groundHeight + starburstWeapons[weaponDefID][1],
			starburstWeapons[weaponDefID][2],
			gf + starburstWeapons[weaponDefID][3],
			gf + starburstWeapons[weaponDefID][4],

			starburstWeapons[weaponDefID][5],
			groundHeight + starburstWeapons[weaponDefID][6],
			groundHeight + starburstWeapons[weaponDefID][7],

			starburstWeapons[weaponDefID][8],
			groundHeight + starburstWeapons[weaponDefID][9],
			groundHeight + starburstWeapons[weaponDefID][10],
		}
	end    
end

function gadget:ProjectileDestroyed(proID) --pre-opt mean 14 us
	local watchedWeaponType = allWatchedProjectileIDs[proID]
	if watchedWeaponType then 
		allWatchedProjectileIDs[proID] = nil
		if mapHasWater and watchedWeaponType == "depthCharge" then 
			depthCharges[proID] = nil
		elseif watchedWeaponType == "missile" then
			missileIDtoProjType[proID] = nil
			missileIDtoLifeEnd[proID] = nil
		elseif watchedWeaponType == "starburst" then 
			starbursts[proID] = nil
		end
	end
end


function gadget:GameFrame(gf)
	gameFrame = gf
	if mapHasWater then 
		for proID, CEG in pairs(depthCharges) do
			local x,y,z = GetProjectilePosition(proID)
			if y then
				if y < 0 then
					SpawnCEG(CEG,x,0,z)
					depthCharges[proID] = nil
					allWatchedProjectileIDs[proID] = nil
				end
			else
				depthCharges[proID] = nil
				allWatchedProjectileIDs[proID] = nil
			end
		end
	end
	
	for proID, missile in pairs(missileIDtoProjType) do
        if gf > missileIDtoLifeEnd[proID] then
            local x,y,z = GetProjectilePosition(proID)
            if y and y > 0 then
                local dirX,dirY,dirZ = GetProjectileDirection(proID)
                SpawnCEG(missile,x,y,z,dirX,dirY,dirZ)
            else
				missileIDtoProjType[proID] = nil
				missileIDtoLifeEnd[proID] = nil
				allWatchedProjectileIDs[proID] = nil
            end
        end
    end	
	
	for proID, missile in pairs(starbursts) do
		if gf <= missile[4] then
			local x, y, z = GetProjectilePosition(proID)
			if y and y > 0 then
				local dirX, dirY, dirZ = GetProjectileDirection(proID)
				if gf <= missile[3] or gf % 2 == 1 then
					-- add extra missiletrail
					SpawnCEG(missile[2], x, y, z, dirX, dirY, dirZ)
					if y <= missile[6] or (y <= missile[7] and gf % 2 == 1) then
						-- add ground dust
						SpawnCEG(missile[5], x, missile[1], z, dirX, dirY, dirZ)
					end
					if y <= missile[9] or (y <= missile[10] and gf % 2 == 1) then
						--add ground fire
						SpawnCEG(missile[8], x, missile[1], z, dirX, dirY, dirZ)
					end
				end
			else
				starbursts[proID] = nil
				allWatchedProjectileIDs[proID] = nil
			end
		else
			starbursts[proID] = nil
			allWatchedProjectileIDs[proID] = nil
		end
	end
end


