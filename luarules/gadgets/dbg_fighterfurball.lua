local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Fighter Furball",
		desc = "Stress test for fighter AA targeting: repeatedly spawns two clumps of fighters out of range of each other, sends them to fight, kills them after a few seconds, then repeats.",
		author = "Bruno-DaSilva",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = -1999999999,
		enabled = true
	}
end

local PACKET_HEADER = "$ff$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

-- Shared authorization (mirrors dbg_benchmark / cmd_dev_helpers): cheats, or an
-- explicit devhelpers permission, and only for players present at game start.
if gadgetHandler:IsSyncedCode() then
	startPlayers = startPlayers or {}
end

function isAuthorized(playerID, subPermission)
	if Spring.IsCheatingEnabled() then
		return true
	end
	local playername = Spring.GetPlayerInfo(playerID)
	local accountID = Spring.Utilities.GetAccountID(playerID)
	local hasPermission = false
	if (_G and _G.permissions.devhelpers and (_G.permissions.devhelpers[accountID] or (playername and _G.permissions.devhelpers[playername]))) or
	   (SYNCED and SYNCED.permissions.devhelpers and (SYNCED.permissions.devhelpers[accountID] or (playername and SYNCED.permissions.devhelpers[playername]))) then
		hasPermission = true
	end
	if not hasPermission and subPermission then
		local permKey = "devhelpers_" .. subPermission
		if (_G and _G.permissions[permKey] and (_G.permissions[permKey][accountID] or (playername and _G.permissions[permKey][playername]))) or
		   (SYNCED and SYNCED.permissions[permKey] and (SYNCED.permissions[permKey][accountID] or (playername and SYNCED.permissions[permKey][playername]))) then
			hasPermission = true
		end
	end
	if hasPermission then
		if startPlayers == nil or startPlayers[playername] == nil then
			return true
		end
	end
	return false
end


