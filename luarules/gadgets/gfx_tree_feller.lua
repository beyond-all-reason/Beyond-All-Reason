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
    

        --Echo("gadget:FeatureDamaged(featureID, featureDefID, featureTeam,Damage, weaponDefID,projectileID,     attackerID, attackerDefID, attackerTeam)")
        --Echo(featureID, featureDefID, featureTeam,Damage, weaponDefID,   projectileID,  attackerID, attackerDefID, attackerTeam)
        --Echo('weaponDefID',WeaponDefs[weaponDefID])
        
        if (fx ~= nil) then
            local health, maxhealth, _ = GetFeatureHealth(featureID)
            --Echo('health=',health,' fx=',fx)
            if (Damage > health) then 
                local remainingMetal, maxMetal, remainingEnergy, maxEnergy, reclaimLeft= GetFeatureResources(featureID)
                if (health ~= nil and maxMetal==0 and maxEnergy > 0 and (health < Damage or weaponDefID==-7)) then -- weaponDefID == -7 is the weapon that crushes features
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
					if projectileID > 0 then
						ppx, ppy, ppz = Spring.GetProjectilePosition(projectileID)
						local vpx, vpy, vpz = Spring.GetProjectileVelocity(projectileID)
						ppx = ppx - 5*vpx
						ppy = ppy - 5*vpy
						ppz = ppz - 5*vpz
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, dmg)
					elseif attackerID then 
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						dmg = math.min(FeatureDefs[featureDefID].mass * 2, UnitDefs[attackerDefID].mass)
					end
                    SetFeatureReclaim(featureID,0)
                    treesdying[featureID]={ frame = GetGameFrame(), posx=fx, posy=fy, posz=fz,fDefID=featureDefID, dirx=dx, diry=dy, dirz=dz, px = ppx, py = ppy, pz = ppz, strength = FeatureDefs[featureDefID].mass / dmg }
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
            local thisfeaturefalltime = falltime * featureinfo.strength
			local thisfeaturefallspeed = fallspeed * featureinfo.strength
            if gf-featureinfo.frame~= 0 then
                local factor = (gf-featureinfo.frame)/thisfeaturefallspeed
                local fx,fy,fz = GetFeaturePosition(featureID)
				local px, py, pz = featureinfo.px, featureinfo.py, featureinfo.pz
                if fy ~= nil then
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
                    SetFeaturePosition(featureID, fx,fy-0.55/thisfeaturefalltime,fz, false)
                    SetFeatureDirection(featureID, featureinfo.dirx , factor*factor , featureinfo.dirz )
                end

                --Odd things about SetFeatureDirection : X is spin around y axis, and so is Y :(
                --TODO: make features rotate in the direction they were damaged from!
                --SetFeatureDirection( featureID,  featureinfo.dirx , featureinfo.diry, factor*factor ) 
            end
            
            if (featureinfo.frame + thisfeaturefalltime < gf) then
                local fx,fy,fz = GetFeaturePosition(featureID)
                if fy ~= nil then
                    local dx, dy ,dz = GetFeatureDirection( featureID)
                    SetFeaturePosition(featureID, fx,fy-0.6,fz, false)
                    SetFeatureDirection(featureID,dx, dy ,dz)
                end
                if featureinfo.frame + falltime + 100 < gf then
                    treesdying[featureID]=nil
                    -- Echo('removing feature',featureID)
                    DestroyFeature(featureID)
                end
            end
        end
    end
end