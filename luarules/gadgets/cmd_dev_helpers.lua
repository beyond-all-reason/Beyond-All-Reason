--[[
local msg = 'luar_uels ihatelua -100 200'
for word in msg:gmatch("[%-_%w]+") do
  print (word)
end
]]--

function gadget:GetInfo()
	return {
		name = "Dev Helper Cmds",
		desc = "provides various luarules commands to help developers, can only be used after /cheat",
		author = "Bluestone",
		date = "",
		license = "GNU GPL, v2 or later, Horses",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

local PACKET_HEADER = "$dev$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

if gadgetHandler:IsSyncedCode() then
	startPlayers = {}
end

function isAuthorized(playerID)
	if Spring.IsCheatingEnabled() then
		return true
	else
		local playername = Spring.GetPlayerInfo(playerID, false)
		local authorized = false

		local authorized = false
		if (_G and _G.permissions.devhelpers[playername]) or (SYNCED and SYNCED.permissions.devhelpers[playername]) then
			if startPlayers == nil or startPlayers[playername] == nil then
				return true
			end
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
	function gadget:PlayerChanged(playerID)
		checkStartPlayers()
	end
	function LoadMissiles()
		if not Spring.IsCheatingEnabled() then
			return
		end

		for _, unitID in pairs(Spring.GetAllUnits()) do
			Spring.SetUnitStockpile(unitID, math.max(5, select(2, Spring.GetUnitStockpile(unitID)))) --no effect if the unit can't stockpile
		end
	end

	function HalfHealth()
		if not Spring.IsCheatingEnabled() then
			return
		end

		-- reduce all units health to 1/2 of its current value
		for _, unitID in pairs(Spring.GetAllUnits()) do
			Spring.SetUnitHealth(unitID, Spring.GetUnitHealth(unitID) / 2)
		end
	end

	local maxunits = 200
	local feedstep = 20
	local mapcx = Game.mapSizeX/2
	local mapcz = Game.mapSizeZ/2
	local mapcy = Spring.GetGroundHeight(mapcx,mapcz)
	local fightertestenabled = false
	local placementradius = 2000
	local keepfeatures = 150
	local fighterteststartgameframe = 0
	local fightertesttotalunitsspawned = 0

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

	local function SpawnUnitDefsForTeam(teamID, unitDefName)
		local unitcount = Spring.GetTeamUnits(teamID)
		if (#unitcount < maxunits) then
			local cmd = string.format(
				"give %d %s %d @%d,%d,%d",
				feedstep,
				unitDefName,
				teamID,
				mapcx + placementradius*(getrandom() - 0.5),
				mapcy,
				mapcz + placementradius*(getrandom()- 0.5)
			)
			Spring.SendCommands({cmd})
			fightertesttotalunitsspawned = fightertesttotalunitsspawned + feedstep
		end
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

			fightertesttotalunitsspawned = fightertesttotalunitsspawned + numspawned
		end
	end

	local debugcommands = nil
	function gadget:Initialize()
		if Spring.GetModOptions() and Spring.GetModOptions().debugcommands then
			debugcommands = {}
			local commands = string.split(Spring.GetModOptions().debugcommands, '|')
			for i,command in ipairs(commands) do
				local cmdsplit = string.split(command,':')
				if cmdsplit[1] and cmdsplit[2] and tonumber(cmdsplit[1]) then
					debugcommands[tonumber(cmdsplit[1])] = cmdsplit[2]
					Spring.Echo("Adding debug command",cmdsplit[1], cmdsplit[2])
				end
			end

		end
		checkStartPlayers()
		gadgetHandler:AddChatAction('loadmissiles', LoadMissiles, "")
		gadgetHandler:AddChatAction('halfhealth', HalfHealth, "")

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
		
		if words[1] == 'desync' then
			Spring.Echo("Synced: Attempting to trigger a /desync")
			Spring.SendCommands("desync")
		end
		
		if not isAuthorized(playerID) then
			return
		end
		
		if words[1] == "givecat" then
			GiveCat(words)
		elseif words[1] == "xpunits" then
			local parts = string.split(msg, ':')
			local words = {}
			msg = parts[1]..':'..parts[2]
			for word in msg:gmatch("[%-_%w]+") do
				table.insert(words, word)
			end
			ExecuteSelUnits(words, playerID, 'xp', parts[3])
		elseif words[1] == "destroyunits" then
			ExecuteSelUnits(words, playerID)
		elseif words[1] == "removeunits" then
			ExecuteSelUnits(words, playerID, 'remove')
		elseif words[1] == "reclaimunits" then
			ExecuteSelUnits(words, playerID, 'reclaim')
		elseif words[1] == "wreckunits" then
			ExecuteSelUnits(words, playerID, 'wreck')
		elseif words[1] == "spawnceg" then
			spawnceg(words)
		elseif words[1] == "removeunitdef" then
			ExecuteRemoveUnitDefName(words[2])
		elseif words[1] == "clearwrecks" then
			ClearWrecks()
		elseif words[1] == "fightertest" then
			fightertest(words)
		end
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('loadmissiles')
		gadgetHandler:RemoveChatAction('halfhealth')
	end
	local featuredefstoremove = {}

	function fightertest(words)
		fightertestenabled = not fightertestenabled
		if not fightertestenabled then
			Spring.Echo(string.format("Fightertest ended, %d units spawned over %d gameframes, Units/frame = %f",
					fightertesttotalunitsspawned,
					Spring.GetGameFrame() - fighterteststartgameframe,
					fightertesttotalunitsspawned * (1.0 / (Spring.GetGameFrame() - fighterteststartgameframe))
					))
			ExecuteRemoveUnitDefName(team1unitDefName)
			ExecuteRemoveUnitDefName(team2unitDefName)
			return
		end
		fighterteststartgameframe = Spring.GetGameFrame()
		fightertesttotalunitsspawned = 0
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

		Spring.Echo(string.format("Starting fightertest %s vs %s with %i maxunits and %i units per step in a %d radius, features live %d frames",
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
		if fightertestenabled then
			local featureDefID = Spring.GetFeatureDefID(featureID)
			if featureDefID and featuredefstoremove[featureDefID] then
				featurestoremove[featureID] = Spring.GetGameFrame() + keepfeatures
			end
		end
	end

	function gadget:GameFrame(n)
		if fightertestenabled then
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
		if debugcommands then
			if debugcommands[n] then
				Spring.Echo("Executing debugcommand", debugcommands[n])
				Spring.SendCommands(debugcommands[n])
				debugcommands[n] = nil
			end
		end
	end

	function GiveCat(words)
		if #words < 5 then
			return
		end
		local ox = tonumber(words[2])
		local oz = tonumber(words[3])
		local teamID = tonumber(words[4])
		local giveUnits = {}
		for n = 5, #words do
			giveUnits[#giveUnits + 1] = tonumber(words[n])
		end

		local arrayWidth = math.ceil(math.sqrt(#giveUnits))
		local spacing = 140
		local n = 0
		local x, z = ox, oz
		for _, uDID in ipairs(giveUnits) do
			local y = Spring.GetGroundHeight(x, z)
			Spring.CreateUnit(uDID, x, y, z, "n", teamID)
			n = n + 1
			if n % arrayWidth == 0 then
				x = ox
				z = z + spacing
			else
				x = x + spacing
			end
		end
	end

	function ExecuteSelUnits(words, playerID, action, params)
		if #words < 2 then
			return
		end
		for n = 2, #words do
			local unitID = tonumber(words[n])
			local h, mh = Spring.GetUnitHealth(unitID)
			if not action then
				Spring.DestroyUnit(unitID)
			elseif action == 'xp' and params then
				--Spring.SetUnitExperience(unitID, select(1, Spring.GetUnitExperience(unitID)) + tonumber(params))
				if type(tonumber(params)) == 'number' then
					Spring.SetUnitExperience(unitID, tonumber(params))
				end
			elseif action == 'remove' then
				Spring.DestroyUnit(unitID, false, true)
			elseif action == 'reclaim' then
				local teamID = Spring.GetUnitTeam(unitID)
				local unitDefID = Spring.GetUnitDefID(unitID)
				Spring.DestroyUnit(unitID, false, true)		-- this doesnt give back resources in itself
				Spring.AddTeamResource(teamID, 'metal', UnitDefs[unitDefID].metalCost)
				Spring.AddTeamResource(teamID, 'energy', UnitDefs[unitDefID].energyCost)
			elseif action == 'wreck' then
				local unitDefID = Spring.GetUnitDefID(unitID)
				local x, y, z = Spring.GetUnitPosition(unitID)
				local heading = Spring.GetUnitHeading(unitID)
				local unitTeam = Spring.GetUnitTeam(unitID)
				Spring.DestroyUnit(unitID, false, true)
				if UnitDefs[unitDefID].wreckName and FeatureDefNames[UnitDefs[unitDefID].wreckName] then
					Spring.CreateFeature(FeatureDefNames[UnitDefs[unitDefID].wreckName].id, x, y, z, heading, unitTeam)
				end
			end
		end
	end

	function spawnceg(words)
		Spring.Echo("SYNCED spawnceg", words[1], words[2], words[3], words[4], words[5])
		Spring.SpawnCEG(words[2], --cegname
			tonumber(words[3]), tonumber(words[4]), tonumber(words[5]), --pos
			0, 0, 0, --dir
			0 --radius
		)
	end

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

	function ClearWrecks()
		local allfeatures = Spring.GetAllFeatures()
		local removedwrecks = 0
		for i, featureID in pairs(allfeatures) do
			local featureDefName = FeatureDefs[Spring.GetFeatureDefID(featureID)].name
			if string.find(featureDefName, "_dead", nil, true) or string.find(featureDefName, "_heap", nil, true) then
				Spring.DestroyFeature(featureID)
				removedwrecks = removedwrecks + 1
			end
		end
		Spring.Echo(string.format("Removed %i wrecks and heaps", removedwrecks))
	end



else	-- UNSYNCED



	function gadget:Initialize()
		-- doing it via GotChatMsg ensures it will only listen to the caller
		gadgetHandler:AddChatAction('givecat', GiveCat, "")   -- Give a category of units, options /luarules givecat [cor|arm|scav|chicken]
		gadgetHandler:AddChatAction('destroyunits', destroyUnits, "")  -- self-destrucs the selected units /luarules destroyunits
		gadgetHandler:AddChatAction('wreckunits', wreckUnits, "")  -- turns the selected units into wrecks /luarules wreckunits
		gadgetHandler:AddChatAction('reclaimunits', reclaimUnits, "")  -- reclaims and refunds the selected units /luarules reclaimUnits
		gadgetHandler:AddChatAction('removeunits', removeUnits, "")  -- removes the selected units /luarules removeunits

		gadgetHandler:AddChatAction('xp', xpUnits, "")

		gadgetHandler:AddChatAction('spawnceg', spawnceg, "") -- --/luarules spawnceg newnuke [int] -- spawns at cursor at height

		gadgetHandler:AddChatAction('dumpunits', dumpUnits, "") -- /luarules dumpunits dumps all units on may into infolog.txt
		gadgetHandler:AddChatAction('dumpfeatures', dumpFeatures, "") -- /luarules dumpfeatures dumps all features into infolog.txt
		gadgetHandler:AddChatAction('removeunitdef', removeUnitDef, "") -- /luarules removeunitdef armflash removes all units, their wrecks and heaps too
		gadgetHandler:AddChatAction('clearwrecks', clearWrecks, "") -- /luarules clearwrecks removes all wrecks and heaps from the map

		gadgetHandler:AddChatAction('fightertest', fightertest, "") -- /luarules fightertest unitdefname1 unitdefname2 count
		gadgetHandler:AddChatAction('desync', desync) -- /luarules fightertest unitdefname1 unitdefname2 count
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('givecat')
		gadgetHandler:RemoveChatAction('destroyunits')
		gadgetHandler:RemoveChatAction('reclaimunits')
		gadgetHandler:RemoveChatAction('removeunits')
		gadgetHandler:RemoveChatAction('xp')
		gadgetHandler:RemoveChatAction('spawnceg')

		gadgetHandler:RemoveChatAction('dumpunits')
		gadgetHandler:RemoveChatAction('dumpfeatures')
		gadgetHandler:RemoveChatAction('removeunitdefs')
		gadgetHandler:RemoveChatAction('clearwrecks')
		gadgetHandler:RemoveChatAction('fightertest')		
		gadgetHandler:RemoveChatAction('desync') -- /luarules fightertest unitdefname1 unitdefname2 count

	end

	function xpUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, 'xpunits')
	end
	function destroyUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, 'destroyunits')
	end
	function wreckUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, 'wreckunits')
	end
	function reclaimUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, 'reclaimunits')
	end
	function removeUnits(_, line, words, playerID)
		processUnits(_, line, words, playerID, 'removeunits')
	end

	function removeUnitDef(_, line, words, playerID)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		Spring.Echo(line)
		Spring.Echo(words[1])
		Spring.Echo(words[2])
		Spring.Echo(words[3])
		if words[1] and UnitDefNames[words[1]] then
			Spring.SendLuaRulesMsg(PACKET_HEADER .. ':removeunitdef '.. words[1])
		end
	end

	function clearWrecks(_, line, words, playerID)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ':clearwrecks')
	end

	function processUnits(_, line, words, playerID, action)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		local selUnits = Spring.GetSelectedUnits()
		local msg = action
		for _, unitID in ipairs(selUnits) do
			msg = msg .. " " .. tostring(unitID)
		end
		if words[1] then
			msg = msg .. ':'.. words[1]
		end
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ':' .. msg)
	end

	function dumpFeatures(_)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		local features=Spring.GetAllFeatures()
		Spring.Echo("Dumping all features")
		for k,featureID in pairs(features) do
			local featureName = (FeatureDefs[Spring.GetFeatureDefID(featureID)].name or "nil")
			local x, y, z = Spring.GetFeaturePosition(featureID)
			local r = Spring.GetFeatureHeading(featureID)
			local resurrectas = Spring.GetFeatureResurrect(featureID)
			if resurrectas then resurrectas = "\"" .. resurrectas .. "\"" else resurrectas = 'nil' end
			Spring.Echo(string.format("{name = \'%s\', x = %d, y = %d, z = %d, rot = %d , scale = 1.0, resurrectas = %s},\n",featureName,x,y,z,r, resurrectas)) --{ name = 'ad0_aleppo_2', x = 2900, z = 52, rot = "-1" },
		end
	end

	function dumpUnits(_)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		Spring.Echo("Dumping all units")
		local units=Spring.GetAllUnits()
		for k,unitID in pairs(units) do
			local unitname = (UnitDefs[Spring.GetUnitDefID(unitID)].name or "nil")
			local x, y, z = Spring.GetUnitPosition(unitID)
			local r = Spring.GetUnitHeading(unitID)
			local tid = Spring.GetUnitTeam(unitID)
			local isneutral = tostring(Spring.GetUnitNeutral(unitID))
			Spring.Echo(string.format("{name = \'%s\', x = %d, y = %d, z = %d, rot = %d , team = %d, neutral = %s},\n",unitname,x,y,z,r,tid, isneutral)) --{ name = 'ad0_aleppo_2', x = 2900, z = 52, rot = "-1" },
		end
	end

	local function centerCamera()
		local camState = Spring.GetCameraState()
		if camState then
			local mapcx = Game.mapSizeX/2
			local mapcz = Game.mapSizeZ/2
			local mapcy = Spring.GetGroundHeight(mapcx,mapcz)
			camState["px"] = mapcx
			camState["py"] = mapcy
			camState["pz"] = mapcz
			camState["height"] = mapcy + 2000
			Spring.SetCameraState(camState, 0.75)
		end
	end
	function fightertest(_, line, words, playerID, action)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		local msg = PACKET_HEADER .. ':fightertest'
		for i=1,5 do
			if words[i] then msg = msg .. " " .. tostring(words[i]) end
		end
		centerCamera()
		Spring.SendLuaRulesMsg(msg)
	end

	function desync()
		Spring.Echo("Unsynced: Attempting to trigger a /desync")
		local msg = PACKET_HEADER .. ':desync'
		Spring.SendLuaRulesMsg(msg)
	end

	function spawnceg(_, line, words, playerID)
		--spawnceg usage:
		--spawnceg usage:
		--/luarules spawnceg newnuke --spawns at cursor
		--/luarules spawnceg newnuke [int] -- spawns at cursor at height
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end
		local height = 32
		if words[2] and tonumber(words[2]) then
			height = tonumber(words[2])
		end
		local mx, my = Spring.GetMouseState()
		local t, pos = Spring.TraceScreenRay(mx, my, true)
		local n = 0
		local ox, oy, oz = math.floor(pos[1]), math.floor(pos[2] + height), math.floor(pos[3])
		local x, y, z = ox, oy, oz
		local msg = "spawnceg " .. tostring(words[1]) .. ' ' .. tostring(x) .. ' ' .. tostring(y) .. ' ' .. tostring(z)

		Spring.Echo('Spawning CEG:', line, playerID, msg)
		Spring.SendLuaRulesMsg(PACKET_HEADER .. ':' .. msg)
	end

	function GiveCat(_, line, words, playerID)
		if not isAuthorized(Spring.GetMyPlayerID()) then
			return
		end

		local unitTypes = {}
		local techLevels = {}

		local facSuffix = { --ignore t3
			["veh"] = "vp", ["bot"] = "lab", ["ship"] = "sy", ["hover"] = "hp" --hover are special case, no t2 fac
		}
		local techSuffix = {
			["t1"] = "", ["t2"] = "a" --t3 added later
		}
		for t, suffix in pairs(facSuffix) do
			local acceptableUDIDs = {}
			for _, uDID in ipairs(UnitDefNames["cor" .. suffix].buildOptions) do
				acceptableUDIDs[uDID] = true
			end
			for _, uDID in ipairs(UnitDefNames["arm" .. suffix].buildOptions) do
				acceptableUDIDs[uDID] = true
			end
			if t ~= "hover" then
				for _, uDID in ipairs(UnitDefNames["arma" .. suffix].buildOptions) do
					acceptableUDIDs[uDID] = true
				end
				for _, uDID in ipairs(UnitDefNames["cora" .. suffix].buildOptions) do
					acceptableUDIDs[uDID] = true
				end
			end
			unitTypes[t] = acceptableUDIDs
		end

		for t, techSuffix in pairs(techSuffix) do
			local acceptableUDIDs = {}
			for t2, facSuffix in pairs(facSuffix) do
				if not (t == "t2" and t2 == "hover") then
					for _, uDID in ipairs(UnitDefNames["cor" .. techSuffix .. facSuffix].buildOptions) do
						acceptableUDIDs[uDID] = true
					end
					for _, uDID in ipairs(UnitDefNames["arm" .. techSuffix .. facSuffix].buildOptions) do
						acceptableUDIDs[uDID] = true
					end
				end
			end
			techLevels[t] = acceptableUDIDs
		end
		local t3Units = {}
		for _, uDID in ipairs(UnitDefNames["corgant"].buildOptions) do
			t3Units[uDID] = true
		end
		for _, uDID in ipairs(UnitDefNames["armshltx"].buildOptions) do
			t3Units[uDID] = true
		end
		techLevels['t3'] = t3Units
		techSuffix['t3'] = 't3'

		local Accept = {} -- table of conditions that must be satisfied for the unitDef to be given

		-- factions
		if string.find(line, "arm") then
			local Condition = function(ud)
				return ud.name:sub(1, 3) == "arm" and not string.find(ud.name, '_scav')
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "cor") then
			local Condition = function(ud)
				return ud.name:sub(1, 3) == "cor" and not string.find(ud.name, '_scav')
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "leg") then
			local Condition = function(ud)
				return ud.name:sub(1, 3) == "leg" and not string.find(ud.name, '_scav')
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "scav") then
			local Condition = function(ud)
				return string.find(ud.name, '_scav')
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "chicken") then
			local Condition = function(ud)
				return string.find(ud.name, 'chicken')
			end
			Accept[#Accept + 1] = Condition
		end

		-- unit types
		for t, suffix in pairs(facSuffix) do
			if string.find(line, t) then
				local Condition = function(ud)
					return unitTypes[t][ud.id]
				end
				Accept[#Accept + 1] = Condition
			end
		end

		-- tech levels
		for t, suffix in pairs(techSuffix) do
			if string.find(line, t) then
				local Condition = function(ud)
					return techLevels[t][ud.id]
				end
				Accept[#Accept + 1] = Condition
			end
		end

		-- other cats
		if string.find(line, "con") then
			local Condition = function(ud)
				return ud.isBuilder
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "mex") then
			local Condition = function(ud)
				return ud.isExtractor
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "trans") then
			local Condition = function(ud)
				return ud.isTransport
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "fac") then
			local Condition = function(ud)
				return ud.isFactory
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "building") then
			local Condition = function(ud)
				return ud.isBuilding
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "air") then
			local Condition = function(ud)
				return ud.canFly
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "mobile") then
			local Condition = function(ud)
				return not ud.isBuilding
			end
			Accept[#Accept + 1] = Condition
		end
		if string.find(line, "all") then
			local Condition = function(ud)
				local exlusions = { 'meteor', 'chicken_hive', 'nuketest', 'nuketestcor', 'nuketestcororg', 'nuketestorg', 'meteor_scav', 'chicken_hive_scav', 'nuketest_scav', 'nuketestcor_scav', 'nuketestcororg_scav', 'nuketestorg_scav' }
				for k, v in pairs(exlusions) do
					if ud.name == v then
						return
					end
				end
				return true
			end
			Accept[#Accept + 1] = Condition
		end

		-- team
		local _, _, _, teamID = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
		if string.match(line, ' ([0-9].*)') then
			teamID = string.match(line, ' ([0-9].*)')
		end


		-- give units
		local giveUnits = {}
		for _, ud in pairs(UnitDefs) do
			local give = true
			for _, Condition in ipairs(Accept) do
				if not Condition(ud) then
					give = false
					break
				end
			end
			if give then
				giveUnits[#giveUnits + 1] = ud.id
			end
		end

		Spring.Echo("givecat found " .. #giveUnits .. " units")
		if #giveUnits == 0 then
			return
		end

		local mx, my = Spring.GetMouseState()
		local t, pos = Spring.TraceScreenRay(mx, my, true)
		local n = 0
		local ox, oz = math.floor(pos[1]), math.floor(pos[3])
		local x, z = ox, oz

		local msg = "givecat " .. x .. " " .. z .. " " .. teamID
		for _, uDID in ipairs(giveUnits) do
			msg = msg .. " " .. uDID
		end

		Spring.SendLuaRulesMsg(PACKET_HEADER .. ':' .. msg)
	end

end
