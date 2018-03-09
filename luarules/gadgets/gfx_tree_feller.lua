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
     

    local GetFeaturePosition     = Spring.GetFeaturePosition
    local GetFeatureHealth     = Spring.GetFeatureHealth
    local GetFeatureDirection     = Spring.GetFeatureDirection
    local GetFeatureResources     = Spring.GetFeatureResources
    local GetUnitDefID             = Spring.GetUnitDefID
    local GetUnitPosition        = Spring.GetUnitPosition
    local SetFeatureDirection        = Spring.SetFeatureDirection
    local SetFeatureBlocking        = Spring.SetFeatureBlocking
    local SetFeaturePosition = Spring.SetFeaturePosition
    local CreateFeature        = Spring.CreateFeature
    local DestroyFeature        = Spring.DestroyFeature
    local GetGameFrame        = Spring.GetGameFrame
    local ValidUnitID        = Spring.ValidUnitID
    local GetUnitPosition        = Spring.GetUnitPosition
    local Echo        = Spring.Echo

    local treesdying={}
    local falltime = 60.0 -- in frames
    local fallspeed = 25.0
    local gaiaTeamID = Spring.GetGaiaTeamID()
    --local treesdying={}
    function gadget:Initialize()
        return
    end  
    function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, Damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
        if (FeatureDefs[featureDefID]["name"]:find('treetype')~= nil) then 
            --Echo('not killing engine tree')
            return Damage, 0.0
        end
        if treesdying[featureID] then --dying trees dont take more damage, and will be removed later
            --Echo('damage removed',Damage,featureID)
            return 0.0 , 0.0
        end
        local fx,fy,fz=GetFeaturePosition(featureID)
    

        --Echo("gadget:FeatureDamaged(featureID, featureDefID, featureTeam,Damage, weaponDefID,projectileID,     attackerID, attackerDefID, attackerTeam)")
        --Echo(featureID, featureDefID, featureTeam,Damage, weaponDefID,   projectileID,  attackerID, attackerDefID, attackerTeam)
        --Echo('weaponDefID',WeaponDefs[weaponDefID])
        
        if (fx ~= nil) then
            local health, maxhealth, _=GetFeatureHealth(featureID)        
            --Echo('health=',health,' fx=',fx)
            if (Damage > health) then 
                local remainingMetal, maxMetal, remainingEnergy, maxEnergy, reclaimLeft= GetFeatureResources(featureID)
                if (health ~= nil and maxMetal==0 and maxEnergy > 0 and (health < Damage or weaponDefID==-7)) then -- weaponDefID == -7 is the weapon that crushes features
                    --if crushed, attackerID returns unit, but projectileID is nil, if projectile destroys feature, then attackerID is nil, but projectileID contains the projectile.
                    --Echo('tree dying...',featureID)
                    local dx, dy ,dz= GetFeatureDirection( featureID)
                    -- Echo(featureID,'direction:', dx, dy, dz)
                    SetFeatureBlocking(featureID, false,false,false,false,false,false,false) --doesnt block anything
                    if (weaponDefID==-7) then --weapon is crush
                        --Echo('tree crushed... ',featureID)
                        --crushed features cannot be saved by returning 0 damage. Must create new one!
                        featureID=CreateFeature(featureDefID,fx,fy,fz)
                        SetFeatureDirection(featureID,dx, dy ,dz)
                        SetFeatureBlocking(featureID, false,false,false,false,false,false,false) 
                        --Echo('tree created... ',featureID)
                    else
                        Damage=0.0 -- so it doesnt take multiple frames for tree to get killed.
                    end
                    
                    treesdying[featureID]={ frame = GetGameFrame(), posx=fx, posy=fy, posz=fz,fDefID=featureDefID, dirx=dx, diry=dy, dirz=dz,}
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
            
            if gf-featureinfo.frame~= 0 then
                local factor = (gf-featureinfo.frame)/fallspeed
                local fx,fy,fz = GetFeaturePosition(featureID)
                SetFeaturePosition(featureID, fx,fy-0.55,fz, false)
                SetFeatureDirection( featureID, featureinfo.dirx , factor*factor , featureinfo.dirz/(gf-featureinfo.frame) )

                --local fx,fy,fz = GetFeaturePosition(featureID)
                --SetFeaturePosition(featureID, fx,fy,fz, false)

                --Odd things about SetFeatureDirection : X is spin around y axis, and so is Y :(
                --TODO: make features rotate in the direction they were damaged from!
                --SetFeatureDirection( featureID,  featureinfo.dirx , featureinfo.diry, factor*factor ) 
            end
            
            if (featureinfo.frame +falltime < gf) then

                local fx,fy,fz = GetFeaturePosition(featureID)
                local dx, dy ,dz= GetFeatureDirection( featureID)
                SetFeaturePosition(featureID, fx,fy-0.6,fz, false)
                SetFeatureDirection(featureID,dx, dy ,dz)

                if featureinfo.frame +falltime+120 < gf then
                    treesdying[featureID]=nil
                    -- Echo('removing feature',featureID)
                    DestroyFeature(featureID)
                end
            end
        end
    end

end