
Spring.Echo("[Scavengers] API initialized")

	-- variables
	GaiaTeamID = Spring.GetGaiaTeamID()
	_,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)
	mapsizeX = Game.mapSizeX
	mapsizeZ = Game.mapSizeZ
	teamcount = #Spring.GetTeamList() - 2
	allyteamcount = #Spring.GetAllyTeamList() - 1
	spawnmultiplier = tonumber(Spring.GetModOptions().scavengers) or 1
	selfdx = {}
	selfdy = {}
	selfdz = {}
	oldselfdx = {}
	oldselfdy = {}
	oldselfdz = {}
	scavNoSelfD = {}
	UDN = UnitDefNames
	scavStructure = {}
	scavConstructor = {}
	scavAssistant = {}
	scavResurrector = {}
	scavFactory = {}
	scavCollector = {}

	-- check for solo play
	if teamcount <= 0 then
   	teamcount = 1
	end
   	if allyteamcount <= 0 then
   	allyteamcount = 1
	end

-- Check height diffrences
function posCheck(posx, posy, posz, posradius)
	-- if true then can spawn
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	local deathwater = Game.waterDamage
	if deathwater > 0 and posy <= 0 then
		return false
	elseif testpos1 < posy - 30 or testpos1 > posy + 30 then
		return false
	elseif testpos2 < posy - 30 or testpos2 > posy + 30 then
		return false
	elseif testpos3 < posy - 30 or testpos3 > posy + 30 then
		return false
	elseif testpos4 < posy - 30 or testpos4 > posy + 30 then
		return false
	elseif testpos5 < posy - 30 or testpos5 > posy + 30 then
		return false
	elseif testpos6 < posy - 30 or testpos6 > posy + 30 then
		return false
	elseif testpos7 < posy - 30 or testpos7 > posy + 30 then
		return false
	elseif testpos8 < posy - 30 or testpos8 > posy + 30 then
		return false
	else
		return true
	end
end

-- Check if area is occupied
function posOccupied(posx, posy, posz, posradius)
	-- if true then can spawn
	local unitcount = #Spring.GetUnitsInRectangle(posx-posradius, posz-posradius, posx+posradius, posz+posradius)
	if unitcount > 0 then
		return false
	else
		return true
	end
end

-- Check if area is visible for any player
function posLosCheck(posx, posy, posz, posradius)
	-- if true then can spawn
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