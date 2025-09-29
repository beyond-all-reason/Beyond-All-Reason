
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= 'Coop II',
		desc	= 'Implements coop modoption',
		author	= 'Niobium',
		date	= 'May 2011',
		license	= 'GNU GPL, v2 or later',
		layer	= 1, --should run after game_initial_spawn
		enabled	= true
	}
end

-- Modoption check
if not Spring.GetModOptions().coop then
	return false
end

if gadgetHandler:IsSyncedCode() then

	----------------------------------------------------------------
	-- Synced Var
	----------------------------------------------------------------
	local coopStartPoints = {} -- coopStartPoints[playerID] = {x,y,z}, also acts as is-player-a-coop-player
	GG.coopStartPoints = coopStartPoints -- Share to other gadgets

	local armcomDefID = UnitDefNames.armcom.id
	local corcomDefID = UnitDefNames.corcom.id
	local legcomDefID = UnitDefNames.legcom.id

	----------------------------------------------------------------
	-- Setting up
	----------------------------------------------------------------

	local function SetCoopStartPoint(playerID, x, y, z)
		coopStartPoints[playerID] = {x, y, z}
		SendToUnsynced("CoopStartPoint", playerID, x, y, z)
	end

	do
		local coopHasEffect = false
		local teamHasPlayers = {}
		local playerList = Spring.GetPlayerList()
		for i = 1, #playerList do
			local playerID = playerList[i]
			local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID,false)
			if not isSpec then
				if teamHasPlayers[teamID] then
					SetCoopStartPoint(playerID, -1, -1, -1)
					coopHasEffect = true
				else
					teamHasPlayers[teamID] = true
				end
			end
		end

		if coopHasEffect then
			GG.coopMode = true -- Inform other gadgets that coop needs to be taken into account
		end
	end

	----------------------------------------------------------------
	-- Synced Callins
	----------------------------------------------------------------

	function gadget:AllowStartPosition(playerID,teamID,readyState,x,y,z)
		for otherplayerID, startPos in pairs(coopStartPoints) do
			if startPos[1]==x and startPos[3]==z then
				return false
			end
		end
		if coopStartPoints[playerID] then
			-- Spring sometimes(?) has each player re-place their start position on their current team start position pre-gamestart
			-- To catch this, we don't recognise a coop start position if it is identical to their teams 'normal' start position
			-- This has the side-effect that a coop player cannot intentionally start directly on their teammate, but this is OK

			-- Since spring is a bitch, and if the first player (the guy who places the real start point) readies up first, and
			-- his coop buddy readies up after, then the first will have his start point overwritten by the second.
			-- This can be prevented by not allowing the first to place on second, either.

			local _, _, _, teamID, allyID = Spring.GetPlayerInfo(playerID,false)
			local osx, _, osz = Spring.GetTeamStartPosition(teamID)
			if x ~= osx or z ~= osz then
				local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyID)
				x = math.clamp(x, xmin, xmax)
				z = math.clamp(z, zmin, zmax)

				SetCoopStartPoint(playerID, x, Spring.GetGroundHeight(x, z), z) -- record coop start point, display it
				return false
			end
		end

		return true
	end

	function IsSteep(x,z)
		-- check if the position (x,z) is too step to start a commander on or not
		local mtta = math.acos(1.0 - 0.41221) - 0.02 -- http://springrts.com/wiki/Movedefs.lua#How_slope_is_determined & the -0.02 is for safety
		local a1,a2,a3,a4 = 0,0,0,0
		local d = 5
		local y = Spring.GetGroundHeight(x,z)
		local y1 = Spring.GetGroundHeight(x+d,z)
		if math.abs(y1 - y) > 0.1 then a1 = math.atan((y1-y)/d) end
		local y2 = Spring.GetGroundHeight(x,z+d)
		if math.abs(y2 - y) > 0.1 then a2 = math.atan((y2-y)/d) end
		local y3 = Spring.GetGroundHeight(x-d,z)
		if math.abs(y3 - y) > 0.1 then a3 = math.atan((y3-y)/d) end
		local y4 = Spring.GetGroundHeight(x,z+d)
		if math.abs(y4 - y) > 0.1 then a4 = math.atan((y4-y)/d) end
		if math.abs(a1) > mtta or math.abs(a2) > mtta or math.abs(a3) > mtta or math.abs(a4) > mtta then
			return true --too steep
		else
			return false --ok
		end
	end

	local function SpawnTeamStartUnit(playerID,teamID, allyID, x, z)
		local startUnit = Spring.GetTeamRulesParam(teamID, 'startUnit')
		if GG.playerStartingUnits then --use that player specific start unit if available
			startUnit = GG.playerStartingUnits[playerID] or startUnit
		end

		if startUnit == nil then
			if math.random() > 0.5 then
				startUnit = corcomDefID
			else
				startUnit = armcomDefID
			end
			if Spring.GetModOptions().experimentallegionfaction and math.random() > 0.33 then
				startUnit = legcomDefID
			end
		end

		if x <= 0 or z <= 0 then --TODO: improve this
			local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyID)
			local tx,tz
			if GG.teamStartPoints then
				tx = GG.teamStartPoints[teamID][1]
				tz = GG.teamStartPoints[teamID][3]
			else
				tx = (xmin+xmax)/2
				tz = (zmin+zmax)/2
			end
			local thetaStart = math.random(15)-1
			for theta = thetaStart,15+thetaStart do
				local sx = tx + 45*math.cos((math.pi/8)*theta)
				local sz = tz + 45*math.sin((math.pi/8)*theta)
				if not IsSteep(sx,sz) then
					x = math.clamp(sx, xmin, xmax)
					x = math.clamp(sz, zmin, zmax)
					break
				else -- fallback
					x=tx
					z=tz
				end
			end
		end

		-- create
		local unitID = Spring.CreateUnit(startUnit, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
		coopStartPoints[playerID] = {x,z}
		GG.playerStartingUnits[playerID] = startUnit
		-- we set unit rule to mark who belongs to, so initial queue knows which com unitID belongs to which player's initial queue
		Spring.SetUnitRulesParam(unitID, "startingOwner", playerID )
	end

	function gadget:GameFrame(n)
		-- spawn cooped coms
		if n==0 and GG.coopMode then
			for playerID, startPos in pairs(coopStartPoints) do
				local _, _, _, teamID, allyID = Spring.GetPlayerInfo(playerID,false)
				SpawnTeamStartUnit(playerID,teamID, allyID, startPos[1], startPos[3])
			end
		end

		gadgetHandler:RemoveGadget(self)
	end


else


	local function CoopStartPoint(epicwtf, playerID, x, y, z) --this epicwtf param is used because it seem that when a registered function is locaal, then the registration name is  passed too. if the function is part of gadget: then it is not passed.
		if Script.LuaUI("GadgetCoopStartPoint") then
			Script.LuaUI.GadgetCoopStartPoint(playerID, x, y, z)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("CoopStartPoint", CoopStartPoint)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("CoopStartPoint")
	end

	function gadget:GameFrame(n)
		gadgetHandler:RemoveGadget(self)
	end

end
