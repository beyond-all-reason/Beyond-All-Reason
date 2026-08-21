function widget:GetInfo()
	return {
		name = "Clump Benchmark",
		desc = "/clumpbench [trees] [seconds] - measures frame cost of N single trees vs the same trees as baked clumps",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Measures what merging trees into clump features actually buys on THIS
-- machine: same tree count, same area, same geometry per tree -- the only
-- variable is the entity count (4000 features vs 500). Three phases with a
-- fixed camera: empty baseline, single trees, clumps. Vsync is forced off for
-- the duration so the numbers are not cap-flattened, and restored after.
--
-- Spawning goes through the Feature Placer gadget's message protocol, so
-- /cheat is required (toggled on and back automatically when hosting).
-- The test area is scanned first and the run ABORTS if it already holds
-- features: cleanup is an area-remove, and eating someone's authored forest
-- for a benchmark would be a poor trade. Run it on a blank/new map.

local PLACELIST_HEADER = "$feature_place_list$"
local REMOVE_HEADER = "$feature_remove$"

local Echo = Spring.Echo
local SendLuaRulesMsg = Spring.SendLuaRulesMsg
local SendCommands = Spring.SendCommands

local floor = math.floor
local sqrt = math.sqrt

local DEFAULT_TREES = 4000
local DEFAULT_MEASURE_SECONDS = 10
local SETTLE_SECONDS = 3 -- model upload + placement wobble before measuring
local SINGLE_SPACING = 26 -- elmos between single trees
local BATCH = 40 -- entries per message, matches the placer
local MSGS_PER_FRAME = 10

local RESULTS_DIR = "Benchmarks/"

local bench = nil -- nil = idle

local function fmt(n, digits)
	return string.format("%." .. (digits or 1) .. "f", n)
end

----------------------------------------------------------------
-- Layout + spawning
----------------------------------------------------------------
local function forestParams(treeCount)
	local cols = math.ceil(sqrt(treeCount))
	local extent = cols * SINGLE_SPACING -- side length of the forest square
	local cx = Game.mapSizeX / 2
	local cz = Game.mapSizeZ / 2
	return cx, cz, extent, cols
end

local function areaFeatureCount(cx, cz, extent)
	local r = extent * 0.75 + 200
	local features = Spring.GetFeaturesInRectangle(cx - r, cz - r, cx + r, cz + r)
	return features and #features or 0
end

-- Deterministic pseudo-random from the index, so reruns are identical.
local function hash01(i, salt)
	local v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return v - floor(v)
end

local function buildSingleEntries(treeCount)
	local cx, cz, extent, cols = forestParams(treeCount)
	local entries = {}
	for i = 0, treeCount - 1 do
		local col = i % cols
		local row = floor(i / cols)
		local x = cx - extent / 2 + (col + 0.25 + hash01(i, 1) * 0.5) * SINGLE_SPACING
		local z = cz - extent / 2 + (row + 0.25 + hash01(i, 2) * 0.5) * SINGLE_SPACING
		local defName = "treetype" .. (i % 16)
		local heading = floor(hash01(i, 3) * 65536)
		entries[#entries + 1] = string.format("%s %.1f %.1f %d", defName, x, z, heading)
	end
	return entries
end

local function buildClumpEntries(treeCount)
	-- Large clumps carry 8 trees each; same area as the singles so the visual
	-- density (and pixel coverage) stays comparable.
	local clumpCount = math.max(1, floor(treeCount / 8))
	local cx, cz, extent = forestParams(treeCount)
	local cols = math.ceil(sqrt(clumpCount))
	local spacing = extent / cols
	local entries = {}
	for i = 0, clumpCount - 1 do
		local col = i % cols
		local row = floor(i / cols)
		local x = cx - extent / 2 + (col + 0.25 + hash01(i, 4) * 0.5) * spacing
		local z = cz - extent / 2 + (row + 0.25 + hash01(i, 5) * 0.5) * spacing
		local defName = (i % 2 == 0) and "treecluster_fir_l1" or "treecluster_fir_l2"
		local heading = floor(hash01(i, 6) * 65536)
		entries[#entries + 1] = string.format("%s %.1f %.1f %d", defName, x, z, heading)
	end
	return entries, clumpCount
end

local strokeCounter = 0
local function queueSpawn(entries)
	strokeCounter = strokeCounter + 1
	local strokeID = string.format("bench%d.%d", floor(os.clock() * 100) % 65536, strokeCounter)
	local msgs = {}
	for i = 1, #entries, BATCH do
		local batch = {}
		for j = i, math.min(i + BATCH - 1, #entries) do
			batch[#batch + 1] = entries[j]
		end
		msgs[#msgs + 1] = PLACELIST_HEADER .. strokeID .. "|" .. table.concat(batch, "|")
	end
	return msgs
end

local function removeTestArea(treeCount)
	local cx, cz, extent = forestParams(treeCount)
	-- The remove message clamps radius to 2000; the default forest fits in one.
	local r = math.min(2000, extent * 0.75 + 200)
	SendLuaRulesMsg(REMOVE_HEADER .. floor(cx) .. " " .. floor(cz) .. " " .. floor(r) .. " circle 0")
end

----------------------------------------------------------------
-- Measurement
----------------------------------------------------------------
local function newSample()
	return { frames = 0, seconds = 0, worst = 0, dts = {} }
end

local function sampleStats(s)
	if s.frames == 0 then
		return { fps = 0, avgMs = 0, p95Ms = 0, worstMs = 0, frames = 0 }
	end
	table.sort(s.dts)
	local p95 = s.dts[math.max(1, floor(#s.dts * 0.95))]
	return {
		fps = s.frames / s.seconds,
		avgMs = (s.seconds / s.frames) * 1000,
		p95Ms = p95 * 1000,
		worstMs = s.worst * 1000,
		frames = s.frames,
	}
end

----------------------------------------------------------------
-- Phase machine
----------------------------------------------------------------
-- PREP -> BASE -> SPAWN1 -> SETTLE1 -> MEAS1 -> CLEAR1 ->
-- SPAWN2 -> SETTLE2 -> MEAS2 -> DONE
local function startBench(treeCount, measureSeconds)
	if bench then
		Echo("[ClumpBench] already running")
		return
	end
	if not FeatureDefNames["treecluster_fir_l1"] then
		Echo("[ClumpBench] treecluster_fir_* defs missing - restart the game to load features/tree_clumps.lua first")
		return
	end

	local cx, cz, extent = forestParams(treeCount)
	local existing = areaFeatureCount(cx, cz, extent)
	if existing > 0 then
		Echo("[ClumpBench] test area at map centre holds " .. existing .. " features; refusing to run (cleanup would remove them). Use a blank map.")
		return
	end

	local cheatWasOn = Spring.IsCheatingEnabled()
	if not cheatWasOn then
		SendCommands("cheat")
	end

	-- Cap-flattened numbers are useless; force vsync off for the run.
	local vsync = Spring.GetConfigInt("VSync", 0)
	if vsync ~= 0 then
		SendCommands("vsync 0")
	end

	-- Fixed overhead camera covering the forest, identical for all phases.
	local camState = Spring.GetCameraState()
	local st = Spring.GetCameraState()
	st.px, st.py, st.pz = cx, extent * 1.35, cz + 1
	st.height = extent * 1.35
	st.rx, st.ry = math.pi, 0
	st.dx, st.dy, st.dz = 0, -1, 0
	Spring.SetCameraState(st, 0)
	-- Belt and braces across camera modes: whatever state fields the current
	-- mode ignored, this still aims it at the forest centre.
	Spring.SetCameraTarget(cx, 0, cz, 0)

	bench = {
		phase = "PREP",
		t = 0,
		trees = treeCount,
		measureSeconds = measureSeconds,
		pending = nil,
		results = {},
		clumpCount = 0,
		restore = { cheatWasOn = cheatWasOn, vsync = vsync, camState = camState },
	}
	Echo("[ClumpBench] running: " .. treeCount .. " trees, " .. measureSeconds .. "s per phase, vsync off")
end

local function finishBench(aborted)
	local b = bench
	bench = nil
	if not b then
		return
	end

	removeTestArea(b.trees)
	Spring.SetCameraState(b.restore.camState, 0.5)
	if b.restore.vsync ~= 0 then
		SendCommands("vsync " .. b.restore.vsync)
	end
	if not b.restore.cheatWasOn and Spring.IsCheatingEnabled() then
		SendCommands("cheat")
	end
	if aborted then
		Echo("[ClumpBench] aborted, test area cleaned up")
		return
	end

	local base = sampleStats(b.results.BASE)
	local singles = sampleStats(b.results.SINGLES)
	local clumps = sampleStats(b.results.CLUMPS)
	local singleCost = singles.avgMs - base.avgMs
	local clumpCost = clumps.avgMs - base.avgMs

	local lines = {
		"Clump benchmark - " .. os.date("%Y-%m-%d %H:%M:%S"),
		string.format("map %s | %d trees | %d singles vs %d clumps | %ds per phase, vsync off", Game.mapName, b.trees, b.trees, b.clumpCount, b.measureSeconds),
		"",
		string.format("%-22s %8s %10s %10s %10s", "phase", "fps", "avg ms", "p95 ms", "worst ms"),
		string.format("%-22s %8s %10s %10s %10s", "empty baseline", fmt(base.fps), fmt(base.avgMs, 2), fmt(base.p95Ms, 2), fmt(base.worstMs, 2)),
		string.format("%-22s %8s %10s %10s %10s", b.trees .. " single trees", fmt(singles.fps), fmt(singles.avgMs, 2), fmt(singles.p95Ms, 2), fmt(singles.worstMs, 2)),
		string.format("%-22s %8s %10s %10s %10s", b.clumpCount .. " clumps (8 trees ea)", fmt(clumps.fps), fmt(clumps.avgMs, 2), fmt(clumps.p95Ms, 2), fmt(clumps.worstMs, 2)),
		"",
		string.format("forest cost over baseline: singles %s ms, clumps %s ms", fmt(singleCost, 2), fmt(clumpCost, 2)),
	}
	if clumpCost > 0.005 then
		lines[#lines + 1] = string.format("=> clumps cost %.1fx less frame time for the same forest", singleCost / clumpCost)
	end

	for _, line in ipairs(lines) do
		Echo("[ClumpBench] " .. line)
	end

	Spring.CreateDir(RESULTS_DIR)
	local path = RESULTS_DIR .. "clumpbench_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
	local f = io.open(path, "w")
	if f then
		f:write(table.concat(lines, "\n") .. "\n")
		f:close()
		Echo("[ClumpBench] written to " .. path)
	end
end

function widget:Update(dt)
	local b = bench
	if not b then
		return
	end
	b.t = b.t + dt

	local phase = b.phase

	if phase == "PREP" then
		if b.t > 1 then
			if not Spring.IsCheatingEnabled() then
				Echo("[ClumpBench] /cheat did not enable (not hosting?); aborting")
				finishBench(true)
				return
			end
			b.phase, b.t = "BASE", 0
			b.results.BASE = newSample()
		end
		return
	end

	if phase == "BASE" or phase == "MEAS1" or phase == "MEAS2" then
		local key = (phase == "BASE" and "BASE") or (phase == "MEAS1" and "SINGLES") or "CLUMPS"
		local s = b.results[key]
		s.frames = s.frames + 1
		s.seconds = s.seconds + dt
		s.dts[#s.dts + 1] = dt
		if dt > s.worst then
			s.worst = dt
		end
		if s.seconds >= b.measureSeconds then
			if phase == "BASE" then
				b.pending = queueSpawn(buildSingleEntries(b.trees))
				b.phase, b.t = "SPAWN1", 0
			elseif phase == "MEAS1" then
				removeTestArea(b.trees)
				b.phase, b.t = "CLEAR1", 0
			else
				finishBench(false)
			end
		end
		return
	end

	if phase == "SPAWN1" or phase == "SPAWN2" then
		local pending = b.pending
		for _ = 1, MSGS_PER_FRAME do
			if #pending == 0 then
				break
			end
			SendLuaRulesMsg(table.remove(pending))
		end
		if #pending == 0 then
			b.pending = nil
			b.phase, b.t = (phase == "SPAWN1") and "SETTLE1" or "SETTLE2", 0
		end
		return
	end

	if phase == "SETTLE1" or phase == "SETTLE2" then
		if b.t > SETTLE_SECONDS then
			local key = (phase == "SETTLE1") and "SINGLES" or "CLUMPS"
			b.results[key] = newSample()
			b.phase, b.t = (phase == "SETTLE1") and "MEAS1" or "MEAS2", 0
			Echo("[ClumpBench] measuring " .. key:lower() .. " (" .. #Spring.GetAllFeatures() .. " features on map)")
		end
		return
	end

	if phase == "CLEAR1" then
		if b.t > 2 then
			local entries, clumpCount = buildClumpEntries(b.trees)
			b.clumpCount = clumpCount
			b.pending = queueSpawn(entries)
			b.phase, b.t = "SPAWN2", 0
		end
		return
	end
end

function widget:Initialize()
	widgetHandler:AddAction("clumpbench", function(_, _, args)
		local trees = tonumber(args and args[1]) or DEFAULT_TREES
		local seconds = tonumber(args and args[2]) or DEFAULT_MEASURE_SECONDS
		trees = math.max(320, math.min(20000, floor(trees / 16) * 16))
		seconds = math.max(3, math.min(60, seconds))
		startBench(trees, seconds)
		return true
	end, nil, "t")
	widgetHandler:AddAction("clumpbenchstop", function()
		if bench then
			finishBench(true)
		end
		return true
	end, nil, "t")
end

function widget:Shutdown()
	if bench then
		finishBench(true)
	end
	widgetHandler:RemoveAction("clumpbench")
	widgetHandler:RemoveAction("clumpbenchstop")
end
