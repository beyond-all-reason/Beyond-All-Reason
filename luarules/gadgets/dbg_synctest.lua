local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Synctest",
		desc = "Expanded engine-API sync test: spawns a broad mix of unit categories (bots, tanks, air, hover, subs, ships, spiders, commanders) concurrently and collects a per-frame sync-hash artifact for RecoilEngine#2910. Independent of the benchmark gadget. See RecoilEngine#2928.",
		author = "Bruno-DaSilva",
		date = "2026-04-13",
		license = "GNU GPL, v2 or later",
		layer = -1999999999,
		enabled = true,
	}
end

local PACKET_HEADER = "$st$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)

local RUN_SEED = 7654321

if gadgetHandler:IsSyncedCode() then
	startPlayers = startPlayers or {}
end

local function isAuthorized(playerID, subPermission)
	if SpringShared.IsCheatingEnabled() then
		return true
	end
	local playername = SpringShared.GetPlayerInfo(playerID)
	local accountID = Utilities.GetAccountID(playerID)
	local hasPermission = false
	if (_G and _G.permissions.devhelpers and (_G.permissions.devhelpers[accountID] or (playername and _G.permissions.devhelpers[playername]))) or (SYNCED and SYNCED.permissions.devhelpers and (SYNCED.permissions.devhelpers[accountID] or (playername and SYNCED.permissions.devhelpers[playername]))) then
		hasPermission = true
	end
	if not hasPermission and subPermission then
		local permKey = "devhelpers_" .. subPermission
		if (_G and _G.permissions[permKey] and (_G.permissions[permKey][accountID] or (playername and _G.permissions[permKey][playername]))) or (SYNCED and SYNCED.permissions[permKey] and (SYNCED.permissions[permKey][accountID] or (playername and SYNCED.permissions[permKey][playername]))) then
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
	--------------------------------------------------------------------
	-- Run configuration and state
	--------------------------------------------------------------------

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
	local unitMultiplier = 1.0

	local seededrand = {}
	local randindex = 1

	local anchorsByClass = { land = {}, water = {}, air = {} }

	-- TODO: add `cons` (with mex-build onSpawn) and `transports` (with
	-- load/unload onSpawn).
	local categoryDefs = {
		{ name = "bots", t1 = "armpw", t2 = "corak", max = 400, step = 28, class = "land" },
		{ name = "tanks", t1 = "armbull", t2 = "armbull", max = 280, step = 14, class = "land" },
		{ name = "fighters", t1 = "corvamp", t2 = "armhawk", max = 280, step = 14, class = "air" },
		{ name = "bombers", t1 = "armpnix", t2 = "corshad", max = 140, step = 7, class = "air" },
		{ name = "hover", t1 = "armanac", t2 = "corsh", max = 200, step = 14, class = "land" },
		{ name = "subs", t1 = "armsub", t2 = "corsub", max = 200, step = 14, class = "water" },
		{ name = "ships", t1 = "armpt", t2 = "corpt", max = 200, step = 14, class = "water" },
		{ name = "spiders", t1 = "armspid", t2 = "armflea", max = 200, step = 14, class = "land" },
		{ name = "commanders", t1 = "armcom", t2 = "corcom", max = 3, step = 1, class = "land", noMultiplier = true },
	}

	local enabledCats = {}
	local allTeamUnitDefNames = {}

	local featurestoremove = {}
	local featureDefsToRemove = {}

	--------------------------------------------------------------------
	-- Forward declarations (so sections read top-down)
	--------------------------------------------------------------------

	local initrandom, getrandom
	local scanAnchors
	local initCategoriesForRun
	local spawnBurstForCategory, spawnBurstForCategoryAtAnchor
	local computeFeatureDefsToRemove, removeAllSpawnedUnits

	--------------------------------------------------------------------
	-- Run lifecycle
	--------------------------------------------------------------------

	-- Supported positional arguments (all optional, parsed from the chat command):
	--   words[2] totalFrames    how many frames to run        integer, >= 60      (default 2000)
	--   words[3] areaFraction   fraction of the map used      number in (0, 1]    (default 1.0)
	--   words[4] areaOffsetX    normalized x start of area    number in [0, 1]    (default 0.0)
	--   words[5] areaOffsetZ    normalized z start of area    number in [0, 1]    (default 0.0)
	--   words[6] unitMultiplier scales nuymber of units       number in (0, 8]    (default 1.0)
	-- areaOffsetX/Z are clamped so offset + areaFraction <= 1.
	local function startRun(words)
		if words[2] then
			local f = tonumber(words[2])
			if f then
				totalFrames = math.max(60, math.floor(f))
			end
		end
		if words[3] then
			local af = tonumber(words[3])
			if af and af > 0 and af <= 1 then
				areaFraction = af
			end
		end
		if words[4] then
			local ox = tonumber(words[4])
			if ox and ox >= 0 and ox <= 1 then
				areaOffsetX = ox
			end
		end
		if words[5] then
			local oz = tonumber(words[5])
			if oz and oz >= 0 and oz <= 1 then
				areaOffsetZ = oz
			end
		end
		if words[6] then
			local m = tonumber(words[6])
			if m and m > 0 and m <= 8 then
				unitMultiplier = m
			end
		end
		if areaOffsetX + areaFraction > 1 then
			areaOffsetX = 1 - areaFraction
		end
		if areaOffsetZ + areaFraction > 1 then
			areaOffsetZ = 1 - areaFraction
		end

		runStartFrame = SpringShared.GetGameFrame()
		initrandom(RUN_SEED)
		scanAnchors()
		initCategoriesForRun()
		computeFeatureDefsToRemove()
		featurestoremove = {}

		SpringShared.Echo(string.format("[synctest] starting: totalframes=%d area=%.2f offset=%.2f,%.2f mult=%.2f categories=%d anchors land/water/air=%d/%d/%d", totalFrames, areaFraction, areaOffsetX, areaOffsetZ, unitMultiplier, #enabledCats, #anchorsByClass.land, #anchorsByClass.water, #anchorsByClass.air))
		SendToUnsynced("synctest_synchash_begin", totalFrames, runStartFrame)
		active = true
	end

	local function endRun()
		active = false
		SpringShared.Echo(string.format("[synctest] ending after %d frames", SpringShared.GetGameFrame() - runStartFrame))
		removeAllSpawnedUnits()
		SendToUnsynced("synctest_synchash_end")
	end

	local function toggleRun(words)
		if active then
			endRun()
		else
			startRun(words)
		end
	end

	--------------------------------------------------------------------
	-- Main tick
	--------------------------------------------------------------------

	function gadget:GameFrame(n)
		if not active then
			return
		end

		local runFrame = n - runStartFrame

		if runFrame % feedMod == 0 then
			for _, cat in ipairs(enabledCats) do
				spawnBurstForCategory(cat)
			end
		end

		-- remove wreckage left behind by unit deaths after a delay
		-- this keeps the map from getting too cluttered
		if runFrame % cleanupMod == 1 then
			for featureID, deathtime in pairs(featurestoremove) do
				if deathtime < runFrame then
					if SpringShared.ValidFeatureID(featureID) then
						SpringSynced.DestroyFeature(featureID)
					end
					featurestoremove[featureID] = nil
				end
			end
		end

		if runFrame >= totalFrames then
			endRun()
		end
	end

	--------------------------------------------------------------------
	-- Anchor selection (per-class spawn/destination points)
	--------------------------------------------------------------------

	function scanAnchors()
		anchorsByClass = { land = {}, water = {}, air = {} }
		local stride = 256
		local originX = mapSX * areaOffsetX
		local originZ = mapSZ * areaOffsetZ
		local areaX = mapSX * areaFraction
		local areaZ = mapSZ * areaFraction
		local regionW = areaX / anchorRegions
		local regionH = areaZ / anchorRegions
		for rz = 0, anchorRegions - 1 do
			for rx = 0, anchorRegions - 1 do
				local pickedLand, pickedWater = false, false
				local z0 = originZ + rz * regionH + stride * 0.5
				local x0 = originX + rx * regionW + stride * 0.5
				for z = z0, originZ + (rz + 1) * regionH, stride do
					for x = x0, originX + (rx + 1) * regionW, stride do
						local h = SpringShared.GetGroundHeight(x, z)
						if not pickedLand and h > 32 then
							anchorsByClass.land[#anchorsByClass.land + 1] = { x = x, z = z }
							pickedLand = true
						end
						if not pickedWater and h < -15 then
							anchorsByClass.water[#anchorsByClass.water + 1] = { x = x, z = z }
							pickedWater = true
						end
						if pickedLand and pickedWater then
							break
						end
					end
					if pickedLand and pickedWater then
						break
					end
				end
			end
		end
		anchorsByClass.air = anchorsByClass.land
	end

	--------------------------------------------------------------------
	-- Spawning bursts of units, with randomized placement and orders
	--------------------------------------------------------------------

	-- TODO: add scripted moments (commander dgun manualfire, armbull selfD
	-- sampling, commander cloak toggle, and any future ones) once the base
	-- test is solid.

	function spawnBurstForCategoryAtAnchor(cat, teamID, udID, anchor)
		if SpringShared.GetTeamUnitDefCount(teamID, udID) >= cat.effectiveMax then
			return {}
		end

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
					local py = SpringShared.GetGroundHeight(px, pz)
					local uid = SpringSynced.CreateUnit(udID, px, py, pz, "n", teamID)
					if uid then
						numspawned = numspawned + 1
						newUnitIDs[#newUnitIDs + 1] = uid
					end
				end
			end
		end

		-- Give some randomized orders to the new units, to mix up the execution paths and
		-- make sure they actually do something instead of just sitting idle.
		if #newUnitIDs > 0 then
			SpringShared.GiveOrderToUnitArray(newUnitIDs, CMD.REPEAT, { 1 }, 0)
			local classAnchors = anchorsByClass[cat.class]
			for _ = 1, 3 do
				local destIdx = 1 + math.floor(getrandom() * #classAnchors)
				local dest = classAnchors[destIdx]
				local gh = SpringShared.GetGroundHeight(dest.x, dest.z)
				SpringShared.GiveOrderToUnitArray(newUnitIDs, CMD.FIGHT, { dest.x, gh, dest.z }, { "shift" })
			end
			local rh = SpringShared.GetGroundHeight(anchor.x, anchor.z)
			SpringShared.GiveOrderToUnitArray(newUnitIDs, CMD.FIGHT, { anchor.x, rh, anchor.z }, { "shift" })
		end
		return newUnitIDs
	end

	function spawnBurstForCategory(cat)
		local anchors = anchorsByClass[cat.class]
		if not anchors or #anchors == 0 then
			return
		end
		cat.anchorCounter = cat.anchorCounter + 1
		local anchor = anchors[((cat.anchorCounter - 1) % #anchors) + 1]

		-- make sure we spawn for both teams
		spawnBurstForCategoryAtAnchor(cat, 0, cat.t1id, anchor)
		spawnBurstForCategoryAtAnchor(cat, 1, cat.t2id, anchor)
	end

	--------------------------------------------------------------------
	-- Unit category setup
	--------------------------------------------------------------------

	function initCategoriesForRun()
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
						cat.effectiveMax = cat.max
						cat.effectiveStep = cat.step
					else
						cat.effectiveMax = math.max(1, math.floor(cat.max * unitMultiplier / 2.0))
						cat.effectiveStep = math.max(1, math.floor(cat.step * unitMultiplier / 2.0))
					end
					enabledCats[#enabledCats + 1] = cat
					allTeamUnitDefNames[cat.t1] = true
					allTeamUnitDefNames[cat.t2] = true
				else
					SpringShared.Echo(string.format("[synctest] skipping category %s: no %s anchors", cat.name, cat.class))
				end
			end
		end
	end

	--------------------------------------------------------------------
	-- Cleanup: wreckage expiry + end-of-run teardown
	--------------------------------------------------------------------

	function computeFeatureDefsToRemove()
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

	function gadget:FeatureCreated(featureID, allyTeam)
		if not active then
			return
		end
		local fdID = SpringShared.GetFeatureDefID(featureID)
		if fdID and featureDefsToRemove[fdID] then
			featurestoremove[featureID] = (SpringShared.GetGameFrame() - runStartFrame) + cleanupFeatureLife
		end
	end

	function removeAllSpawnedUnits()
		local all = SpringShared.GetAllUnits()
		local removedByDef = {}
		for _, uid in ipairs(all) do
			local udID = SpringShared.GetUnitDefID(uid)
			local ud = udID and UnitDefs[udID]
			if ud and allTeamUnitDefNames[ud.name] then
				SpringSynced.DestroyUnit(uid, false, true)
				removedByDef[ud.name] = (removedByDef[ud.name] or 0) + 1
			end
		end
		local allFeatures = SpringShared.GetAllFeatures()
		for _, fid in ipairs(allFeatures) do
			local fdID = SpringShared.GetFeatureDefID(fid)
			if fdID and featureDefsToRemove[fdID] then
				SpringSynced.DestroyFeature(fid)
			end
		end
		for name, n in pairs(removedByDef) do
			SpringShared.Echo(string.format("[synctest] removed %d x %s", n, name))
		end
	end

	--------------------------------------------------------------------
	-- Chat entry point + startPlayers gating
	--------------------------------------------------------------------

	local function recordStartPlayers()
		for _, playerID in ipairs(SpringShared.GetPlayerList()) do
			local playername, _, spec = SpringShared.GetPlayerInfo(playerID, false)
			if not spec then
				startPlayers[playername] = true
			end
		end
	end

	function gadget:Initialize()
		recordStartPlayers()
	end

	function gadget:GameStart()
		recordStartPlayers()
	end

	-- Entry point for the `/synctest` chat command, relayed from unsynced
	-- via Spring.SendLuaRulesMsg. Expected packet format:
	--   "$st$:synctest [totalFrames] [areaFraction] [areaOffsetX] [areaOffsetZ] [unitMultiplier]"
	-- See startRun() above for per-argument meaning, ranges, and defaults.
	-- Toggles a run: starts if idle, ends if already active.
	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		msg = string.sub(msg, PACKET_HEADER_LENGTH)
		local words = {}
		for word in msg:gmatch("[%-_%w%.]+") do
			table.insert(words, word)
		end
		if words[1] ~= "synctest" then
			return
		end
		if not isAuthorized(playerID, "terrain") then
			return
		end
		toggleRun(words)
	end

	--------------------------------------------------------------------
	-- Seeded RNG
	--------------------------------------------------------------------

	function initrandom(seed)
		math.randomseed(seed)
		for i = 1, 5000 do
			seededrand[i] = math.random()
		end
		randindex = 1
	end

	function getrandom()
		if #seededrand < 1 then
			initrandom(RUN_SEED)
		end
		randindex = randindex + 1
		if randindex > #seededrand then
			randindex = 1
		end
		return seededrand[randindex]
	end
else -- UNSYNCED
	--------------------------------------------------------------------
	-- HUD
	--------------------------------------------------------------------

	local vsx, vsy = SpringUnsynced.GetViewGeometry()
	local uiScale = vsy / 1080

	local hudActive = false
	local hudTotalFrames = 0
	local hudRunStartFrame = nil

	function gadget:ViewResize()
		vsx, vsy = SpringUnsynced.GetViewGeometry()
		uiScale = vsy / 1080
	end

	function gadget:DrawScreen()
		if not hudActive then
			return
		end
		local gameFrame = SpringShared.GetGameFrame()
		local runFrame = hudRunStartFrame and (gameFrame - hudRunStartFrame) or 0
		gl.Color(1, 1, 1, 1)
		gl.Text(string.format("Synctest  frame %d / %d", runFrame, hudTotalFrames), 600 * uiScale, 600 * uiScale, 16 * uiScale)
	end

	--------------------------------------------------------------------
	-- Sync-hash capture
	--------------------------------------------------------------------

	local frameBuffer = {}
	local checksumBuffer = {}
	local synchashFirstFrame, synchashLastFrame

	local function onSynchashBegin(_, totalFrames, runStartFrame)
		frameBuffer = {}
		checksumBuffer = {}
		synchashFirstFrame, synchashLastFrame = nil, nil
		hudActive = true
		hudTotalFrames = tonumber(totalFrames) or 0
		hudRunStartFrame = tonumber(runStartFrame) or SpringShared.GetGameFrame()
	end

	function gadget:GameFrame(n)
		if not hudActive then
			return
		end
		if not Engine.hasSyncChecksums then
			return
		end
		local checksum = Spring.GetPrevFrameSyncChecksum()
		local runFrame = n - hudRunStartFrame
		local i = #checksumBuffer + 1
		frameBuffer[i] = runFrame
		checksumBuffer[i] = checksum
		if not synchashFirstFrame then
			synchashFirstFrame = runFrame
		end
		synchashLastFrame = runFrame
	end

	local function onSynchashEnd()
		hudActive = false
		local count = #checksumBuffer
		if count == 0 then
			SpringShared.Echo("[synctest] sync-hash: no frames collected (Engine.hasSyncChecksums is false — engine built without SYNCCHECK)")
			return
		end

		-- Digest is computed purely over the checksum values in frame order, so it
		-- stays stable across any future change to the file format.
		local digest = VFS.CalculateHash(table.concat(checksumBuffer, "\n"), 0)

		local checksums = {}
		for i = 1, count do
			checksums[i] = { frame = frameBuffer[i], checksum = checksumBuffer[i] }
		end

		local path = "synctest_synchash.json"
		local content = Json.encode({
			digest = digest,
			frameCount = count,
			firstFrame = synchashFirstFrame or -1,
			lastFrame = synchashLastFrame or -1,
			checksums = checksums,
		})

		local f, err = io.open(path, "w")
		if not f then
			SpringShared.Echo("[synctest] sync-hash: failed to open " .. tostring(path) .. ": " .. tostring(err))
			return
		end
		f:write(content)
		f:close()
		SpringShared.Echo(string.format("[synctest] sync-hash: wrote %s (md5=%s, %d frames %d..%d)", path, digest, count, synchashFirstFrame or -1, synchashLastFrame or -1))
		frameBuffer = {}
		checksumBuffer = {}
	end

	--------------------------------------------------------------------
	-- Chat action + gadget lifecycle
	--------------------------------------------------------------------

	local function synctest(_, line, words, playerID, action)
		if playerID ~= SpringUnsynced.GetLocalPlayerID() then
			return
		end
		SpringShared.Echo("[synctest]", line, playerID, action)
		if not isAuthorized(playerID, "terrain") then
			return
		end
		local msg = PACKET_HEADER .. ":synctest"
		for i = 1, 6 do
			if words[i] then
				msg = msg .. " " .. tostring(words[i])
			end
		end
		SpringUnsynced.SendLuaRulesMsg(msg)
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction("synctest", synctest, "")
		gadgetHandler:AddSyncAction("synctest_synchash_begin", onSynchashBegin)
		gadgetHandler:AddSyncAction("synctest_synchash_end", onSynchashEnd)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("synctest")
		gadgetHandler:RemoveSyncAction("synctest_synchash_begin")
		gadgetHandler:RemoveSyncAction("synctest_synchash_end")
	end
end
