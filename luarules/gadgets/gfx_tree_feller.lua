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
	local treefirewpnname = "trees_fire"
	local treefirecegname = "treeburn"
	local treefireExplosion = {
		   weaponDef = WeaponDefNames[treefirewpnname].id,
		   -- owner = -1,
		   hitUnit = 1,
		   hitFeature = 1,
		   craterAreaOfEffect = 64,
		   damageAreaOfEffect = 64,
		   edgeEffectiveness = 1,
		   explosionSpeed = 1,
		   impactOnly = false,
		   ignoreOwner = false,
		   damageGround = true,
		   }
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
        if treesdying[featureID] then --dying trees dont take more damage, and will be removed later
            --Echo('damage removed',Damage,featureID)
            return 0.0 , 0.0
        end
        local fx,fy,fz = GetFeaturePosition(featureID)
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
                if (health ~= nil and maxMetal==0 and maxEnergy > 0 and (health <= Damage or weaponDefID==-7)) then -- weaponDefID == -7 is the weapon that crushes features
                    --if crushed, attackerID returns unit, but projectileID is nil, if projectile destroys feature, then attackerID is nil, but projectileID contains the projectile.
                    --Echo('tree dying...',featureID)
                    local dx, dy ,dz= GetFeatureDirection( featureID)
                    -- Echo(featureID,'direction:', dx, dy, dz)
                    SetFeatureBlocking(featureID, false,false,false,false,false,false,false) --doesnt block anything
                    if (weaponDefID == -7) then --weapon is crush
                        --Echo('tree crushed... ',featureID)
                        --crushed features cannot be saved by returning 0 damage. Must create new one!
                        featureID = CreateFeature(featureDefID,fx,fy,fz)
                        SetFeatureDirection(featureID,dx, dy ,dz)
                        SetFeatureBlocking(featureID, false,false,false,false,false,false,false) 
                        --Echo('tree created... ',featureID)
                    else
                        Damage=0.0 -- so it doesnt take multiple frames for tree to get killed.
                    end
					if weaponDefID == WeaponDefNames[treefireExplosion].id then -- TREE CAUGHT FIRE FROM OTHER TREE
						ppx, ppy, ppz = GetFeaturePosition(featureID)
						ppx, ppy, ppz = ppx +math.random(-5,5), ppy +math.random(-5,5), ppz +math.random(-5,5) -- we don't have an attacker pos/projpos
						dmg = 40
						fire = true
					elseif projectileID > 0 then -- PROJECTILE EXPLOSION
						ppx, ppy, ppz = Spring.GetProjectilePosition(projectileID)
						local vpx, vpy, vpz = Spring.GetProjectileVelocity(projectileID)
						ppx = ppx - 2*vpx
						ppy = ppy - 2*vpy
						ppz = ppz - 2*vpz
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, dmg)
						fire = true
					elseif attackerID and weaponDefID < 0 then -- CRUSH
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						local vpx, vpy, vpz = Spring.GetUnitVelocity(attackerID)
						ppx = ppx - 2*vpx
						ppy = ppy - 2*vpy
						ppz = ppz - 2*vpz
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, UnitDefs[attackerDefID].mass)
						fire = false
					elseif attackerID then -- UNITEXPLOSION
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, dmg)	
						fire = true
					end
					local name = FeatureDefs[featureDefID].name
					if fire and string.find(name,"lowpoly_tree_") then
						if not (string.find(name, "burnt")) then
							name = string.sub(name, string.find(name, "pinetree"), string.len(name))
							DestroyFeature(featureID)
							featureID = CreateFeature(("lowpoly_tree_"..name.."burnt"),fx,fy,fz)
							SetFeatureDirection(featureID,dx, dy ,dz)
							SetFeatureBlocking(featureID, false,false,false,false,false,false,false)
						end
					else
						fire = false
					end
                    SetFeatureReclaim(featureID,0)
                    treesdying[featureID]={ frame = GetGameFrame(), posx=fx, posy=fy, posz=fz,fDefID=featureDefID, dirx=dx, diry=dy, dirz=dz, px = ppx, py = ppy, pz = ppz, strength = FeatureDefs[featureDefID].mass / dmg, fire = fire }
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

    function gadget:GameFrame(gf)
        for featureID, featureinfo in pairs(treesdying) do
		if not GetFeaturePosition(featureID) then
			treesdying[featureID] = nil
			DestroyFeature(featureID)
		else
            SetFeatureReclaim(featureID,0)
            local thisfeaturefalltime = falltime * featureinfo.strength
			local thisfeaturefallspeed = fallspeed * featureinfo.strength
            if featureinfo.frame + thisfeaturefalltime > gf then
                local factor = (gf-featureinfo.frame)/thisfeaturefallspeed
                local fx,fy,fz = GetFeaturePosition(featureID)
				local px, py, pz = featureinfo.px, featureinfo.py, featureinfo.pz
                if fy ~= nil then
					if featureinfo.fire then
						if gf%1 == featureID%1 then
							local firex, firey, firez = fx+math.random(-5,5), fy+math.random(-5,5), fz+math.random(-5,5)
							if gf%10 == featureID%10 then
								if math.random(1,3) == 1 then Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion) end
							end
							Spring.SpawnCEG(treefirecegname, firex,firey,firez,0,0,0,0,0,0)
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
            elseif (featureinfo.frame + thisfeaturefalltime <= gf) then
                local fx,fy,fz = GetFeaturePosition(featureID)
                if fy ~= nil then
                    local dx, dy ,dz = GetFeatureDirection(featureID)
					if featureinfo.fire then
						if gf%3 == featureID%3 then
							local firex, firey, firez = fx+math.random(-5,5), fy+math.random(-5,5), fz+math.random(-5,5)
							if gf%30 == featureID%30 then
								if math.random(1,3) == 1 then Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion) end	
							end
							Spring.SpawnCEG(treefirecegname, firex,firey,firez,0,0,0,0,0,0)
						end
					end
                    SetFeatureDirection(featureID,dx, dy ,dz)
                end
                if featureinfo.frame + thisfeaturefalltime + 100 <= gf then
					if featureinfo.fire then
						if gf%6 == featureID%6 then
							local firex, firey, firez = fx+math.random(-5,5), fy+math.random(-5,5), fz+math.random(-5,5)
							if gf%60 == featureID%60 then
								if math.random(1,3) == 1 then Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion) end	
							end
							Spring.SpawnCEG(treefirecegname, firex,firey,firez,0,0,0,0,0,0)
						end
					end
					if math.random(1,30) == 1 then
						treesdying[featureID]=nil
						-- Echo('removing feature',featureID)
						DestroyFeature(featureID)
					end
                end
            end
        end
		end
    end
end