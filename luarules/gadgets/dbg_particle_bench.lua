local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Particle Benchmark",
		desc = "Deterministic map-wide particle/projectile load generator for benchmarking and profiling the engine particle systems. Spawns CEGs, weapon explosions, in-flight projectiles and beams spread over the map at configurable rates. Non-destructive: zero damage AoE, zero craters, projectiles air-detonate above ground, so back-to-back runs are comparable. Writes a frame-time stats JSON per run.",
		author = "ruwetuin",
		date = "2026-08-15",
		license = "GNU GPL, v2 or later",
		layer = -1999999998,
		enabled = true,
	}
end

-- Usage (chat):
--   /particlebench [preset] [totalFrames] [intensity] [areaFraction] [areaOffsetX] [areaOffsetZ] [startFrame]
--   /particlebench stop
--   /particlebench list
-- All arguments optional. Numeric arguments are positional in the order above;
-- the preset word may appear anywhere. Running the command while a run is
-- active stops it (toggle).
--   preset        mix | heavy | trails | cegs | sweep         (default mix)
--   totalFrames   run length in sim frames, >= 30             (default 1800 = 60s)
--   intensity     rate multiplier applied to all entries      (default 1.0, max 50)
--   areaFraction  fraction of the map used, (0, 1]            (default 1.0)
--   areaOffsetX/Z normalized area origin, [0, 1]              (default 0.0)
--   startFrame    absolute frame to start on, for runs that are reproducible
--                 across game restarts (the command arrives over the network on
--                 a non-deterministic frame; anchoring removes that variance).
--
-- Spawn positions/timings come from a private seeded PRNG, so the synced spawn
-- sequence is identical between runs (when frame-anchored). Note the particle
-- counts a CEG emits can still vary slightly per client: CEG visual randomness
-- uses the unsynced RNG. Use long-enough runs to average that out.
--
-- Beam/lightning entries are spawned via SpawnProjectile with pos+end; if a
-- projectile type turns out not to render this way, remove those entries.

local PACKET_HEADER = "$pb$"
local PACKET_HEADER_LENGTH = string.len(PACKET_HEADER)
local PH_B1 = string.byte(PACKET_HEADER, 1)

local RUN_SEED = 20260815

if gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------
	-- Run configuration and state
	--------------------------------------------------------------------

	local mapSX = Game.mapSizeX
	local mapSZ = Game.mapSizeZ
	local GRAVITY_PER_FRAME = -(Game.gravity / 900) -- elmos/frame^2, negative = down
	local DETONATE_HEIGHT = 30 -- elmos above target ground for scheduled airbursts
	local TTL_HEADROOM = 15 -- frames past scheduled detonation before the engine kills a projectile itself

	local spDeleteProjectile = Spring.DeleteProjectile or Spring.DestroyProjectile
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetProjectilePosition = Spring.GetProjectilePosition
	local spSpawnCEG = Spring.SpawnCEG
	local spSpawnExplosion = Spring.SpawnExplosion
	local spSpawnProjectile = Spring.SpawnProjectile
	local spSetProjectileDamages = Spring.SetProjectileDamages

	local active = false
	local runStartFrame = 0
	local runEndFrame = 0
	local pendingStartFrame = nil
	local presetName = "mix"
	local totalFrames = 1800
	local intensity = 1.0
	local areaFraction = 1.0
	local areaOffsetX = 0.0
	local areaOffsetZ = 0.0

	local originX, originZ, areaX, areaZ = 0, 0, mapSX, mapSZ

	local entries = {} -- resolved entries for the active run
	local detQueue = {} -- [frame] = { {id=projectileID, ex=explParams}, ... }
	local liveProjectiles = 0
	local spawnedCEG, spawnedExpl, spawnedProj, spawnedBeam = 0, 0, 0, 0
	local detonated, missedDetonations = 0, 0

	--------------------------------------------------------------------
	-- Seeded PRNG (Park-Miller; exact in doubles, independent of math.random)
	--------------------------------------------------------------------

	local prngState = 1

	local function initrandom(seed)
		prngState = seed % 2147483647
		if prngState <= 0 then
			prngState = prngState + 2147483646
		end
	end

	local function getrandom()
		prngState = (prngState * 16807) % 2147483647
		return (prngState - 1) / 2147483646
	end

	--------------------------------------------------------------------
	-- Effect presets
	--
	-- rate = spawns per second over the whole area at intensity 1.
	-- ceg entries spawn hmin..hmax elmos above ground (flak bursts high).
	-- proj flight models: "arc" (ballistic parabola from spawnHeight h0..h1,
	-- launched d0..d1 elmos away from the target), "straight" (level flight at
	-- weaponDef speed), "up" (vertical launch, for starburst types).
	--------------------------------------------------------------------

	local function ceg(name, rate, damage, hmin, hmax)
		return { kind = "ceg", name = name, rate = rate, damage = damage or 200, hmin = hmin or 6, hmax = hmax or 12 }
	end

	local function expl(wdName, rate)
		return { kind = "expl", wd = wdName, rate = rate }
	end

	local function arc(wdName, rate, f0, f1, d0, d1, h0, h1)
		return { kind = "proj", flight = "arc", wd = wdName, rate = rate, f0 = f0, f1 = f1, d0 = d0, d1 = d1, h0 = h0, h1 = h1 or h0 }
	end

	local function straight(wdName, rate, f0, f1, h0)
		return { kind = "proj", flight = "straight", wd = wdName, rate = rate, f0 = f0, f1 = f1, h0 = h0 }
	end

	local function up(wdName, rate, f0, f1)
		return { kind = "proj", flight = "up", wd = wdName, rate = rate, f0 = f0, f1 = f1, h0 = 30 }
	end

	local function beam(wdName, rate, d0, d1)
		return { kind = "beam", wd = wdName, rate = rate, d0 = d0, d1 = d1, ttl = 12 }
	end

	-- Battle-realistic weighting: many small hits and muzzle flashes, steady
	-- mid-caliber fire with live trails, sparse artillery, rare nuke-scale.
	local presetMix = {
		-- impact flashes and small explosions
		ceg("plasmahit-small", 40, 80),
		ceg("laserhit-small", 25, 60),
		ceg("barrelshot-medium", 30, 100), -- muzzle flashes
		ceg("flak", 12, 150, 250, 550), -- AA bursts at altitude
		expl("armpw_emg", 25),
		expl("corak_gator_laser", 15),
		-- medium
		expl("armstump_arm_lightcannon", 10),
		expl("corlevlr_corlevlr_weapon", 7),
		expl("armrock_arm_bot_rocket", 7),
		ceg("genericshellexplosion-medium", 8, 300),
		ceg("genericunitexplosion-medium", 2, 400), -- units dying
		-- artillery / large
		expl("armbrtha_lrpc", 1.5),
		expl("corint_lrpc", 1.2),
		ceg("arty-large", 1.2, 800),
		ceg("genericbuildingexplosion-large", 0.4, 900),
		-- huge, occasional
		expl("cortron_cortron_weapon", 1 / 15),
		expl("armsilo_nuclear_missile", 1 / 30),
		-- in-flight projectiles (smoke/fire trails)
		arc("armstump_arm_lightcannon", 12, 50, 90, 350, 900, 25),
		arc("corlevlr_corlevlr_weapon", 8, 50, 90, 350, 900, 25),
		arc("armbrtha_lrpc", 1.5, 100, 160, 1200, 3000, 40),
		arc("armvulc_rflrpc", 2.5, 110, 170, 1500, 3500, 40),
		arc("armthund_armbomb", 4, 45, 70, 60, 250, 450, 650), -- bombs falling
		arc("corshad_corbomb", 3, 45, 70, 60, 250, 450, 650),
		straight("armrock_arm_bot_rocket", 8, 45, 75, 35),
		straight("cormist_cortruck_missile", 7, 60, 90, 45),
		straight("corpyro_flamethrower", 5, 20, 35, 18),
		up("armmerl_armtruck_rocket", 1.5, 100, 150),
		up("corvroc_cortruck_rocket", 1.2, 100, 150),
		-- beams
		beam("armllt_arm_lightlaser", 10, 180, 420),
		beam("corak_gator_laser", 8, 150, 350),
		beam("armzeus_lightning", 5, 150, 320),
	}

	-- Only the expensive stuff: worst-case effect cost per spawn.
	local presetHeavy = {
		expl("armsilo_nuclear_missile", 0.5),
		expl("corsilo_crblmssl", 0.4),
		expl("cortron_cortron_weapon", 1),
		expl("armemp_armemp_weapon", 0.4),
		expl("armvulc_rflrpc", 6),
		expl("corbuzz_rflrpc", 6),
		ceg("newshockwaveblast", 0.5, 4000),
		ceg("t3unitexplosion", 0.4, 4000),
		ceg("genericbuildingexplosion-gigantic", 0.5, 2000),
		ceg("arty-extraheavy", 2, 1500),
		ceg("barrelshot-huge", 6, 500),
		arc("armvulc_rflrpc", 5, 110, 170, 1500, 3500, 40),
		arc("corbuzz_rflrpc", 5, 110, 170, 1500, 3500, 40),
	}

	-- In-flight trail load: many live projectiles, few explosions.
	local presetTrails = {
		ceg("barrelshot-medium", 40, 100),
		arc("armstump_arm_lightcannon", 25, 50, 90, 350, 900, 25),
		arc("corlevlr_corlevlr_weapon", 18, 50, 90, 350, 900, 25),
		arc("armbrtha_lrpc", 5, 100, 160, 1200, 3000, 40),
		arc("armvulc_rflrpc", 8, 110, 170, 1500, 3500, 40),
		arc("corbuzz_rflrpc", 8, 110, 170, 1500, 3500, 40),
		arc("armthund_armbomb", 10, 45, 70, 60, 250, 450, 650),
		arc("corshad_corbomb", 8, 45, 70, 60, 250, 450, 650),
		straight("armrock_arm_bot_rocket", 20, 45, 75, 35),
		straight("cormist_cortruck_missile", 16, 60, 90, 45),
		straight("corpyro_flamethrower", 8, 20, 35, 18),
		up("armmerl_armtruck_rocket", 5, 100, 150),
		up("corvroc_cortruck_rocket", 4, 100, 150),
	}

	-- Uniform cycle through a representative CEG list, pure SpawnCEG cost.
	local cegCycleList = {
		{ "plasmahit-small", 100 },
		{ "plasmahit-medium", 200 },
		{ "plasmahit-huge", 800 },
		{ "laserhit-small", 80 },
		{ "laserhit-medium", 150 },
		{ "barrelshot-medium", 100 },
		{ "barrelshot-huge", 400 },
		{ "flak", 150 },
		{ "dirt", 100 },
		{ "genericshellexplosion-small", 150 },
		{ "genericshellexplosion-medium", 350 },
		{ "genericshellexplosion-large", 900 },
		{ "genericshellexplosion-huge", 2500 },
		{ "genericunitexplosion-medium", 400 },
		{ "genericunitexplosion-large", 900 },
		{ "genericbuildingexplosion-medium", 500 },
		{ "genericbuildingexplosion-large", 1000 },
		{ "arty-medium", 400 },
		{ "arty-large", 900 },
		{ "arty-huge", 1800 },
		{ "heatray-large", 700 },
		{ "expldgun", 500 },
		{ "fusexpl", 2000 },
		{ "afusexpl", 3000 },
		{ "t3unitexplosion", 3500 },
		{ "juno-explo", 800 },
		{ "newnuketac", 4000 },
		{ "newnuke", 8000 },
	}

	local presets = {
		mix = presetMix,
		heavy = presetHeavy,
		trails = presetTrails,
		cegs = { { kind = "cegcycle", rate = 25, list = cegCycleList } },
		sweep = { { kind = "sweep", rate = 20 } },
	}

	--------------------------------------------------------------------
	-- Entry resolution
	--------------------------------------------------------------------

	local function defaultDamage(def)
		local damages = def.damages
		return (damages and (damages[0] or damages[1])) or 100
	end

	-- Zero-footprint explosion: real weaponDef + damage magnitude (drives CEG
	-- visual scaling), but no damage AoE, no crater, no ground damage.
	local function makeExplParams(wdID, damage)
		return {
			weaponDef = wdID,
			damages = damage,
			damageAreaOfEffect = 0,
			craterAreaOfEffect = 0,
			damageGround = false,
			ignoreOwner = true,
		}
	end

	local function resolveEntries()
		entries = {}
		local skipped = {}
		for _, e in ipairs(presets[presetName]) do
			local ok = true
			if e.wd then
				local def = WeaponDefNames[e.wd]
				if def then
					e.wdID = def.id
					e.damage = defaultDamage(def)
					e.speed = def.projectilespeed or 6
					e.explParams = makeExplParams(e.wdID, e.damage)
				else
					skipped[#skipped + 1] = e.wd
					ok = false
				end
			end
			if e.kind == "sweep" then
				local ids = {}
				for wdID, def in pairs(WeaponDefs) do
					if def.type ~= "Shield" then
						ids[#ids + 1] = wdID
					end
				end
				table.sort(ids)
				e.ids = ids
				e.params = {} -- explParams cache, filled lazily
			end
			if ok then
				e.label = e.name or e.wd or e.kind
				e.acc = 0
				e.count = 0
				e.idx = 0
				entries[#entries + 1] = e
			end
		end
		if #skipped > 0 then
			Spring.Echo("[particlebench] skipping unknown weapondefs: " .. table.concat(skipped, " "))
		end
	end

	--------------------------------------------------------------------
	-- Spawning
	--------------------------------------------------------------------

	local function clampX(x)
		return math.max(16, math.min(mapSX - 16, x))
	end

	local function clampZ(z)
		return math.max(16, math.min(mapSZ - 16, z))
	end

	local function groundY(x, z)
		return math.max(spGetGroundHeight(x, z), 0)
	end

	local function rndPos()
		return originX + getrandom() * areaX, originZ + getrandom() * areaZ
	end

	local function spawnCEGEntry(e)
		local x, z = rndPos()
		local y = groundY(x, z) + e.hmin + getrandom() * (e.hmax - e.hmin)
		spSpawnCEG(e.name, x, y, z, 0, 1, 0, 0, e.damage)
		spawnedCEG = spawnedCEG + 1
	end

	local function spawnExplEntry(e)
		local x, z = rndPos()
		local y = groundY(x, z) + 8
		spSpawnExplosion(x, y, z, 0, 1, 0, e.explParams)
		spawnedExpl = spawnedExpl + 1
	end

	-- Neutralize a live projectile: no crater, no impulse, no damage AoE, so an
	-- accidental terrain/unit collision before the scheduled airburst is
	-- cosmetic-only. (Damage values themselves can't be zeroed through this
	-- API, so a direct unit hit still hurts that one unit — run on empty maps.)
	local function neutralizeProjectile(projectileID)
		spSetProjectileDamages(projectileID, {
			craterMult = 0,
			impulseFactor = 0,
			impulseBoost = 0,
			damageAreaOfEffect = 0,
		})
	end

	local function scheduleDetonation(projectileID, e, frame)
		neutralizeProjectile(projectileID)
		local list = detQueue[frame]
		if not list then
			list = {}
			detQueue[frame] = list
		end
		list[#list + 1] = { id = projectileID, ex = e.explParams }
		liveProjectiles = liveProjectiles + 1
	end

	local function spawnProjEntry(e, frame)
		local flightFrames = math.floor(e.f0 + getrandom() * (e.f1 - e.f0))
		local params, projectileID
		if e.flight == "arc" then
			local tx, tz = rndPos()
			local targetGround = groundY(tx, tz)
			local angle = getrandom() * 2 * math.pi
			local dist = e.d0 + getrandom() * (e.d1 - e.d0)
			local sx = clampX(tx + math.cos(angle) * dist)
			local sz = clampZ(tz + math.sin(angle) * dist)
			local sy = groundY(sx, sz) + e.h0 + getrandom() * (e.h1 - e.h0)
			local g = GRAVITY_PER_FRAME
			local detY = targetGround + DETONATE_HEIGHT
			params = {
				pos = { sx, sy, sz },
				speed = {
					(tx - sx) / flightFrames,
					(detY - sy - 0.5 * g * flightFrames * flightFrames) / flightFrames,
					(tz - sz) / flightFrames,
				},
				gravity = g,
				ttl = flightFrames + TTL_HEADROOM,
			}
		elseif e.flight == "straight" then
			local sx, sz = rndPos()
			local sy = groundY(sx, sz) + e.h0
			local angle = getrandom() * 2 * math.pi
			params = {
				pos = { sx, sy, sz },
				speed = { math.cos(angle) * e.speed, 0, math.sin(angle) * e.speed },
				ttl = flightFrames + TTL_HEADROOM,
			}
		else -- "up": vertical launch, for starburst-type weapons
			local sx, sz = rndPos()
			local sy = groundY(sx, sz) + e.h0
			params = {
				pos = { sx, sy, sz },
				speed = { (getrandom() - 0.5) * 1.5, e.speed, (getrandom() - 0.5) * 1.5 },
				upTime = flightFrames,
				ttl = flightFrames + TTL_HEADROOM,
			}
		end
		projectileID = spSpawnProjectile(e.wdID, params)
		if projectileID then
			scheduleDetonation(projectileID, e, frame + flightFrames)
			spawnedProj = spawnedProj + 1
		end
	end

	local function spawnBeamEntry(e)
		local sx, sz = rndPos()
		local sy = groundY(sx, sz) + 30 + getrandom() * 40
		local angle = getrandom() * 2 * math.pi
		local len = e.d0 + getrandom() * (e.d1 - e.d0)
		local ex = clampX(sx + math.cos(angle) * len)
		local ez = clampZ(sz + math.sin(angle) * len)
		local ey = groundY(ex, ez) + 10
		spSpawnProjectile(e.wdID, {
			pos = { sx, sy, sz },
			["end"] = { ex, ey, ez },
			ttl = e.ttl,
		})
		-- beams don't collide when spawned this way; fire the impact visual directly
		spSpawnExplosion(ex, ey, ez, 0, 1, 0, e.explParams)
		spawnedBeam = spawnedBeam + 1
	end

	local function spawnCegCycleEntry(e)
		e.idx = (e.idx % #e.list) + 1
		local item = e.list[e.idx]
		local x, z = rndPos()
		local y = groundY(x, z) + 8
		spSpawnCEG(item[1], x, y, z, 0, 1, 0, 0, item[2])
		spawnedCEG = spawnedCEG + 1
	end

	local function spawnSweepEntry(e)
		e.idx = (e.idx % #e.ids) + 1
		local wdID = e.ids[e.idx]
		local params = e.params[wdID]
		if not params then
			params = makeExplParams(wdID, defaultDamage(WeaponDefs[wdID]))
			e.params[wdID] = params
		end
		local x, z = rndPos()
		local y = groundY(x, z) + 8
		spSpawnExplosion(x, y, z, 0, 1, 0, params)
		spawnedExpl = spawnedExpl + 1
	end

	local spawnByKind = {
		ceg = spawnCEGEntry,
		expl = spawnExplEntry,
		proj = spawnProjEntry,
		beam = spawnBeamEntry,
		cegcycle = spawnCegCycleEntry,
		sweep = spawnSweepEntry,
	}

	--------------------------------------------------------------------
	-- Scheduled airbursts
	--------------------------------------------------------------------

	local function processDetonations(frame)
		local list = detQueue[frame]
		if not list then
			return
		end
		for i = 1, #list do
			local d = list[i]
			local px, py, pz = spGetProjectilePosition(d.id)
			if px then
				spSpawnExplosion(px, py, pz, 0, 1, 0, d.ex)
				spDeleteProjectile(d.id)
				detonated = detonated + 1
			else
				-- already gone: collided early (harmless, it was neutralized)
				-- or engine ttl expired first
				missedDetonations = missedDetonations + 1
			end
			liveProjectiles = liveProjectiles - 1
		end
		detQueue[frame] = nil
	end

	local function clearPendingProjectiles()
		for _, list in pairs(detQueue) do
			for i = 1, #list do
				if spGetProjectilePosition(list[i].id) then
					spDeleteProjectile(list[i].id)
				end
			end
		end
		detQueue = {}
		liveProjectiles = 0
	end

	--------------------------------------------------------------------
	-- Run lifecycle
	--------------------------------------------------------------------

	local function beginRun(startFrame)
		runStartFrame = startFrame
		runEndFrame = runStartFrame + totalFrames
		pendingStartFrame = nil

		originX = mapSX * areaOffsetX
		originZ = mapSZ * areaOffsetZ
		areaX = mapSX * areaFraction
		areaZ = mapSZ * areaFraction

		initrandom(RUN_SEED)
		resolveEntries()
		detQueue = {}
		liveProjectiles = 0
		spawnedCEG, spawnedExpl, spawnedProj, spawnedBeam = 0, 0, 0, 0
		detonated, missedDetonations = 0, 0

		Spring.Echo(
			string.format(
				"[particlebench] starting: preset=%s startframe=%d endframe=%d totalframes=%d intensity=%.2f area=%.2f offset=%.2f,%.2f entries=%d",
				presetName,
				runStartFrame,
				runEndFrame,
				totalFrames,
				intensity,
				areaFraction,
				areaOffsetX,
				areaOffsetZ,
				#entries
			)
		)
		SendToUnsynced(
			"pbench_begin",
			presetName,
			totalFrames,
			runStartFrame,
			runEndFrame,
			intensity,
			areaFraction,
			areaOffsetX,
			areaOffsetZ,
			RUN_SEED
		)
		active = true
	end

	local function endRun()
		active = false
		clearPendingProjectiles()

		local perEntry = {}
		for _, e in ipairs(entries) do
			perEntry[#perEntry + 1] = string.format("%s=%d", e.label, e.count)
		end
		Spring.Echo(
			string.format(
				"[particlebench] ended on frame %d: ceg=%d expl=%d proj=%d beam=%d airbursts=%d missed=%d",
				Spring.GetGameFrame(),
				spawnedCEG,
				spawnedExpl,
				spawnedProj,
				spawnedBeam,
				detonated,
				missedDetonations
			)
		)
		Spring.Echo("[particlebench] per-entry: " .. table.concat(perEntry, " "))
		SendToUnsynced("pbench_end", spawnedCEG, spawnedExpl, spawnedProj, spawnedBeam, detonated, missedDetonations)
	end

	-- See the usage comment at the top of the file for argument meanings.
	local function armRun(words)
		presetName = "mix"
		totalFrames = 1800
		intensity = 1.0
		areaFraction = 1.0
		areaOffsetX = 0.0
		areaOffsetZ = 0.0

		local nums = {}
		for i = 2, #words do
			local w = words[i]
			if presets[w] then
				presetName = w
			else
				local n = tonumber(w)
				if n then
					nums[#nums + 1] = n
				end
			end
		end
		if nums[1] then
			totalFrames = math.max(30, math.floor(nums[1]))
		end
		if nums[2] and nums[2] > 0 and nums[2] <= 50 then
			intensity = nums[2]
		end
		if nums[3] and nums[3] > 0 and nums[3] <= 1 then
			areaFraction = nums[3]
		end
		if nums[4] and nums[4] >= 0 and nums[4] <= 1 then
			areaOffsetX = nums[4]
		end
		if nums[5] and nums[5] >= 0 and nums[5] <= 1 then
			areaOffsetZ = nums[5]
		end
		if areaOffsetX + areaFraction > 1 then
			areaOffsetX = 1 - areaFraction
		end
		if areaOffsetZ + areaFraction > 1 then
			areaOffsetZ = 1 - areaFraction
		end

		local now = Spring.GetGameFrame()
		if not nums[6] then
			beginRun(now)
			return
		end

		local startFrame = math.floor(nums[6])
		if startFrame <= now then
			Spring.Echo(
				string.format(
					"[particlebench] ERROR: startFrame must be a frame after the current one (%d); got %d",
					now,
					startFrame
				)
			)
			return
		end
		pendingStartFrame = startFrame
		Spring.Echo(string.format("[particlebench] armed on frame %d, starting on frame %d", now, startFrame))
	end

	local function toggleRun(words)
		if active then
			endRun()
		elseif pendingStartFrame then
			Spring.Echo(
				string.format("[particlebench] cancelling pending run (was to start on frame %d)", pendingStartFrame)
			)
			pendingStartFrame = nil
		else
			armRun(words)
		end
	end

	--------------------------------------------------------------------
	-- Main tick
	--------------------------------------------------------------------

	function gadget:GameFrame(n)
		if pendingStartFrame and n == pendingStartFrame then
			beginRun(pendingStartFrame)
		end
		if not active then
			return
		end

		for _, e in ipairs(entries) do
			e.acc = e.acc + e.rate * intensity / 30
			while e.acc >= 1 do
				e.acc = e.acc - 1
				spawnByKind[e.kind](e, n)
				e.count = e.count + 1
			end
		end

		processDetonations(n)

		if n % 30 == 0 then
			SendToUnsynced("pbench_live", liveProjectiles)
		end

		if n >= runEndFrame then
			endRun()
		end
	end

	function gadget:Shutdown()
		if active then
			clearPendingProjectiles()
		end
	end

	--------------------------------------------------------------------
	-- Chat entry point (relayed from unsynced via Spring.SendLuaRulesMsg)
	--------------------------------------------------------------------

	-- Permission gate (mirrors game_ceg_preview / cmd_dev_helpers, devhelpers only)
	local function isAuthorized(playerID)
		local playername = Spring.GetPlayerInfo(playerID)
		local accountID = BAR.Utilities and BAR.Utilities.GetAccountID and BAR.Utilities.GetAccountID(playerID)
		-- accountID of -1 means offline/singleplayer -- treat as no valid account
		if accountID and accountID <= 0 then
			accountID = nil
		end

		-- devhelpers permission bypasses cheat requirement (authorized users in any game)
		if
			(
				_G
				and _G.permissions
				and _G.permissions.devhelpers
				and (
					accountID and _G.permissions.devhelpers[accountID]
					or (playername and _G.permissions.devhelpers[playername])
				)
			)
			or (
				SYNCED
				and SYNCED.permissions
				and SYNCED.permissions.devhelpers
				and (
					accountID and SYNCED.permissions.devhelpers[accountID]
					or (playername and SYNCED.permissions.devhelpers[playername])
				)
			)
		then
			return true
		end
		-- Fall back to cheat requirement for everyone else (covers singleplayer testing)
		if Spring.IsCheatingEnabled() then
			return true
		end
		return false
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if
			#msg < PACKET_HEADER_LENGTH
			or string.byte(msg, 1) ~= PH_B1
			or string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER
		then
			return
		end
		msg = string.sub(msg, PACKET_HEADER_LENGTH)
		local words = {}
		for word in msg:gmatch("[%-_%w%./]+") do
			table.insert(words, word)
		end
		if words[1] ~= "particlebench" then
			return
		end
		if not isAuthorized(playerID) then
			return
		end
		if words[2] == "stop" then
			if active then
				endRun()
			elseif pendingStartFrame then
				pendingStartFrame = nil
				Spring.Echo("[particlebench] cancelled pending run")
			end
			return
		end
		if words[2] == "list" then
			local names = {}
			for name, list in pairs(presets) do
				names[#names + 1] = string.format("%s(%d entries)", name, #list)
			end
			table.sort(names)
			Spring.Echo("[particlebench] presets: " .. table.concat(names, " "))
			return
		end
		toggleRun(words)
	end
else -- UNSYNCED
	--------------------------------------------------------------------
	-- HUD + frame-time capture
	--------------------------------------------------------------------

	local WARMUP_FRAMES = 30 -- skip the first second after run start

	local vsx, vsy = Spring.GetViewGeometry()
	local uiScale = vsy / 1080

	local hudActive = false
	local runPreset = "mix"
	local runTotalFrames = 0
	local runStartFrame = nil
	local runEndFrame = nil
	local runIntensity = 1
	local runAreaFraction = 1
	local runAreaOffsetX = 0
	local runAreaOffsetZ = 0
	local runSeed = 0
	local liveProjectiles = 0

	local samples = {}
	local lastTimer = nil
	local bucketSums, bucketCounts = {}, {}
	local cumulativeMs = 0

	function gadget:ViewResize()
		vsx, vsy = Spring.GetViewGeometry()
		uiScale = vsy / 1080
	end

	local function onBegin(_, preset, totalFrames, startFrame, endFrame, intensity, areaFraction, offsetX, offsetZ, seed)
		hudActive = true
		runPreset = tostring(preset)
		runTotalFrames = tonumber(totalFrames) or 0
		runStartFrame = tonumber(startFrame) or Spring.GetGameFrame()
		runEndFrame = tonumber(endFrame) or (runStartFrame + runTotalFrames)
		runIntensity = tonumber(intensity) or 1
		runAreaFraction = tonumber(areaFraction) or 1
		runAreaOffsetX = tonumber(offsetX) or 0
		runAreaOffsetZ = tonumber(offsetZ) or 0
		runSeed = tonumber(seed) or 0
		liveProjectiles = 0
		samples = {}
		lastTimer = nil
		bucketSums, bucketCounts = {}, {}
		cumulativeMs = 0
	end

	local function onLive(_, count)
		liveProjectiles = tonumber(count) or 0
	end

	function gadget:Update()
		if not hudActive then
			return
		end
		local now = Spring.GetTimer()
		local gameFrame = Spring.GetGameFrame()
		local _, _, paused = Spring.GetGameSpeed()
		if paused or gameFrame <= runStartFrame + WARMUP_FRAMES or gameFrame > runEndFrame then
			lastTimer = now
			return
		end
		if lastTimer then
			local ms = Spring.DiffTimers(now, lastTimer) * 1000
			samples[#samples + 1] = ms
			cumulativeMs = cumulativeMs + ms
			local bucket = math.floor(cumulativeMs / 1000) + 1
			bucketSums[bucket] = (bucketSums[bucket] or 0) + ms
			bucketCounts[bucket] = (bucketCounts[bucket] or 0) + 1
		end
		lastTimer = now
	end

	local function percentile(sorted, p)
		local n = #sorted
		if n == 0 then
			return 0
		end
		return sorted[math.max(1, math.min(n, math.ceil(p * n)))]
	end

	local function onEnd(_, cegs, expls, projs, beams, airbursts, missed)
		hudActive = false
		local n = #samples
		if n == 0 then
			Spring.Echo("[particlebench] no frame-time samples collected (run too short?)")
			return
		end

		local sum = 0
		local sorted = {}
		for i = 1, n do
			sum = sum + samples[i]
			sorted[i] = samples[i]
		end
		table.sort(sorted)
		local avgMs = sum / n

		local series = {}
		for i = 1, #bucketSums do
			if bucketCounts[i] and bucketCounts[i] > 0 then
				series[i] = math.floor((bucketSums[i] / bucketCounts[i]) * 1000 + 0.5) / 1000
			end
		end

		local stats = {
			gadget = "particlebench",
			engine = Engine and (Engine.versionFull or Engine.version) or "unknown",
			game = Game and Game.gameName or nil,
			map = Game and Game.mapName or nil,
			preset = runPreset,
			totalFrames = runTotalFrames,
			startFrame = runStartFrame,
			endFrame = runEndFrame,
			intensity = runIntensity,
			areaFraction = runAreaFraction,
			areaOffsetX = runAreaOffsetX,
			areaOffsetZ = runAreaOffsetZ,
			seed = runSeed,
			spawned = {
				ceg = tonumber(cegs) or 0,
				explosion = tonumber(expls) or 0,
				projectile = tonumber(projs) or 0,
				beam = tonumber(beams) or 0,
				airbursts = tonumber(airbursts) or 0,
				missedDetonations = tonumber(missed) or 0,
			},
			frameTimes = {
				samples = n,
				avgMs = avgMs,
				p50Ms = percentile(sorted, 0.50),
				p90Ms = percentile(sorted, 0.90),
				p99Ms = percentile(sorted, 0.99),
				maxMs = sorted[n],
				avgFps = 1000 / avgMs,
				p1LowFps = 1000 / math.max(percentile(sorted, 0.99), 0.001),
			},
			perSecondAvgMs = series,
		}

		local path = string.format("particlebench_%s_f%d.json", runPreset, runStartFrame or 0)
		local f, err = io.open(path, "w")
		if f then
			f:write(Json.encode(stats))
			f:close()
		else
			Spring.Echo("[particlebench] failed to write " .. tostring(path) .. ": " .. tostring(err))
		end

		Spring.Echo(
			string.format(
				"[particlebench] frametimes over %d samples: avg=%.2fms (%.1f fps) p50=%.2f p90=%.2f p99=%.2f max=%.2f -> %s",
				n,
				stats.frameTimes.avgMs,
				stats.frameTimes.avgFps,
				stats.frameTimes.p50Ms,
				stats.frameTimes.p90Ms,
				stats.frameTimes.p99Ms,
				stats.frameTimes.maxMs,
				path
			)
		)
	end

	function gadget:DrawScreen()
		if not hudActive then
			return
		end
		local gameFrame = Spring.GetGameFrame()
		local runFrame = runStartFrame and math.max(0, gameFrame - runStartFrame) or 0
		gl.Color(1, 1, 1, 1)
		gl.Text(
			string.format(
				"Particlebench [%s x%.1f]  frame %d / %d  live proj %d  fps %d",
				runPreset,
				runIntensity,
				runFrame,
				runTotalFrames,
				liveProjectiles,
				Spring.GetFPS()
			),
			600 * uiScale,
			640 * uiScale,
			16 * uiScale
		)
	end

	--------------------------------------------------------------------
	-- Chat action + gadget lifecycle
	--------------------------------------------------------------------

	local function particlebench(_, line, words, playerID)
		if playerID ~= Spring.GetLocalPlayerID() then
			return
		end
		local msg = PACKET_HEADER .. ":particlebench"
		for i = 1, 7 do
			if words[i] then
				msg = msg .. " " .. tostring(words[i])
			end
		end
		Spring.SendLuaRulesMsg(msg)
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction("particlebench", particlebench, "")
		gadgetHandler:AddChatAction("pbench", particlebench, "")
		gadgetHandler:AddSyncAction("pbench_begin", onBegin)
		gadgetHandler:AddSyncAction("pbench_live", onLive)
		gadgetHandler:AddSyncAction("pbench_end", onEnd)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("particlebench")
		gadgetHandler:RemoveChatAction("pbench")
		gadgetHandler:RemoveSyncAction("pbench_begin")
		gadgetHandler:RemoveSyncAction("pbench_live")
		gadgetHandler:RemoveSyncAction("pbench_end")
	end
end
