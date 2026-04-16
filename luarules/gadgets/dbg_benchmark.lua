local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Benchmark",
		desc = "Performance benchmarking tool: spawns units and measures sim/draw/update frame times. Extracted from cmd_dev_helpers.",
		author = "Bluestone, Beherith, Bruno-DaSilva",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = -1999999999,
		enabled = true
	}
end

local PACKET_HEADER = "$bm$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

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
	-- check catch-all devhelpers permission (by accountID and by name for late joiners)
	if (_G and _G.permissions.devhelpers and (_G.permissions.devhelpers[accountID] or (playername and _G.permissions.devhelpers[playername]))) or
	   (SYNCED and SYNCED.permissions.devhelpers and (SYNCED.permissions.devhelpers[accountID] or (playername and SYNCED.permissions.devhelpers[playername]))) then
		hasPermission = true
	end
	-- check specific sub-permission
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
			-- update player infos
			local playername, _, spec = Spring.GetPlayerInfo(playerID, false)
			if not spec then
				startPlayers[playername] = true
			end
		end
	end

	function gadget:GameStart()
		checkStartPlayers()
	end

	local maxunits = 200
	local feedstep = 20
	local mapcx = Game.mapSizeX/2
	local mapcz = Game.mapSizeZ/2
	local mapcy = Spring.GetGroundHeight(mapcx,mapcz)
	local benchmarkenabled = false
	local placementradius = 2000
	local keepfeatures = 150
	local benchmarkstartgameframe = 0
	local benchmarktotalunitsspawned = 0

	local team1unitDefName = "armbull"
	local team2unitDefName = "armbull"


	local seededrand = {}
	local randindex = 1
	local function initrandom(seed)
		math.randomseed(seed)
		for i=1, 5000 do
			seededrand[i] = math.random()
		end
		randindex = 1
	end

	local function getrandom()
		if #seededrand < 1 then initrandom(7654321) end
		randindex = randindex + 1
		if randindex > #seededrand then randindex = 1 end
		return seededrand[randindex]
	end

	local function SpawnUnitDefsForTeamSynced(teamID, unitDefName)
		--Spring.GetTeamUnitDefCount ( number teamID, number unitDefID )
		--return: nil | number count
		local unitDefID = UnitDefNames[unitDefName].id


		local unitcount = Spring.GetTeamUnitDefCount(teamID, unitDefID)

		if (unitcount < maxunits) then
			local cx = mapcx + placementradius*(getrandom() - 0.5)
			local cz = mapcz + placementradius*(getrandom()- 0.5)

			local sqrtfeed = math.ceil(math.sqrt(feedstep))
			local footprint = math.max(UnitDefs[unitDefID].xsize, UnitDefs[unitDefID].zsize)
			local newUnitIDs = {}
			local numspawned = 0
			for x=1,sqrtfeed do
				for z = 1, sqrtfeed do
					if numspawned < feedstep then
						local px = cx + 12 * footprint * x
						local pz = cz + 12 * footprint * z
						local py = Spring.GetGroundHeight(px,pz)
						local unitID = Spring.CreateUnit(unitDefID, px, py, pz, "n", teamID)
						if unitID then
							numspawned = numspawned + 1
							newUnitIDs[#newUnitIDs + 1] = unitID
						end
					end
				end
			end

			--Spring.GiveOrderToUnitArray ( table unitArray = { [1] = number unitID, etc... }, number cmdID, table params = {number, etc...}, table options = {"alt", "ctrl", "shift", "right"} )
			--return: nil | bool true
			--CMD.MOVE, { p.x, p.y, p.z }, 0 )
			Spring.GiveOrderToUnitArray(newUnitIDs, CMD.REPEAT, { 1 }, 0)

			local ncx = mapcx + placementradius*(getrandom() - 0.5)
			local ncz = mapcz + placementradius*(getrandom() - 0.5)
			local gh = Spring.GetGroundHeight(ncx,ncz)
			Spring.GiveOrderToUnitArray(newUnitIDs, CMD.MOVE, {ncx,gh,ncz}, {"shift"})

			ncx = mapcx + placementradius*(getrandom() - 0.5)
			ncz = mapcz + placementradius*(getrandom() - 0.5)
			gh = Spring.GetGroundHeight(ncx,ncz)
			Spring.GiveOrderToUnitArray(newUnitIDs, CMD.MOVE, {ncx,gh,ncz}, {"shift"})

			gh = Spring.GetGroundHeight(cx,cz)
			Spring.GiveOrderToUnitArray(newUnitIDs, CMD.MOVE, {cx,gh,cz}, {"shift"})

			benchmarktotalunitsspawned = benchmarktotalunitsspawned + numspawned
		end
	end

	local featuredefstoremove = {}

	function ExecuteRemoveUnitDefName(unitdefname)
		local unitDefID = UnitDefNames[unitdefname].id
		if unitDefID then
			if FeatureDefNames[unitdefname .. "_dead"] then
				wreckFeatureDefID = FeatureDefNames[unitdefname .. "_dead"].id
			end
			if FeatureDefNames[unitdefname .. "_heap"] then
				heapFeatureDefID = FeatureDefNames[unitdefname .. "_heap"].id
			end
			local allunits = Spring.GetAllUnits()
			local removedunits = 0
			local removedwrecks = 0
			local removedheaps = 0
			for i, unitID in ipairs(allunits) do
				if unitDefID == Spring.GetUnitDefID(unitID) then
					Spring.DestroyUnit(unitID, false, true)
					removedunits = removedunits + 1
				end
			end
			local allfeatures = Spring.GetAllFeatures()
			for i, featureID in ipairs(allfeatures) do
				local featureDefID = Spring.GetFeatureDefID(featureID)
				if featureDefID == wreckFeatureDefID then
					Spring.DestroyFeature(featureID)
					removedwrecks = removedwrecks + 1
				end
				if featureDefID == heapFeatureDefID then
					Spring.DestroyFeature(featureID)
					removedheaps = removedheaps + 1
				end
			end

			Spring.Echo(string.format("Removed %i units, %i wrecks, %i heaps for unitDefName %s",removedunits, removedwrecks, removedheaps, unitdefname ))
		else
			Spring.Echo("Removeunitdef:", unitdefname, "is not a valid UnitDefName")
		end
	end

	function benchmark(words)
		benchmarkenabled = not benchmarkenabled
		if not benchmarkenabled then
			Spring.Echo(string.format("Benchmark ended, %d units spawned over %d gameframes, Units/frame = %f",
					benchmarktotalunitsspawned,
					Spring.GetGameFrame() - benchmarkstartgameframe,
					benchmarktotalunitsspawned * (1.0 / (Spring.GetGameFrame() - benchmarkstartgameframe))
					))
			ExecuteRemoveUnitDefName(team1unitDefName)
			ExecuteRemoveUnitDefName(team2unitDefName)
			return
		end
		benchmarkstartgameframe = Spring.GetGameFrame()
		benchmarktotalunitsspawned = 0
		initrandom(7654321)
		if words[2] and UnitDefNames[words[2]] then	team1unitDefName = words[2]
		else Spring.Echo(words[2], "is not a valid unitDefName, using", team1unitDefName, "instead") end

		if words[3] and UnitDefNames[words[3]] then	team2unitDefName = words[3]
		else Spring.Echo(words[3], "is not a valid unitDefName, using", team2unitDefName, "instead") end


		if words[4] then
			local maxunitsint = tonumber(words[4])
			if maxunitsint == nil then
				Spring.Echo(words[4], "must be the number of max units to keep spawning, using", maxunits, "instead")
			else
				maxunits = math.floor(maxunitsint)
			end
		end
		if words[5] then
			local feedstepint = tonumber(words[5])
			if feedstepint == nil then
				Spring.Echo(words[5], "must be the number units to spawn each step, using", maxunits, "instead")
			else
				feedstep = math.floor(feedstepint)
			end
		end
		if words[6] then
			local placementradiusint = tonumber(words[6])
			if placementradiusint == nil then
				Spring.Echo(words[6], "must be the radius in which to spawn units, using ", placementradius, "instead")
			else
				placementradius = math.floor(placementradiusint)
			end
		end
		if words[7] then
			local keepfeaturesint = tonumber(words[7])
			if keepfeaturesint == nil then
				Spring.Echo(words[7], "must be the number of frames wrecks will live ", placementradius, "instead")
			else
				keepfeatures = math.floor(keepfeaturesint)
			end
		end

		Spring.Echo(string.format("Starting benchmark %s vs %s with %i maxunits and %i units per step in a %d radius, features live %d frames",
				team1unitDefName,
				team2unitDefName,
				maxunits,
				feedstep,
				placementradius,
				keepfeatures))
		featuredefstoremove = {}
		for _, udn in ipairs({team1unitDefName,team2unitDefName}) do
			for _, wreckheap in ipairs({'_dead','_heap'}) do
				if FeatureDefNames[udn .. wreckheap] and FeatureDefNames[udn .. wreckheap].id then
					featuredefstoremove[FeatureDefNames[udn .. wreckheap].id] = true
					Spring.Echo(udn .. wreckheap)
				end
			end
		end
	end


	local featurestoremove = {}
	function gadget:FeatureCreated(featureID, allyTeam)
		if benchmarkenabled then
			local featureDefID = Spring.GetFeatureDefID(featureID)
			if featureDefID and featuredefstoremove[featureDefID] then
				featurestoremove[featureID] = Spring.GetGameFrame() + keepfeatures
			end
		end
	end

	function gadget:GameFrame(n)
		if benchmarkenabled then
			if (n % 3 == 0)  then
				SpawnUnitDefsForTeamSynced(0, team1unitDefName)
				SpawnUnitDefsForTeamSynced(1, team2unitDefName)
			end

			if (n % 3 == 1)  then
				for featureID, deathtime in pairs(featurestoremove) do
					if deathtime < n then
						if Spring.ValidFeatureID(featureID) then
							Spring.DestroyFeature(featureID)
						end
						featurestoremove[featureID] = nil
					end
				end
			end
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

		if words[1] ~= "benchmark" then return end
		if not isAuthorized(playerID, "terrain") then return end

		benchmark(words)
	end

	function gadget:Initialize()
		checkStartPlayers()
	end


