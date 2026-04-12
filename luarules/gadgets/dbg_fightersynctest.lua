local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Fightertest Synctest",
		desc = "Expanded engine-API sync test: spawns a broad mix of unit categories (bots, tanks, air, hover, subs, ships, spiders, commanders) concurrently and collects a per-frame sync-hash artifact for RecoilEngine#2910. Independent of the fightertest benchmark gadget. See RecoilEngine#2928.",
		author = "Bruno-DaSilva",
		date = "2026-04-13",
		license = "GNU GPL, v2 or later",
		layer = -1999999999,
		enabled = true
	}
end

local PACKET_HEADER = "$fts$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

local RUN_SEED = 7654321

if gadgetHandler:IsSyncedCode() then
	startPlayers = startPlayers or {}
end

local function isAuthorized(playerID, subPermission)
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

	local function checkStartPlayers()
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

	local mapSX = Game.mapSizeX
	local mapSZ = Game.mapSizeZ

	local active = false
	local runStartFrame = 0
	local totalFrames = 2000
	local placementRadius = 400
	local feedMod = 3
	local cleanupMod = 3
	local cleanupFeatureLife = 150
	local anchorRegions = 8
	local areaFraction = 1.0
	local areaOffsetX = 0.0
	local areaOffsetZ = 0.0
	local unitMultiplier = 2.0

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
		if #seededrand < 1 then initrandom(RUN_SEED) end
		randindex = randindex + 1
		if randindex > #seededrand then randindex = 1 end
		return seededrand[randindex]
	end

	local anchorsByClass = { land = {}, water = {}, deepwater = {}, air = {} }

	local function scanAnchors()
		anchorsByClass = { land = {}, water = {}, deepwater = {}, air = {} }
		local stride = 256
		local originX = mapSX * areaOffsetX
		local originZ = mapSZ * areaOffsetZ
		local areaX = mapSX * areaFraction
		local areaZ = mapSZ * areaFraction
		local regionW = areaX / anchorRegions
		local regionH = areaZ / anchorRegions
		for rz = 0, anchorRegions - 1 do
			for rx = 0, anchorRegions - 1 do
				local pickedLand, pickedWater, pickedDeep = false, false, false
				local z0 = originZ + rz * regionH + stride * 0.5
				local x0 = originX + rx * regionW + stride * 0.5
				for z = z0, originZ + (rz + 1) * regionH, stride do
					for x = x0, originX + (rx + 1) * regionW, stride do
						local h = Spring.GetGroundHeight(x, z)
						if not pickedLand and h > 32 then
							anchorsByClass.land[#anchorsByClass.land + 1] = { x = x, z = z }
							pickedLand = true
						end
						if not pickedWater and h < -16 then
							anchorsByClass.water[#anchorsByClass.water + 1] = { x = x, z = z }
							pickedWater = true
						end
						if not pickedDeep and h < -48 then
							anchorsByClass.deepwater[#anchorsByClass.deepwater + 1] = { x = x, z = z }
							pickedDeep = true
						end
						if pickedLand and pickedWater and pickedDeep then break end
					end
					if pickedLand and pickedWater and pickedDeep then break end
				end
			end
		end
		anchorsByClass.air = anchorsByClass.land
	end


	-- TODO: restore `cons` (with mex-build onSpawn) and `transports` (with
	-- load/unload onSpawn) categories once the broader test is stable.
	local categoryDefs = {
		{ name = "bots",       t1 = "armpw",    t2 = "corak",    max = 400, step = 28, class = "land" },
		{ name = "tanks",      t1 = "armbull",  t2 = "armbull",  max = 280, step = 14, class = "land" },
		{ name = "fighters",   t1 = "corvamp",  t2 = "armhawk",  max = 280, step = 14, class = "air" },
		{ name = "bombers",    t1 = "armpnix",  t2 = "corshad",  max = 140, step = 7,  class = "air" },
		{ name = "hover",      t1 = "armanac",  t2 = "corsh",    max = 200, step = 14, class = "land" },
		{ name = "subs",       t1 = "armsub",   t2 = "corsub",   max = 200, step = 14, class = "deepwater" },
		{ name = "ships",      t1 = "armpt",    t2 = "corpt",    max = 200, step = 14, class = "water" },
		{ name = "spiders",    t1 = "armspid",  t2 = "armflea",  max = 200, step = 14, class = "land" },
		{ name = "commanders", t1 = "armcom",   t2 = "corcom",   max = 3,   step = 1,  class = "land",
			noMultiplier = true },
	}

	local enabledCats = {}
	local allTeamUnitDefNames = {}

	local function filterCategories()
		enabledCats = {}
		allTeamUnitDefNames = {}
		for _, cat in ipairs(categoryDefs) do
			if UnitDefNames[cat.t1] and UnitDefNames[cat.t2] then
				local anchors = anchorsByClass[cat.class]
				if anchors and #anchors > 0 then
					cat.anchorCounter = 0
					cat.t1id = UnitDefNames[cat.t1].id
					cat.t2id = UnitDefNames[cat.t2].id
					if cat.noMultiplier then
						cat.effectiveMax  = cat.max
						cat.effectiveStep = cat.step
					else
						cat.effectiveMax  = math.max(1, math.floor(cat.max  * unitMultiplier / 2.0))
						cat.effectiveStep = math.max(1, math.floor(cat.step * unitMultiplier / 2.0))
					end
					enabledCats[#enabledCats + 1] = cat
					allTeamUnitDefNames[cat.t1] = true
					allTeamUnitDefNames[cat.t2] = true
				else
					Spring.Echo(string.format(
						"[fightersynctest] skipping category %s: no %s anchors", cat.name, cat.class))
				end
			end
		end
	end

	local function spawnBurstForCategoryAtAnchor(cat, teamID, udID, anchor)
		if Spring.GetTeamUnitDefCount(teamID, udID) >= cat.effectiveMax then return {} end

		local footprint = math.max(UnitDefs[udID].xsize, UnitDefs[udID].zsize)
		local sqrtFeed = math.max(1, math.ceil(math.sqrt(cat.effectiveStep)))
		local newUnitIDs = {}
		local numspawned = 0
		local cx = anchor.x + placementRadius * (getrandom() - 0.5)
		local cz = anchor.z + placementRadius * (getrandom() - 0.5)
		for x = 1, sqrtFeed do
			for z = 1, sqrtFeed do
				if numspawned < cat.effectiveStep then
					local px = cx + 12 * footprint * x
					local pz = cz + 12 * footprint * z
					local py = Spring.GetGroundHeight(px, pz)
					local uid = Spring.CreateUnit(udID, px, py, pz, "n", teamID)
					if uid then
						numspawned = numspawned + 1
						newUnitIDs[#newUnitIDs + 1] = uid
					end
				end
			end
		end

		if #newUnitIDs > 0 then
			Spring.GiveOrderToUnitArray(newUnitIDs, CMD.REPEAT, { 1 }, 0)
			local classAnchors = anchorsByClass[cat.class]
			for _ = 1, 3 do
				local destIdx = 1 + math.floor(getrandom() * #classAnchors)
				local dest = classAnchors[destIdx]
				local gh = Spring.GetGroundHeight(dest.x, dest.z)
				Spring.GiveOrderToUnitArray(newUnitIDs, CMD.FIGHT, { dest.x, gh, dest.z }, { "shift" })
			end
			local rh = Spring.GetGroundHeight(anchor.x, anchor.z)
			Spring.GiveOrderToUnitArray(newUnitIDs, CMD.FIGHT, { anchor.x, rh, anchor.z }, { "shift" })
		end
		return newUnitIDs
	end

	local function spawnBurstForCategory(cat)
		local anchors = anchorsByClass[cat.class]
		if not anchors or #anchors == 0 then return end
		cat.anchorCounter = cat.anchorCounter + 1
		local anchor = anchors[((cat.anchorCounter - 1) % #anchors) + 1]
		spawnBurstForCategoryAtAnchor(cat, 0, cat.t1id, anchor)
		spawnBurstForCategoryAtAnchor(cat, 1, cat.t2id, anchor)
	end


	-- TODO: restore scripted moments (commander dgun manualfire, armbull selfD
	-- sampling, commander cloak toggle, and any future ones) once the base
	-- test is solid. They previously fired at frames 300/600/900/1200 and
	-- pushed a `fightersynctest_scripted_tick` event to the HUD.

	local featurestoremove = {}
	local featureDefsToRemove = {}

	local function computeFeatureDefsToRemove()
		featureDefsToRemove = {}
		for udName in pairs(allTeamUnitDefNames) do
			for _, suffix in ipairs({ "_dead", "_heap" }) do
				local fd = FeatureDefNames[udName .. suffix]
				if fd and fd.id then
					featureDefsToRemove[fd.id] = true
				end
			end
		end
	end


	local function removeAllSpawnedUnits()
		local all = Spring.GetAllUnits()
		local removedByDef = {}
		for _, uid in ipairs(all) do
			local udID = Spring.GetUnitDefID(uid)
			local ud = udID and UnitDefs[udID]
			if ud and allTeamUnitDefNames[ud.name] then
				Spring.DestroyUnit(uid, false, true)
				removedByDef[ud.name] = (removedByDef[ud.name] or 0) + 1
			end
		end
		local allFeatures = Spring.GetAllFeatures()
		for _, fid in ipairs(allFeatures) do
			local fdID = Spring.GetFeatureDefID(fid)
			if fdID and featureDefsToRemove[fdID] then
				Spring.DestroyFeature(fid)
			end
		end
		for name, n in pairs(removedByDef) do
			Spring.Echo(string.format("[fightersynctest] removed %d x %s", n, name))
		end
	end


	local function startRun(words)
		if words[2] then
			local f = tonumber(words[2])
			if f then totalFrames = math.max(60, math.floor(f)) end
		end
		if words[3] then
			local af = tonumber(words[3])
			if af and af > 0 and af <= 1 then areaFraction = af end
		end
		if words[4] then
			local ox = tonumber(words[4])
			if ox and ox >= 0 and ox <= 1 then areaOffsetX = ox end
		end
		if words[5] then
			local oz = tonumber(words[5])
			if oz and oz >= 0 and oz <= 1 then areaOffsetZ = oz end
		end
		if words[6] then
			local m = tonumber(words[6])
			if m and m > 0 and m <= 8 then unitMultiplier = m end
		end
		if areaOffsetX + areaFraction > 1 then areaOffsetX = 1 - areaFraction end
		if areaOffsetZ + areaFraction > 1 then areaOffsetZ = 1 - areaFraction end

		runStartFrame = Spring.GetGameFrame()
		initrandom(RUN_SEED)
		scanAnchors()
		filterCategories()
		computeFeatureDefsToRemove()
		featurestoremove = {}

		Spring.Echo(string.format(
			"[fightersynctest] starting: totalframes=%d area=%.2f offset=%.2f,%.2f mult=%.2f categories=%d anchors land/water/deep/air=%d/%d/%d/%d",
			totalFrames, areaFraction, areaOffsetX, areaOffsetZ, unitMultiplier, #enabledCats,
			#anchorsByClass.land, #anchorsByClass.water, #anchorsByClass.deepwater, #anchorsByClass.air))
		SendToUnsynced("fightersynctest_synchash_begin", totalFrames)
		active = true
	end

	local function endRun()
		active = false
		Spring.Echo(string.format("[fightersynctest] ending after %d frames", Spring.GetGameFrame() - runStartFrame))
		removeAllSpawnedUnits()
		SendToUnsynced("fightersynctest_synchash_end")
	end

	local function toggleRun(words)
		if active then endRun() else startRun(words) end
	end

	function gadget:Initialize()
		checkStartPlayers()
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		msg = string.sub(msg, PACKET_HEADER_LENGTH)
		local words = {}
		for word in msg:gmatch("[%-_%w%.]+") do
			table.insert(words, word)
		end
		if words[1] ~= "fightersynctest" then return end
		if not isAuthorized(playerID, "terrain") then return end
		toggleRun(words)
	end

	function gadget:FeatureCreated(featureID, allyTeam)
		if not active then return end
		local fdID = Spring.GetFeatureDefID(featureID)
		if fdID and featureDefsToRemove[fdID] then
			featurestoremove[featureID] = Spring.GetGameFrame() + cleanupFeatureLife
		end
	end

	function gadget:GameFrame(n)
		if not active then return end

		local runFrame = n - runStartFrame

		if n % feedMod == 0 then
			for _, cat in ipairs(enabledCats) do
				spawnBurstForCategory(cat)
			end
		end

		if n % cleanupMod == 1 then
			for featureID, deathtime in pairs(featurestoremove) do
				if deathtime < n then
					if Spring.ValidFeatureID(featureID) then
						Spring.DestroyFeature(featureID)
					end
					featurestoremove[featureID] = nil
				end
			end
		end

		if runFrame >= totalFrames then
			endRun()
		end
	end


else	-- UNSYNCED


	local vsx, vsy = Spring.GetViewGeometry()
	local uiScale = vsy / 1080

	local synchashBuffer = {}
	local synchashFirstFrame, synchashLastFrame

	local hudActive = false
	local hudTotalFrames = 0
	local hudRunStartFrame = nil

	local function onSynchashBegin(_, totalFrames)
		synchashBuffer = {}
		synchashFirstFrame, synchashLastFrame = nil, nil
		hudActive = true
		hudTotalFrames = tonumber(totalFrames) or 0
		hudRunStartFrame = Spring.GetGameFrame()
	end

	function gadget:GameFrame(n)
		if not hudActive then return end
		if not Engine.hasSyncChecksums then return end
		local checksum = tostring(Spring.GetPrevFrameSyncChecksum() or "")
		synchashBuffer[#synchashBuffer + 1] = string.format("%d:%s", n, checksum)
		if not synchashFirstFrame then synchashFirstFrame = n end
		synchashLastFrame = n
	end

	local function onSynchashEnd()
		hudActive = false
		local count = #synchashBuffer
		if count == 0 then
			Spring.Echo("[fightersynctest] sync-hash: no frames collected (engine may lack Spring.GetPrevFrameSyncChecksum)")
			return
		end
		local blob = table.concat(synchashBuffer, "\n")
		local digest = VFS.CalculateHash(blob, 0)

		local path = "fightersynctest_synchash.txt"
		local content = digest .. "\n"
			.. string.format("frames=%d first=%d last=%d\n",
				count, synchashFirstFrame or -1, synchashLastFrame or -1)
			.. blob .. "\n"

		local f, err = io.open(path, "w")
		if not f then
			Spring.Echo("[fightersynctest] sync-hash: failed to open " .. tostring(path) .. ": " .. tostring(err))
			return
		end
		f:write(content)
		f:close()
		Spring.Echo(string.format(
			"[fightersynctest] sync-hash: wrote %s (md5=%s, %d frames %d..%d)",
			path, digest, count, synchashFirstFrame or -1, synchashLastFrame or -1))
		synchashBuffer = {}
	end

	local function fightersynctest(_, line, words, playerID, action)
		if playerID ~= Spring.GetMyPlayerID() then return end
		Spring.Echo("[fightersynctest]", line, playerID, action)
		if not isAuthorized(playerID, "terrain") then return end
		local msg = PACKET_HEADER .. ':fightersynctest'
		for i = 1, 6 do
			if words[i] then msg = msg .. " " .. tostring(words[i]) end
		end
		Spring.SendLuaRulesMsg(msg)
	end

	function gadget:ViewResize()
		vsx, vsy = Spring.GetViewGeometry()
		uiScale = vsy / 1080
	end

	function gadget:DrawScreen()
		if not hudActive then return end
		local gameFrame = Spring.GetGameFrame()
		local runFrame = hudRunStartFrame and (gameFrame - hudRunStartFrame) or 0
		gl.Color(1, 1, 1, 1)
		gl.Text(string.format("Fightertest Synctest  frame %d / %d", runFrame, hudTotalFrames),
			600 * uiScale, 600 * uiScale, 16 * uiScale)
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction('fightersynctest', fightersynctest, "")
		gadgetHandler:AddSyncAction('fightersynctest_synchash_begin', onSynchashBegin)
		gadgetHandler:AddSyncAction('fightersynctest_synchash_end',   onSynchashEnd)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('fightersynctest')
		gadgetHandler:RemoveSyncAction('fightersynctest_synchash_begin')
		gadgetHandler:RemoveSyncAction('fightersynctest_synchash_end')
	end

end
