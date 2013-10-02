--NOTE: unitdefs_post does not deal with the normal lua UnitDefs table, it deals precisely with the UnitDef table from unit definition files.
--also it's case sensitive

if (Spring.GetModOptions) then
	local modOptions = Spring.GetModOptions()

  if (modOptions.mo_transportenemy == "com") then
  	for name,ud in pairs(UnitDefs) do  
      if (name == "armcom" or name == "corcom" or name == "armdecom" or name == "cordecom") then
        ud.transportbyenemy = false
      end
    end
  elseif (modOptions.mo_transportenemy == "all") then
  	for name, ud in pairs(UnitDefs) do  
			ud.transportbyenemy = false
		end
  end
  if (modOptions.mo_storageowner == "com") then
  	for name, ud in pairs(UnitDefs) do  
      if (name == "armcom" or name == "corcom") then
        ud.energyStorage = modOptions.startenergy or 1000
        ud.metalStorage = modOptions.startmetal or 1000
      end
    end
  end
	
end

				-- const float reqTurnAngle = math::fabs(180.0f * (owner->heading - wantedHeading) / SHORTINT_MAXVALUE);
				-- const float maxTurnAngle = (turnRate / SPRING_CIRCLE_DIVS) * 360.0f;

				-- float turnSpeed = (reversing)? maxReverseSpeed: maxSpeed;

				-- if (reqTurnAngle != 0.0f) {
					-- turnSpeed *= (maxTurnAngle / reqTurnAngle);
				-- }

				-- if (waypointDir.SqLength() > 0.1f) {
					-- if (!ud->turnInPlace) {
						-- targetSpeed = std::max(ud->turnInPlaceSpeedLimit, turnSpeed);
					-- } else {
						-- if (reqTurnAngle > ud->turnInPlaceAngleLimit) {
							-- targetSpeed = turnSpeed;
						-- }
					-- }
				-- }

				-- if (atEndOfPath) {
					-- // at this point, Update() will no longer call GetNextWayPoint()
					-- // and we must slow down to prevent entering an infinite circle
					-- targetSpeed = std::min(targetSpeed, (currWayPointDist * PI) / (SPRING_CIRCLE_DIVS / turnRate));
				-- }
local cons = {['armcv'] = true,
	['armacv']  = true,
	['consul'] = true,
	['armbeaver'] = true,
	['armch'] = true,
	['corcv'] = true,
	['coracv'] = true,
	['cormuskrat'] = true,
	['corch'] = true,}
local turninplacebots= {['corck'] = true,
	['corack'] = true,
	['corfast'] = true,
	['armck'] = true,
	['armack'] = true,
	['armfark'] = true,}
for name, ud in pairs(UnitDefs) do
	if (ud.maxvelocity) then 
		ud.turninplacespeedlimit = (ud.maxvelocity*0.66) or 0
		ud.turninplaceanglelimit = 140
	end
	if (ud.hoverattack) then
		ud.turninplaceanglelimit = 360
	end
	
	if (ud.brakerate) then 
		if ud.canfly then
			ud.brakerate = ud.brakerate * 0.04
		else 
			ud.brakerate = ud.brakerate * 3.0
		end
	end
	
	if ud.movementclass and (ud.movementclass:find("TANK",1,true) or ud.movementclass:find("HOVER",1,true)) then
		--Spring.Echo('tank or hover:',ud.name,ud.movementclass)
		if cons[name] then
			--Spring.Echo('tank or hover con:',ud.name,ud.moveData)
			ud.turninplace=1
			ud.turninplaceanglelimit=60
			ud.acceleration=ud.acceleration*2
			ud.brakerate=ud.brakerate*2
		elseif (ud.maxvelocity) then 
			ud.turninplace = 0
			ud.turninplacespeedlimit = (ud.maxvelocity*0.66) or 0
		end
	elseif ud.movementclass and (ud.movementclass:find("KBOT",1,true)) then
		if turninplacebots[name] then
			--Spring.Echo('turninplacekbot:',ud.name)
			ud.turninplace=1
			ud.turninplaceanglelimit=60
			ud.acceleration=ud.acceleration*2
			ud.brakerate=ud.brakerate*2
		elseif (ud.maxvelocity) then 
			ud.turninplaceanglelimit = 140
		end
	end

	if (name == 'armnanotc' or name == 'cornanotc') then
		ud.cantbetransported=false
	end
	ud.minCollisionSpeed = 0.0
	
end

-- Setting collisionvolumetest true for all units
for name, ud in pairs(UnitDefs) do
		ud.collisionvolumetest = 1
end