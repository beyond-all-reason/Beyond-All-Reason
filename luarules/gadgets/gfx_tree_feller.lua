function gadget:GetInfo()
  return {
    name      = "Tree feller",
    desc      = "Destroyes features that have 0 m and >0 energy",
    author    = "Beherith",
    date      = "march 201",
    license   = "CC BY NC ND",
    layer     = 0,
    enabled   = true,
  }
end

if  (gadgetHandler:IsSyncedCode()) then
	local treefireExplosion = {
		tiny = {
			weaponDef = WeaponDefNames['treefire_tiny'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 38,
			damageAreaOfEffect = 38,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
		small = {
			weaponDef = WeaponDefNames['treefire_small'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 44,
			damageAreaOfEffect = 44,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
		medium = {
			weaponDef = WeaponDefNames['treefire_medium'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 50,
			damageAreaOfEffect = 50,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
		large = {
			weaponDef = WeaponDefNames['treefire_large'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 58,
			damageAreaOfEffect = 58,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
	}
	local treeWeapons = {}
	treeWeapons[WeaponDefNames['treefire_tiny'].id] = true
	treeWeapons[WeaponDefNames['treefire_small'].id] = true
	treeWeapons[WeaponDefNames['treefire_medium'].id] = true
	treeWeapons[WeaponDefNames['treefire_large'].id] = true

	local noFireWeapons = {}
	for id, wDefs in pairs(WeaponDefs) do
		if wDefs.customParams and wDefs.customParams.nofire then
			noFireWeapons[id] = true
		end
	end
    local GetFeaturePosition  = Spring.GetFeaturePosition
    local GetFeatureHealth = Spring.GetFeatureHealth
    local GetFeatureDirection = Spring.GetFeatureDirection
    local GetFeatureResources = Spring.GetFeatureResources
    local SetFeatureDirection = Spring.SetFeatureDirection
    local SetFeatureBlocking = Spring.SetFeatureBlocking
    local SetFeaturePosition = Spring.SetFeaturePosition
    local SetFeatureReclaim = Spring.SetFeatureReclaim
    local CreateFeature = Spring.CreateFeature
    local DestroyFeature = Spring.DestroyFeature
    local GetGameFrame = Spring.GetGameFrame

    local treesdying = {}
    local falltime = 55.0 -- in frames
    local fallspeed = 25.0
	
    function gadget:Initialize()
        return
    end

    function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, Damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		local dmg = Damage
        if (FeatureDefs[featureDefID]["name"]:find('treetype')~= nil) then 
            --Echo('not killing engine tree')
            return Damage, 0.0
        end
        local fx,fy,fz = GetFeaturePosition(featureID)
        if treesdying[featureID] then --dying trees dont take more damage, and will be removed later
			if weaponDefID >= 0 and not (noFireWeapons[weaponDefID]) then -- UNITEXPLOSION
				if fy and fy >= 0 then
					treesdying[featureID].fire = true
				end
			end
            --Echo('damage removed',Damage,featureID)
            return 0.0 , 0.0
        end
		local fire
		local ppx, ppy, ppz
        --Echo("gadget:FeatureDamaged(featureID, featureDefID, featureTeam,Damage, weaponDefID,projectileID,     attackerID, attackerDefID, attackerTeam)")
        --Echo(featureID, featureDefID, featureTeam,Damage, weaponDefID,   projectileID,  attackerID, attackerDefID, attackerTeam)
        --Echo('weaponDefID',WeaponDefs[weaponDefID])
        if (fx ~= nil) then
            local health, maxhealth, _ = GetFeatureHealth(featureID)
            --Echo('health=',health,' fx=',fx)
            if (Damage >= health) then 
                local remainingMetal, maxMetal, remainingEnergy, maxEnergy, reclaimLeft= GetFeatureResources(featureID)
				local dissapearSpeed = 1
				local size = 'medium'
				if FeatureDefs[featureDefID].collisionVolume and FeatureDefs[featureDefID].collisionVolume.scaleY then
					if FeatureDefs[featureDefID].collisionVolume.scaleY < 40 then
						size = 'tiny'
					elseif FeatureDefs[featureDefID].collisionVolume.scaleY < 50 then
						size = 'small'
					elseif FeatureDefs[featureDefID].collisionVolume.scaleY > 65 then
						size = 'large'
					end
					dissapearSpeed = 0.02 + Spring.GetFeatureHeight(featureID) / math.random(3700,4700)
				end
				local destroyFrame = GetGameFrame() + (falltime * (FeatureDefs[featureDefID].mass / dmg)) + 150 + (dissapearSpeed*4000)

                if (health ~= nil and maxMetal==0 and maxEnergy > 0 and (health <= Damage or weaponDefID==-7)) then -- weaponDefID == -7 is the weapon that crushes features
                    --if crushed, attackerID returns unit, but projectileID is nil, if projectile destroys feature, then attackerID is nil, but projectileID contains the projectile.
                    --Echo('tree dying...',featureID)
                    local dx, dy ,dz= GetFeatureDirection( featureID)
                    -- Echo(featureID,'direction:', dx, dy, dz)
                    SetFeatureBlocking(featureID, false,false,false,false,false,false,false) --doesnt block anything
                    if (weaponDefID == -7) then --weapon is crush
                        --Echo('tree crushed... ',featureID)
                        --crushed features cannot be saved by returning 0 damage. Must create new one!
						DestroyFeature(featureID)
						treesdying[featureID]={ frame = GetGameFrame(), posx=fx, posy=fy, posz=fz,fDefID=featureDefID, dirx=dx, diry=dy, dirz=dz, px = ppx, py = ppy, pz = ppz, strength = FeatureDefs[featureDefID].mass / dmg, fire = fire, size = size, dissapearSpeed = dissapearSpeed, destroyFrame = destroyFrame } -- this prevents this tobedestroyed feature to be replaced multiple times
                        featureID = CreateFeature(featureDefID,fx,fy,fz)
                        SetFeatureDirection(featureID,dx, dy ,dz)
                        SetFeatureBlocking(featureID, false,false,false,false,false,false,false) 
                        --Echo('tree created... ',featureID)
                    else
                        Damage=0.0 -- so it doesnt take multiple frames for tree to get killed.
                    end
					if treeWeapons[weaponDefID] then -- TREE CAUGHT FIRE FROM OTHER TREE
						ppx, ppy, ppz = GetFeaturePosition(featureID)
						ppx, ppy, ppz = ppx +math.random(-5,5), ppy +math.random(-5,5), ppz +math.random(-5,5) -- we don't have an attacker pos/projpos
						dmg = 40
						if fy >= 0 then
							fire = true
						end
					elseif projectileID > 0 and weaponDefID and not (noFireWeapons[weaponDefID]) then -- PROJECTILE EXPLOSION
						ppx, ppy, ppz = Spring.GetProjectilePosition(projectileID)
						local vpx, vpy, vpz = Spring.GetProjectileVelocity(projectileID)
						ppx = ppx - 2*vpx
						ppy = ppy - 2*vpy
						ppz = ppz - 2*vpz
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, dmg)
						if fy >= 0 then
							fire = true
						end
					elseif attackerID and weaponDefID < 0 then -- CRUSH
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						local vpx, vpy, vpz = Spring.GetUnitVelocity(attackerID)
						ppx = ppx - 2*vpx
						ppy = ppy - 2*vpy
						ppz = ppz - 2*vpz
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, UnitDefs[attackerDefID].mass)
						fire = false
					elseif attackerID and weaponDefID and not (noFireWeapons[weaponDefID]) then -- UNITEXPLOSION
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, dmg)	
						if fy >= 0 then
							fire = true
						end
					end
					local name = FeatureDefs[featureDefID].name
					if fire and string.find(name,"lowpoly_tree_") then
						if not (string.find(name, "burnt")) then
							name = string.sub(name, string.find(name, "pinetree"), string.len(name))
							DestroyFeature(featureID)
							treesdying[featureID]={frame = GetGameFrame(), posx=fx, posy=fy, posz=fz,fDefID=featureDefID, dirx=dx, diry=dy, dirz=dz, px = ppx, py = ppy, pz = ppz, strength = FeatureDefs[featureDefID].mass / dmg, fire = fire, size = size, dissapearSpeed = dissapearSpeed, destroyFrame = destroyFrame } -- this prevents this tobedestroyed feature to be replaced multiple times
							featureID = CreateFeature(("lowpoly_tree_"..name.."burnt"),fx,fy,fz)
							SetFeatureDirection(featureID,dx, dy ,dz)
							SetFeatureBlocking(featureID, false,false,false,false,false,false,false)
						end
					else
						fire = false
					end
                    SetFeatureReclaim(featureID,0)
					Spring.SetFeatureNoSelect(featureID, true)
                    treesdying[featureID]={ frame = GetGameFrame(), posx=fx, posy=fy, posz=fz,fDefID=featureDefID, dirx=dx, diry=dy, dirz=dz, px = ppx, py = ppy, pz = ppz, strength = FeatureDefs[featureDefID].mass / dmg, fire = fire, size = size, dissapearSpeed = dissapearSpeed, destroyFrame = destroyFrame }
                else
                    --Echo("feature not a dying tree")
                end
            else
                --Echo("Feature has more health than damage dealt")
            end
        end
        --Echo("passthrough damage=",Damage)
        return Damage, 0.0
    end
	
	function gadget:FeatureDestroyed(fid)
	end
	
    function gadget:GameFrame(gf)
        for featureID, featureinfo in pairs(treesdying) do
			if not GetFeaturePosition(featureID) then
				treesdying[featureID] = nil
				DestroyFeature(featureID)
			else
				SetFeatureReclaim(featureID,0)
				local thisfeaturefalltime = falltime * featureinfo.strength
				local thisfeaturefallspeed = fallspeed * featureinfo.strength
				local fireFrequency = 5
				if featureinfo.fire then
					fireFrequency = math.floor(2 + ((gf - featureinfo.frame) / 70))
				end

				-- falling
				if featureinfo.frame + thisfeaturefalltime > gf then
					local factor = (gf-featureinfo.frame)/thisfeaturefallspeed
					local fx,fy,fz = GetFeaturePosition(featureID)
					local px, py, pz = featureinfo.px, featureinfo.py, featureinfo.pz
					if fy ~= nil then
						if featureinfo.fire then
							if gf%fireFrequency == math.floor(fireFrequency/1.5) then
								local firex, firey, firez = fx+math.random(-3,3), fy+math.random(-3,3), fz+math.random(-3,3)
								local pos =  math.random(12,17)
								firex = firex - (featureinfo.dirx*pos)
								firez = firez - (featureinfo.dirz*pos)
								Spring.SpawnCEG('treeburn-'..treesdying[featureID].size, firex,firey,firez,0,0,0,0,0,0)
							end
							if gf%fireFrequency == math.floor(fireFrequency/3) and math.random(1,5) == 1 then
								local firex, firey, firez = fx+math.random(-3,3), fy+math.random(-3,3), fz+math.random(-3,3)
								local pos =  math.random(12,17)
								firex = firex - (featureinfo.dirx*pos)
								firez = firez - (featureinfo.dirz*pos)
								Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion[featureinfo.size])
							end
						end
						if px and py and pz then
							local difx = px-fx
							local difz = pz-fz
							local dirx = (((difx^2 + difz^2)) ~= 0) and math.sqrt((difx^2/(difx^2 + difz^2))) or 0
							local dirz = (((difx^2 + difz^2)) ~= 0) and math.sqrt((difz^2/(difx^2 + difz^2))) or 0
							if difx < 0 then dirx = - dirx end
							if difz < 0 then dirz = - dirz end
							featureinfo.dirx = dirx
							featureinfo.diry = py-fy
							featureinfo.dirz = dirz
						end
						SetFeatureDirection(featureID, featureinfo.dirx , factor*factor , featureinfo.dirz )
					end

				-- fallen
				elseif (featureinfo.frame + thisfeaturefalltime <= gf) then
					local fx,fy,fz = GetFeaturePosition(featureID)
					local dx, dy ,dz = GetFeatureDirection(featureID)
					if fy ~= nil then
						if featureinfo.fire then
							if gf%fireFrequency == math.floor(fireFrequency/1.5) then
								local firex, firey, firez = fx+math.random(-3,3), fy+math.random(-3,3), fz+math.random(-3,3)
								local pos =  math.random(12,17)
								firex = firex - (featureinfo.dirx*pos)
								firez = firez - (featureinfo.dirz*pos)
								Spring.SpawnCEG('treeburn-'..treesdying[featureID].size, firex,firey,firez,0,0,0,0,0,0)
							end
							if gf%fireFrequency == math.floor(fireFrequency/3) and math.random(1,6) == 1 then
								local firex, firey, firez = fx+math.random(-3,3), fy+math.random(-3,3), fz+math.random(-3,3)
								local pos =  math.random(12,17)
								firex = firex - (featureinfo.dirx*pos)
								firez = firez - (featureinfo.dirz*pos)
								Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion[featureinfo.size])
							end
						end
						SetFeatureDirection(featureID, dx, dy, dz)		-- gets reset so we re-apply

						if featureinfo.destroyFrame <= gf then
							treesdying[featureID]=nil
							DestroyFeature(featureID)
						elseif featureinfo.frame + thisfeaturefalltime + 250 <= gf and treesdying[featureID].fire then
							treesdying[featureID].fire = false
						elseif featureinfo.frame + thisfeaturefalltime + 100 <= gf then
							if treesdying[featureID].fire then
								SetFeaturePosition(featureID, fx, fy-treesdying[featureID].dissapearSpeed, fz, false)
							else
								SetFeaturePosition(featureID, fx, fy-treesdying[featureID].dissapearSpeed*6, fz, false)
							end
							SetFeatureDirection(featureID, dx, dy, dz)		-- gets reset so we re-apply
						end
					end
				end
			end
		end
    end
end