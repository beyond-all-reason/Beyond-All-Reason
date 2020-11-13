local GaiaAllyTeamID = GaiaAllyTeamID or 999
if not scavconfig then
	heighttollerance = 30
	noheightchecksforwater = true
else
	heighttollerance = scavconfig.other.heighttolerance
	noheightchecksforwater = scavconfig.other.noheightchecksforwater
end
-- Check height diffrences
function posCheck(posx, posy, posz, posradius)
	-- if true then position is valid
	local posradius = posradius or 1000
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	local deathwater = Game.waterDamage
	if noheightchecksforwater and (not deathwater or deathwater == 0) and posy <= 0 then
		return true
	elseif deathwater > 0 and posy <= 0 then
		return false
	elseif testpos1 < posy - heighttollerance or testpos1 > posy + heighttollerance then
		return false
	elseif testpos2 < posy - heighttollerance or testpos2 > posy + heighttollerance then
		return false
	elseif testpos3 < posy - heighttollerance or testpos3 > posy + heighttollerance then
		return false
	elseif testpos4 < posy - heighttollerance or testpos4 > posy + heighttollerance then
		return false
	elseif testpos5 < posy - heighttollerance or testpos5 > posy + heighttollerance then
		return false
	elseif testpos6 < posy - heighttollerance or testpos6 > posy + heighttollerance then
		return false
	elseif testpos7 < posy - heighttollerance or testpos7 > posy + heighttollerance then
		return false
	elseif testpos8 < posy - heighttollerance or testpos8 > posy + heighttollerance then
		return false
	else
		return true
	end
end

-- Check if area is occupied
function posOccupied(posx, posy, posz, posradius)
	-- if true then position isn't occupied
	local posradius = posradius or 1000
	local unitcount = #Spring.GetUnitsInRectangle(posx-posradius, posz-posradius, posx+posradius, posz+posradius)
	if unitcount > 0 then
		return false
	else
		return true
	end
end

-- Check if area is visible for any player
function posLosCheck(posx, posy, posz, posradius)
	-- if true then position is not in player LoS(includes radar)
	local posradius = posradius or 1000
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInRadar(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
				return false
			end
		end
	end
	return true
end

function posFriendlyCheckOnlyLos(posx, posy, posz, allyTeamID)
	return Spring.IsPosInLos(posx, posy, posz, allyTeamID)
end

function posLosCheckNoRadar(posx, posy, posz, posradius)
	-- if true then position is not in player LoS(excludes radar)
	local posradius = posradius or 1000
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
				return false
			end
		end
	end
	return true
end

function posLosCheckReversed(posx, posy, posz, posradius)
	-- if true then position is in player LoS(excludes radar)
	local posradius = posradius or 1000
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
				return true
			end
		end
	end
	return false
end

function posLosCheckOnlyLOS(posx, posy, posz, posradius)
	-- if true then position is in player LoS(excludes radar and airLoS)
	local posradius = posradius or 1000
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
			return false
			end
		end
	end
	return true
end

function posStartboxCheck(posx, posy, posz, posradius)
	-- if true then position is within scav startbox
	local posradius = posradius or 1000
	if ScavengerStartboxExists and posx <= ScavengerStartboxXMax and posx >= ScavengerStartboxXMin and posz >= ScavengerStartboxZMin and posz <= ScavengerStartboxZMax then
		return false
	else
		return true
	end
end

function posSafeAreaCheck(posx, posy, posz, posradius)
	-- if true then position is within scav safe position
	
	--ScavSafeAreaMinX
	--ScavSafeAreaMaxX
	--ScavSafeAreaMinZ
	--ScavSafeAreaMaxZ
	local posradius = posradius or 1000
	if ScavSafeAreaExist and posx <= ScavSafeAreaMaxX and posx >= ScavSafeAreaMinX and posz >= ScavSafeAreaMinZ and posz <= ScavSafeAreaMaxZ then
		return false
	else
		return true
	end
end

function posMapsizeCheck(posx, posy, posz, posradius)
	-- if true then position is far enough from map border
	local posradius = posradius or 1000
	if posx + posradius >= mapsizeX or posx - posradius <= 0 or posz - posradius <= 0 or posz + posradius >= mapsizeZ then
		return false
	else
		return true
	end
end

function posLandCheck(posx, posy, posz, posradius)
	-- if true then position is safe for land units
	local posradius = posradius or 1000
	local testpos0 = Spring.GetGroundHeight((posx), (posz))
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	local deathwater = Game.waterDamage
	
	
	if testpos0 <= 0 then
		return false
	elseif testpos1 <= 0 then
		return false
	elseif testpos2 <= 0 then
		return false
	elseif testpos3 <= 0 then
		return false
	elseif testpos4 <= 0 then
		return false
	elseif testpos5 <= 0 then
		return false
	elseif testpos6 <= 0 then
		return false
	elseif testpos7 <= 0 then
		return false
	elseif testpos8 <= 0 then
		return false
	elseif deathwater > 0 then
		return false
	else
		return true
	end
end

function posSeaCheck(posx, posy, posz, posradius)
	-- if true then position is safe for water units
	local posradius = posradius or 1000
	local testpos0 = Spring.GetGroundHeight((posx), (posz))
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	local deathwater = Game.waterDamage
	
	
	if testpos0 > 0 then
		return false
	elseif testpos1 > 0 then
		return false
	elseif testpos2 > 0 then
		return false
	elseif testpos3 > 0 then
		return false
	elseif testpos4 > 0 then
		return false
	elseif testpos5 > 0 then
		return false
	elseif testpos6 > 0 then
		return false
	elseif testpos7 > 0 then
		return false
	elseif testpos8 > 0 then
		return false
	elseif deathwater > 0 then
		return false
	else
		return true
	end
end