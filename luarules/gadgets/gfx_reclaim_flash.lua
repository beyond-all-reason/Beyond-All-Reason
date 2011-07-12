   function gadget:GetInfo()
      return {
        name      = "Reclaim flash",
        desc      = "Nice tree reclaim effect",
        author    = "Beherith",
        date      = "July 2011",
        license   = "PD",
        layer     = 0,
        enabled   = true,
      }
    end
     
if (not gadgetHandler:IsSyncedCode()) then
  return
end

function gadget:FeatureDestroyed(featureID,allyteam)
	fx,fy,fz=Spring.GetFeaturePosition(featureID)
	--Spring.Echo(allyteam)
	if (fx ~= nil) then
		rm, mm, re, me, rl = Spring.GetFeatureResources(featureID)
		if (rm ~= nil) then
			if mm==0 and re == 0 then
				Spring.SpawnCEG("sparklegreen", fx, fy, fz)
			end
		end
	end
end