if gadgetHandler:IsSyncedCode() then

	function checkStartPlayers()
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local playername, _, spec = Spring.GetPlayerInfo(playerID, false)
			if not spec then
				startPlayers[playername] = true
			end
		end
	end

	function gadget:GameStart()
		checkStartPlayers()
	end

	local mapcx = Game.mapSizeX / 2
	local mapcz = Game.mapSizeZ / 2

	-- Tunables (overridable from the chat action arguments)
	local countPerSide = 1000          -- fighters spawned per clump
	local fightFrames = 5 * 30         -- frames the two clumps are left to fight
	local respawnGap = 15              -- frames between a kill and the next spawn
	local clumpOffset = 1000           -- half the distance between clump centers (elmos)
	local spacing = 10                 -- grid spacing between fighters within a clump (elmos)
	local team1unitDefName = "armfig"  -- Arm T1 fighter
	local team2unitDefName = "corveng" -- Cor T1 fighter

	local active = false
	local team1, team2                 -- opposing teamIDs
	local spawnedUnits = {}            -- list of currently-alive spawned unitIDs
	local nextKillFrame = 0
	local nextSpawnFrame = 0
	local cycles = 0

	-- Pick two teams on different (non-gaia) allyteams so the clumps are hostile.
	-- Falls back to teams 0/1 (the convention dbg_benchmark relies on).
	local function pickOpposingTeams()
		local gaiaTeam = Spring.GetGaiaTeamID()
		local seen = {}
		local a, b
		for _, teamID in ipairs(Spring.GetTeamList()) do
			if teamID ~= gaiaTeam then
				local allyTeamID = select(6, Spring.GetTeamInfo(teamID, false))
				if not a then
					a = teamID
					seen.allyTeam = allyTeamID
				elseif not b and allyTeamID ~= seen.allyTeam then
					b = teamID
				end
			end
		end
		if a and b then
			return a, b
		end
		return 0, 1
	end

	local function spawnClump(teamID, unitDefName, cx, cz)
		local unitDef = UnitDefNames[unitDefName]
		if not unitDef then
			Spring.Echo("Fighter Furball:", unitDefName, "is not a valid unitDefName")
			return
		end
		local unitDefID = unitDef.id
		local side = math.ceil(math.sqrt(countPerSide))
		local half = (side - 1) * spacing * 0.5
		local spawned = 0
		for ix = 0, side - 1 do
			for iz = 0, side - 1 do
				if spawned >= countPerSide then break end
				local px = cx - half + ix * spacing
				local pz = cz - half + iz * spacing
				local py = Spring.GetGroundHeight(px, pz)
				local unitID = Spring.CreateUnit(unitDefID, px, py, pz, "n", teamID)
				if unitID then
					spawned = spawned + 1
					spawnedUnits[#spawnedUnits + 1] = unitID
				end
			end
		end
	end

	local function spawnWave()
		spawnedUnits = {}
		-- Two clumps offset along X, well outside fighter weapon range (~680).
		local ax, az = mapcx - clumpOffset, mapcz
		local bx, bz = mapcx + clumpOffset, mapcz
		spawnClump(team1, team1unitDefName, ax, az)
		spawnClump(team2, team2unitDefName, bx, bz)

		-- Send each clump to fight a point on top of the other clump, so they
		-- close the gap and auto-acquire targets along the way.
		local team1ids, team2ids = {}, {}
		for _, unitID in ipairs(spawnedUnits) do
			if Spring.GetUnitTeam(unitID) == team1 then
				team1ids[#team1ids + 1] = unitID
			else
				team2ids[#team2ids + 1] = unitID
			end
		end
		Spring.GiveOrderToUnitArray(team1ids, CMD.FIGHT, { bx, Spring.GetGroundHeight(bx, bz), bz }, 0)
		Spring.GiveOrderToUnitArray(team2ids, CMD.FIGHT, { ax, Spring.GetGroundHeight(ax, az), az }, 0)

		cycles = cycles + 1
		Spring.Echo(string.format("Fighter Furball: cycle %d, spawned %d fighters", cycles, #spawnedUnits))
	end

	local function killWave()
		for _, unitID in ipairs(spawnedUnits) do
			if Spring.ValidUnitID(unitID) then
				Spring.DestroyUnit(unitID, false, true) -- selfd=false, reclaimed=true (no wreck)
			end
		end
		spawnedUnits = {}
	end

	local function startFurball(words)
		if words[2] then countPerSide = math.max(1, math.floor(tonumber(words[2]) or countPerSide)) end
		if words[3] then fightFrames = math.max(1, math.floor((tonumber(words[3]) or 5) * 30)) end
		if words[4] and UnitDefNames[words[4]] then team1unitDefName = words[4] end
		if words[5] and UnitDefNames[words[5]] then team2unitDefName = words[5] end

		team1, team2 = pickOpposingTeams()
		cycles = 0
		Spring.Echo(string.format(
			"Fighter Furball: starting, %d %s (team %d) vs %d %s (team %d), %d-frame fights",
			countPerSide, team1unitDefName, team1, countPerSide, team2unitDefName, team2, fightFrames))

		active = true
		local n = Spring.GetGameFrame()
		spawnWave()
		nextKillFrame = n + fightFrames
		nextSpawnFrame = 0
	end

	local function stopFurball()
		active = false
		killWave()
		Spring.Echo(string.format("Fighter Furball: stopped after %d cycles", cycles))
	end

	function gadget:GameFrame(n)
		if not active then return end

		if nextSpawnFrame ~= 0 and n >= nextSpawnFrame then
			spawnWave()
			nextKillFrame = n + fightFrames
			nextSpawnFrame = 0
		elseif nextKillFrame ~= 0 and n >= nextKillFrame then
			killWave()
			nextKillFrame = 0
			nextSpawnFrame = n + respawnGap
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		msg = string.sub(msg, PACKET_HEADER_LENGTH)

		local words = {}
		for word in msg:gmatch("[%-_%w]+") do
			table.insert(words, word)
		end

		if words[1] ~= "fighterfurball" then return end
		if not isAuthorized(playerID, "terrain") then return end

		if active then
			stopFurball()
		else
			startFurball(words)
		end
	end

	function gadget:Initialize()
		checkStartPlayers()
	end


else -- UNSYNCED


	local vsx, vsy = Spring.GetViewGeometry()
	local uiScale = vsy / 1080

	-- On-screen sim/update/draw frame timing (same approach as dbg_benchmark).
	-- An Update always starts with gadget:Update, a draw frame spans DrawGenesis
	-- to DrawScreenPost, and a sim frame starts at gadget:GameFrame.
	local active = false
	local lastDrawTimerUS = Spring.GetTimerMicros()
	local lastSimTimerUS = Spring.GetTimerMicros()
	local lastUpdateTimerUs = Spring.GetTimerMicros()
	local lastFrameType = 'draw' -- can be draw, sim, update
	local simTime = 0
	local drawTime = 0
	local updateTime = 0
	local ss = 0 -- smoothed sim time
	local sd = 0 -- smoothed draw time
	local su = 0 -- smoothed update time
	local alpha = 0.98

	function gadget:ViewResize()
		vsx, vsy = Spring.GetViewGeometry()
		uiScale = vsy / 1080
	end

	function gadget:Update() -- START OF UPDATE
		if active then
			local now = Spring.GetTimerMicros()
			if lastFrameType ~= 'draw' then
				-- ending a sim frame: record its time
				simTime = Spring.DiffTimers(now, lastSimTimerUS)
				ss = alpha * ss + (1 - alpha) * simTime
			end
			lastUpdateTimerUs = Spring.GetTimerMicros()
		end
	end

	function gadget:GameFrame(n) -- START OF SIM FRAME
		if active then
			local now = Spring.GetTimerMicros()
			if lastFrameType == 'sim' then
				-- double sim frame: record the previous one's time
				simTime = Spring.DiffTimers(now, lastSimTimerUS)
				ss = alpha * ss + (1 - alpha) * simTime
			end
			lastSimTimerUS = now
			lastFrameType = 'sim'
		end
	end

	function gadget:DrawGenesis() -- START OF DRAW
		if active then
			local now = Spring.GetTimerMicros()
			updateTime = Spring.DiffTimers(now, lastUpdateTimerUs)
			su = alpha * su + (1 - alpha) * updateTime
			lastDrawTimerUS = now
		end
	end

	function gadget:DrawScreenPost() -- END OF DRAW
		if active then
			drawTime = Spring.DiffTimers(Spring.GetTimerMicros(), lastDrawTimerUS)
			sd = alpha * sd + (1 - alpha) * drawTime
			lastFrameType = 'draw'
		end
	end

	function gadget:DrawScreen()
		if active then
			local s = string.format(
				"Sim = ~%3.2fms  (%3.2fms)\nUpdate = ~%3.2fms (%3.2fms)\nDraw = ~%3.2fms (%3.2fms)",
				ss, simTime, su, updateTime, sd, drawTime)
			gl.Text(s, 600 * uiScale, 600 * uiScale, 16 * uiScale)
		end
	end

	local function centerCamera()
		local camState = Spring.GetCameraState()
		if camState then
			local mapcx = Game.mapSizeX / 2
			local mapcz = Game.mapSizeZ / 2
			local mapcy = Spring.GetGroundHeight(mapcx, mapcz)

			camState["px"] = mapcx
			camState["py"] = mapcy
			camState["pz"] = mapcz
			camState["dy"] = -1
			camState["dz"] = -1
			camState["dx"] = 0
			camState["rx"] = 2.75
			camState["height"] = mapcy + 2000
			camState["dist"] = mapcy + 2000
			camState["name"] = "spring"

			Spring.SetCameraState(camState, 0.75)
		end
	end

	-- /luarules fighterfurball [countPerSide] [fightSeconds] [unitDefName1] [unitDefName2]
	-- Toggles the furball on/off.
	function fighterfurball(_, line, words, playerID, action)
		if playerID ~= Spring.GetMyPlayerID() then
			return
		end
		if not isAuthorized(playerID, "terrain") then
			return
		end
		active = not active
		if active then
			lastDrawTimerUS = Spring.GetTimerMicros()
			lastSimTimerUS = Spring.GetTimerMicros()
			lastUpdateTimerUs = Spring.GetTimerMicros()
		end
		local msg = PACKET_HEADER .. "fighterfurball"
		for i = 1, 4 do
			if words[i] then msg = msg .. " " .. tostring(words[i]) end
		end
		centerCamera()
		Spring.SendLuaRulesMsg(msg)
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction('fighterfurball', fighterfurball, "")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('fighterfurball')
	end

end