else	-- UNSYNCED


	local vsx,vsy = Spring.GetViewGeometry()
	local uiScale = vsy / 1080

	local function centerCamera()
		local camState = Spring.GetCameraState()
		if camState then
			local mapcx = Game.mapSizeX/2
			local mapcz = Game.mapSizeZ/2
			local mapcy = Spring.GetGroundHeight(mapcx,mapcz)

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

	------------------------------UNSYNCED-----------------------------
	local benchmarkactive = false
	local benchmarkstats


	-- An Update is always done before a Draw Frame
	-- An Update always Start with Gadget:Update
	-- A draw frame actually spans from DrawGenesis to DrawScreenPost!
	-- The timer of every sim frame ends with a lastFrameTime
	-- A Sim frame starts at gadget:GameFrame.
	-- The end of a Sim Frame is unknown

	-- A


	-- Spring.DiffTimers(Spring.GetTimerMicros(),tus)

	local lastDrawTimerUS = Spring.GetTimerMicros()
	local lastSimTimerUS = Spring.GetTimerMicros()
	local lastUpdateTimerUs = Spring.GetTimerMicros()
	local lastFrameType = 'draw' -- can be draw, sim, update
	local simTime = 0
	local drawTime = 0
	local updateTime = 0
	local isBenchMark = false
	local benchMarkFrames = 0

	local ss = 0
	local sd = 0
	local su = 0
	local alpha = 0.98

	function gadget:ViewResize()
		vsx, vsy = Spring.GetViewGeometry()
		uiScale = vsy / 1080
	end

	function gadget:Update() -- START OF UPDATE
		if benchmarkactive then
			local now = Spring.GetTimerMicros()
			if lastFrameType == 'draw' then
				-- We are doing a double draw
			else
				-- We are ending a sim frame, so better push the sim frame time number
				simTime = Spring.DiffTimers(now, lastSimTimerUS)
				benchmarkstats.simFrameTimes[#benchmarkstats.simFrameTimes + 1] = simTime
				ss = alpha * ss + (1-alpha) * simTime
			end
			lastUpdateTimerUs = Spring.GetTimerMicros()
		end
	end

	function gadget:GameFrame(n) -- START OF SIM FRAME
		if benchmarkactive then
			local now = Spring.GetTimerMicros()
			if lastFrameType == 'sim' then
				-- We are doing double sim, push a sim frame time number
				simTime = Spring.DiffTimers(now, lastSimTimerUS)
				benchmarkstats.simFrameTimes[#benchmarkstats.simFrameTimes + 1] = simTime
				ss = alpha * ss + (1-alpha) * simTime
			else -- we are coming off a draw frame

			end
			lastSimTimerUS = now
			lastFrameType = 'sim'
		end
	end

	function gadget:DrawGenesis() -- START OF DRAW
		if benchmarkactive then
			local now = Spring.GetTimerMicros()
			updateTime = Spring.DiffTimers(now, lastUpdateTimerUs)
			benchmarkstats.updateFrameTimes[#benchmarkstats.updateFrameTimes + 1] = updateTime
			su = alpha * su + (1-alpha) * updateTime
			lastDrawTimerUS = now
		end
	end

	function gadget:DrawScreenPost() -- END OF DRAW
		if benchmarkactive then
			drawTime = Spring.DiffTimers(Spring.GetTimerMicros(), lastDrawTimerUS)
			benchmarkstats.drawFrameTimes[#benchmarkstats.drawFrameTimes + 1] = drawTime
			sd = alpha * sd + (1-alpha) * drawTime

			lastFrameType = 'draw'
			dt = drawTime
		end
	end

	function gadget:DrawScreen()
		if benchmarkactive or isBenchMark then
			local s = ""
			if isBenchMark then
				s = s .. string.format("Benchmark Frame %d/%d\n", #benchmarkstats.simFrameTimes,benchMarkFrames)
			end
			s = s .. string.format("Sim = ~%3.2fms  (%3.2fms)\nUpdate = ~%3.2fms (%3.2fms)\nDraw = ~%3.2fms (%3.2fms)", ss, simTime, su, updateTime, sd,  drawTime)
			gl.Text(s, 600*uiScale, 600*uiScale, 16*uiScale)
		end
	end

	function gadget:UnitCreated()
		if benchmarkactive then
			benchmarkstats.numunitscreated = benchmarkstats.numunitscreated + 1
		end
	end

	function gadget:UnitDestroyed()
		if benchmarkactive then
			benchmarkstats.numunitsdestroyed = benchmarkstats.numunitsdestroyed + 1
		end
	end

	function benchmark(_, line, words, playerID, action)
		if playerID ~= Spring.GetMyPlayerID() then
			return
		end
		Spring.Echo("Benchmark",line, words, playerID, action)
		if not isAuthorized(playerID, "terrain") then
			return
		end
		if benchmarkactive then
			-- We need to dump the stats
			local s1 = string.format("Benchmark complete, #created = %d, #destroyed = %d",  benchmarkstats.numunitscreated, benchmarkstats.numunitsdestroyed)
			Spring.Echo(s1)
			local res = {}
			local stats = {}
			for n, t in pairs({Sim = benchmarkstats.simFrameTimes, Draw = benchmarkstats.drawFrameTimes, Update = benchmarkstats.updateFrameTimes}) do
				local ms = {
					count = 0,
					total = 0,
					mean = 0,
					spread = 0,
					percentiles = {},

				}  --mystats
				-- Discard first 10%
				local ct = {} -- cleantable
				local oldtotal = #t
				for i,v in ipairs(t) do
					if i > (oldtotal * 0.1) then
						ms.count = ms.count + 1
						ct[ms.count] = v
						ms.total = ms.total + v
					end
				end

				ms.mean = ms.total/ms.count
				table.sort(ct)

				for i, v in ipairs(ct) do
					ms.spread = ms.spread + math.abs( v - ms.mean)
				end
				ms.spread = ms.spread/ms.count

				for _,i in ipairs({0,1,2,5,10,20,35,50,65,80,90,95,98,99,100}) do
					ms.percentiles[i] = ct[math.min(#ct, 1 + math.floor(i*0.01 * #ct))]
				end

				stats[n] = ms

				local total = 0
				for i,v in ipairs(t) do
					total = total + v
				end

				local s2 = string.format("%s %d frames, %3.2fms per frame, %4.2fs total",
						n, ms.count, ms.mean, ms.total)
				res[#res+1] = s2
				Spring.Echo(s2)
			end

			if isBenchMark then
				--stats.scenariooptions = Spring.GetModOptions().scenariooptions -- pass it back so we know difficulty
				stats.benchmarkcommand = isBenchMark
				stats.mapName = Game.mapName
				stats.gameName = Game.gameName .. " " .. Game.gameVersion
				stats.engineVersion = Engine.versionFull
				stats.gpu = Platform.gpu
				stats.cpu = Platform.hwConfig
				stats.display = tostring(vsx) ..'x' .. tostring(vsy)

				Spring.Echo("Benchmark Results")
				Spring.Echo(stats)

				if Spring.GetMenuName then
					local message = Json.encode(stats)
					--Spring.Echo("Sending Message", message)
					Spring.SendLuaMenuMsg("ScenarioGameEnd " .. message)
				end
			end


			-- clean up
			--benchmarkstats = {}
		else
			Spring.Echo("Starting Benchmark")
			if Spring.GetModOptions().scenariooptions then
				--Spring.Echo("Scenario: Spawning on frame", Spring.GetGameFrame())
				local scenariooptions = string.base64Decode(Spring.GetModOptions().scenariooptions)
				Spring.Echo(scenariooptions)
				scenariooptions = Json.decode(scenariooptions)
				if scenariooptions and scenariooptions.benchmarkcommand then
					--This is where the magic happens!
					isBenchMark = scenariooptions.benchmarkcommand
					benchMarkFrames = scenariooptions.benchmarkframes
				end
			end
			-- initialize stats table
			benchmarkstats = {
				commandline = line,
				simFrameTimes = {},
				drawFrameTimes = {},
				updateFrameTimes = {},
				numunitscreated = 0,
				numunitsdestroyed= 0,
			}
			lastDrawTimerUS = Spring.GetTimerMicros()
			lastSimTimerUS = Spring.GetTimerMicros()
			lastUpdateTimerUs = Spring.GetTimerMicros()
		end
		benchmarkactive = not benchmarkactive
		local msg = PACKET_HEADER .. ':benchmark'
		for i=1,5 do
			if words[i] then msg = msg .. " " .. tostring(words[i]) end
		end
		centerCamera()
		Spring.SendLuaRulesMsg(msg)
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction('benchmark', benchmark, "") -- /luarules benchmark unitdefname1 unitdefname2 count
		-- TODO: remove once chobby is updated to use `/luarules benchmark`.
		gadgetHandler:AddChatAction('fightertest', benchmark, "")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('benchmark')
		gadgetHandler:RemoveChatAction('fightertest')
	end

end
