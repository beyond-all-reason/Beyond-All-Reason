function gadget:GetInfo()
    return {
        name      = 'Lightning Splash Damage',
        desc      = 'Handles Lightning Weapons Splash Damage',
        author    = 'TheFatController, Itanthias',
        version   = 'v2.1',
        date      = 'April 2011 (V1.0), Jan 2023 (V2.1)',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

--only run code in synced space
if not gadgetHandler:IsSyncedCode() then
    return false
end

-- needed for random surplus sparking effect
local random = math.random

-- Options here
local terminal_spark_effect = "genericshellexplosion-splash-lightning" -- can refactor into sparkWeapons if per-unit effects defined by customParams are desired
local visual_chain_weapon = WeaponDefNames["lightning_chain"].id -- can refactor into sparkWeapons if per-unit effects defined by customParams are desired

-- dictionary for in-game spark weapons
local sparkWeapons = {}

for wdid, wd in pairs(WeaponDefNames) do
	if wd.customParams ~= nil then
		if wd.customParams.spark_forkdamage ~= nil then
            Script.SetWatchWeapon(wd.id, true) -- watch weapon so ProjectileCreated works
			-- ZECRUS, values can be tuned in the unitdef file
			sparkWeapons[wd.id] = 	{
									ceg = wd.customParams.spark_ceg, -- currently overridden by above "global" options
									basedamage = tonumber(wd.damages[0]), --spark damage is assumed to be based on default damage 
									forkdamage = tonumber(wd.customParams.spark_forkdamage),
									maxunits = tonumber(wd.customParams.spark_maxunits),
									range = tonumber(wd.customParams.spark_range)
									}
		end
	end
end

-- look at this later, currently this makes these units completely immune to spark damage, friend or foe
local immuneToSplash = {
    [UnitDefNames.armzeus.id] = true,
	[UnitDefNames.armlatnk.id] = true,
    [UnitDefNames.armclaw.id] = true,
    [UnitDefNames.armthor.id] = true,
    [UnitDefNames.chickene1.id] = true,
    [UnitDefNames.chickene2.id] = true,
}
for udid, ud in pairs(UnitDefs) do
    for id, v in pairs(immuneToSplash) do
        if string.find(ud.name, UnitDefs[id].name) then
            immuneToSplash[udid] = v
        end
    end
end

local lightning_info = {} -- stores information related to every lighting bolt created in-game
local lightning_shooter = {} -- stores information related to units directly hit by lighting bolts
local lightning_shooter_ttl = {} -- stores information related to how long ago a unit was directly hit by lighting bolts

function gadget:GameFrame(frame)
  -- keep track of unit "primary target" to avoid self-chaining
  for attackerID, value in pairs(lightning_shooter_ttl) do
    -- if lightning_shooter[attackerID] was shot by attackerID, they are immune to sparks from attackerID for 3 frames
    lightning_shooter_ttl[attackerID] = lightning_shooter_ttl[attackerID] - 1 -- decrement counter
    if lightning_shooter_ttl[attackerID] == 0 then
      -- if counter reaches zero, set nil values
      lightning_shooter_ttl[attackerID] = nil
      lightning_shooter[attackerID] = nil
    end
  end

end

local SpringGetUnitsInSphere = Spring.GetUnitsInSphere
local SpringGetUnitDefID = Spring.GetUnitDefID
local SpringGetUnitPosition = Spring.GetUnitPosition
local SpringSpawnCEG = Spring.SpawnCEG
local SpringAddUnitDamage = Spring.AddUnitDamage
local SpringSpawnProjectile = Spring.SpawnProjectile
local SpringGetUnitIsDead = Spring.GetUnitIsDead 
local SpringGetGroundHeight = Spring.GetGroundHeight

-- this part handles the actual spark and chaining effect and applies damage
-- for a typical lighting bolt ttl = 1, main bolt strikes frame 1, spark bolts strike frame 2
function gadget:ProjectileDestroyed(proID)
  if lightning_info[proID] ~= nil then -- make sure we are handling lightning weapons
    
    local lightning = lightning_info[proID] -- shorter name
    local nearUnits = SpringGetUnitsInSphere(lightning.x,lightning.y,lightning.z,lightning.spark_range) -- get list of units in spark range
    local count = lightning.spark_maxunits -- set counter
    
    for i=1, #nearUnits do -- loop over nearby units
      
      if count == 0 then -- exit if maximum chain is reached
		-- clear from table
    	lightning_info[proID] = nil
		return
      end
      
      local nearUnit = nearUnits[i] -- get nearest unit
      local nearUnitDefID = SpringGetUnitDefID(nearUnit) -- get its unitdefID
      if not immuneToSplash[nearUnitDefID] then -- check if unit is immune to sparking
        if not SpringGetUnitIsDead(nearUnit) then -- check if unit is in "death animation", so sparks do not chain to dying units. 
          if lightning_shooter[lightning.proOwnerID] ~= nearUnit then --check if main bolt has hit this target or not
            local v1,v2,v3,v4,v5,v6, ex, ey, ez = SpringGetUnitPosition(nearUnit,true,true) -- gets aimpoint of unit
            SpringSpawnCEG(terminal_spark_effect,ex,ey,ez,0,0,0) -- spawns "electric aura" at spark target
            local spark_damage = lightning.spark_basedamage*lightning.spark_forkdamage -- figure out damage to apply to spark target
            -- NB: weaponDefID -1 is debris damage which gets removed by engine_hotfixes.lua, use -7 (crush damage) arbitrarily instead
            SpringAddUnitDamage(nearUnit, spark_damage, 0, lightning.proOwnerID, -7) -- apply damage to spark target
            -- create visual lighting arc from main bolt termination point to spark target
            -- set owner = -1 as a "spark bolt" identifier
            -- lightning.weaponDefID
            SpringSpawnProjectile(lightning.weaponDefID, {["pos"]={lightning.x,lightning.y,lightning.z},["end"] = {ex,ey,ez}, ["ttl"] = 2, ["owner"] = -1})
            count = count - 1 -- spark target count accounting
          end
        end
      end
    end
    
    -- special effects, for leftover chain
    for i=1, count, 3 do
      angle = random()*2*math.pi -- random angle, in radians
      pitch = random()*math.pi/2 -- random pitch, in radians
      -- convert to x,z and offset from main bolt termination point
      newx = lightning.x + math.cos(pitch)*math.sin(angle)*lightning.spark_range
      newz = lightning.z + math.cos(pitch)*math.cos(angle)*lightning.spark_range
      -- get height of random spark bolt termination point
      -- This may need to be tuned, steep slopes, cliffs, and uneven terrain may create weird visuals
      height1 = math.max(SpringGetGroundHeight(lightning.x,lightning.z),lightning.y) -- no vertical offset from ground seems needed for ground-strike bolts
      height2 = SpringGetGroundHeight(newx,newz)+5+(math.sin(pitch)*lightning.spark_range/2) 
	  -- offset by 5 units seems good for termination point of spark
      -- also pitch height is added, and squashed by a factor of 2 for an "ellipsoid" strike surface

      -- create effects
	  -- using special defined thinner bolt for left-over chain bolts
      SpringSpawnProjectile(visual_chain_weapon, {["pos"]={lightning.x,height1,lightning.z},["end"] = {newx,height2,newz}, ["ttl"] = 2, ["owner"] = -1})
      --SpringSpawnProjectile(lightning.weaponDefID, {["pos"]={lightning.x,height1,lightning.z},["end"] = {newx,height2,newz}, ["ttl"] = 2, ["owner"] = -1})
      SpringSpawnCEG(terminal_spark_effect,newx,height2,newz,0,0,0)
    end
    
    -- clear from table
    lightning_info[proID] = nil
  end
  
end

local SpringGetProjectilePosition = Spring.GetProjectilePosition
local SpringGetProjectileVelocity = Spring.GetProjectileVelocity


-- when a lighting bolt is created by a unit, save some info to a table, to be used to figure out sparking when the bolt despawns
function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
  if sparkWeapons[weaponDefID] then -- make sure we are handling lightning weapons
    if proOwnerID ~= -1 then -- make sure we are handling a main bolt, and not a spark bolt
    
      xp,yp,zp = SpringGetProjectilePosition(proID) -- get bolt start point
      xv,yv,zv = SpringGetProjectileVelocity(proID) -- get bolt length
      
      -- fill table, to be used in ProjectileDestroyed
      lightning_info[proID] = {}
      lightning_info[proID].weaponDefID = weaponDefID -- the lighting weapon used
      lightning_info[proID].proOwnerID = proOwnerID -- who shot it
      lightning_info[proID].spark_ceg = sparkWeapons[weaponDefID].ceg
      lightning_info[proID].spark_basedamage = sparkWeapons[weaponDefID].basedamage
      lightning_info[proID].spark_forkdamage = sparkWeapons[weaponDefID].forkdamage
      lightning_info[proID].spark_range = sparkWeapons[weaponDefID].range
      lightning_info[proID].spark_maxunits = sparkWeapons[weaponDefID].maxunits
      -- main bolt termination point
      lightning_info[proID].x = xp+xv
      lightning_info[proID].y = yp+yv
      lightning_info[proID].z = zp+zv

    end
  end
end

-- when a unit is directly hit by a lighting attack, keep track of that so the lighting weapon does not chain to the same target it hit. 
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
  -- using UnitPreDamaged to try to catch a unit being hit by a lightning bolt as soon as possible. UnitDamaged should also work, if necessary
  if sparkWeapons[weaponID] then
    
      -- engine does not provide a projectileID for hitscan weapons, bleh
      -- as a workaround, if a unit is shot by a lightning unit, make it immune to that unit's chaining for 3 frames
      lightning_shooter[attackerID] = unitID
      lightning_shooter_ttl[attackerID] = 3
      
  end
  return damage,1
end
