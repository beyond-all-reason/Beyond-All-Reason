--------------------------------------------------------------------------------
-- VOLCANO PYROCLASTIC ERUPTIONS —
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Volcano Pyroclastic Eruptions",
		desc = "Cinematic volcano eruption event for BAR",
		author = "Steel",
		date = "Dec 2025",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------------------
	-- Shortcuts
	--------------------------------------------------------------------------------
	local spCreateUnit = SpringSynced.CreateUnit
	local spDestroyUnit = SpringSynced.DestroyUnit
	local spGiveOrderToUnit = SpringSynced.GiveOrderToUnit
	local spSpawnCEG = SpringSynced.SpawnCEG
	local spGetGroundHeight = SpringShared.GetGroundHeight
	local spSetUnitCloak = SpringSynced.SetUnitCloak
	local spMoveCtrlEnable = SpringSynced.MoveCtrl.Enable
	local spMoveCtrlSetPosition = SpringSynced.MoveCtrl.SetPosition

	local GameFrame = SpringShared.GetGameFrame
	local SendToUnsynced = SendToUnsynced

	local CMD_ATTACK = CMD.ATTACK
	local CMD_FIRE_STATE = CMD.FIRE_STATE

	--------------------------------------------------------------------------------
	-- Volcano center
	--------------------------------------------------------------------------------
	local VX = Game.mapSizeX * 0.5
	local VZ = Game.mapSizeZ * 0.5

	local VRIM = 600
	local LAUNCHER_Y = VRIM - 300

	--------------------------------------------------------------------------------
	-- Timing control
	--------------------------------------------------------------------------------
	local VOLCANO_EJECT_DELAY_FRAMES = 86 -- << EDIT THIS ONLY

	local FIRST_MIN = 8 * 60 * 30 -- 8 minutes
	local FIRST_MAX = 12 * 60 * 30 -- 12 minutes
	local COOLDOWN_MIN = 8 * 60 * 30 -- 8 minutes
	local COOLDOWN_MAX = 12 * 60 * 30 -- 12 minutes
	local BUILDUP = 20 * 30

	--------------------------------------------------------------------------------
	-- Runtime / map control
	--------------------------------------------------------------------------------
	local REQUIRED_MAP = "forge v2.3"
	local volcanoActive = true

	local function Normalize(s)
		s = tostring(s or "")
		s = string.lower(s)
		s = s:gsub(";", "")
		s = s:gsub("%s+", " ")
		s = s:gsub("^%s+", ""):gsub("%s+$", "")
		return s
	end

	local function IsVolcanoEnabled()
		local modOpts = (SpringShared.GetModOptions and SpringShared.GetModOptions()) or {}
		local v = modOpts.forge_volcano
		return v == nil or v == true or v == 1 or v == "1" or v == "true"
	end

	--------------------------------------------------------------------------------
	-- State
	--------------------------------------------------------------------------------
	local nextErupt = nil
	local delayed = {}
	local pendingDestroy = {}
	local firstFireballFrame = nil
	local ejectScheduled = false
	local buildupSoundPlayed = false

	local function R(a, b)
		return a + math.random() * (b - a)
	end

	--------------------------------------------------------------------------------
	-- DelayCall helper
	--------------------------------------------------------------------------------
	local function DelayCall(func, args, delay)
		local f = GameFrame() + delay
		delayed[f] = delayed[f] or {}
		delayed[f][#delayed[f] + 1] = { func, args }
	end

	--------------------------------------------------------------------------------
	-- Volcano Controls "/luarules volcano" to pause/resume volcano explosion
	--------------------------------------------------------------------------------

	local function ResetVolcanoState()
		nextErupt = GameFrame() + R(COOLDOWN_MIN, COOLDOWN_MAX)
		delayed = {}
		pendingDestroy = {}
		firstFireballFrame = nil
		ejectScheduled = false
		buildupSoundPlayed = false
	end

	function gadget:Initialize()
		if Normalize(Game.mapName) ~= REQUIRED_MAP then
			gadgetHandler:RemoveGadget(self)
			return
		end

		volcanoActive = IsVolcanoEnabled()
		if not volcanoActive then
			ResetVolcanoState()
		end

		gadgetHandler:AddChatAction("volcano", function(cmd, line, words, playerID)
			local accountID = Utilities.GetAccountID(playerID)
			local authorized = _G.permissions.volcano[accountID]

			if not (authorized or SpringShared.IsCheatingEnabled()) then
				SpringShared.Echo("[Volcano] Unauthorized command.")
				return
			end

			volcanoActive = not volcanoActive
			if volcanoActive then
				nextErupt = GameFrame() + R(COOLDOWN_MIN, COOLDOWN_MAX)
				SpringShared.Echo("[Volcano] Volcano system resumed.")
			else
				ResetVolcanoState()
				SpringShared.Echo("[Volcano] Volcano system paused.")
			end
		end)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("volcano")
	end

	--------------------------------------------------------------------------------
	-- Ash helpers
	--------------------------------------------------------------------------------
	local function spawnAshBuild()
		local x = VX + math.random(-160, 160)
		local z = VZ + math.random(-160, 160)
		spSpawnCEG("volcano_ash_build", x, spGetGroundHeight(x, z) + VRIM, z)
	end

	local function spawnAshBig()
		local x = VX + math.random(-260, 260)
		local z = VZ + math.random(-260, 260)
		spSpawnCEG("volcano_ash_big", x, spGetGroundHeight(x, z) + VRIM + 50, z)
	end

	local function spawnAshSmall()
		local x = VX + math.random(-320, 320)
		local z = VZ + math.random(-320, 320)
		spSpawnCEG("volcano_ash_small", x, spGetGroundHeight(x, z) + VRIM, z)
	end

	--------------------------------------------------------------------------------
	-- FIRE HELPERS
	--------------------------------------------------------------------------------
	local FIRE_CEG = "volcano_fire-area"

	local FIRE_RIM_RADIUS = 160 * 1.20
	local VRIM_FIRE_HEIGHT = VRIM

	local function spawnFireRimCEG()
		local a = math.random() * math.pi * 2
		local x = VX + math.cos(a) * FIRE_RIM_RADIUS
		local z = VZ + math.sin(a) * FIRE_RIM_RADIUS
		local y = spGetGroundHeight(VX, VZ) + VRIM_FIRE_HEIGHT
		spSpawnCEG(FIRE_CEG, x, y, z)
	end

	local function spawnFireMouthCEG()
		local y = spGetGroundHeight(VX, VZ) + VRIM
		spSpawnCEG(FIRE_CEG, VX + math.random(-30, 30), y, VZ + math.random(-30, 30))
	end

	local FIRE_OUTER_RADIUS_MIN = 220
	local FIRE_OUTER_RADIUS_MAX = 900

	local function spawnFireSlopeCEG()
		local a = math.random() * math.pi * 2
		local d = FIRE_OUTER_RADIUS_MIN + math.random() * (FIRE_OUTER_RADIUS_MAX - FIRE_OUTER_RADIUS_MIN)

		local x = VX + math.cos(a) * d
		local z = VZ + math.sin(a) * d
		local y = spGetGroundHeight(x, z) + 14

		spSpawnCEG(FIRE_CEG, x, y, z)
	end

	--------------------------------------------------------------------------------
	-- Fireball launcher
	--------------------------------------------------------------------------------
	local function launchFireball()
		if not firstFireballFrame then
			firstFireballFrame = GameFrame()
			ejectScheduled = false
		end

		local uid = spCreateUnit("volcano_projectile_unit", VX, LAUNCHER_Y, VZ, 0, SpringShared.GetGaiaTeamID())
		if not uid then
			return
		end

		spSetUnitCloak(uid, true, 100000)
		spMoveCtrlEnable(uid)
		spMoveCtrlSetPosition(uid, VX, LAUNCHER_Y, VZ)
		spGiveOrderToUnit(uid, CMD_FIRE_STATE, { 2 }, {})

		local a = math.random() * math.pi * 2
		local d = 900 + math.random(900)
		spGiveOrderToUnit(uid, CMD_ATTACK, { VX + math.cos(a) * d, spGetGroundHeight(VX, VZ) + 20, VZ + math.sin(a) * d }, {})

		pendingDestroy[uid] = GameFrame() + 90
	end

	--------------------------------------------------------------------------------
	-- Main loop
	--------------------------------------------------------------------------------
	function gadget:GameFrame(f)
		if not volcanoActive then
			return
		end

		if delayed[f] then
			for _, d in ipairs(delayed[f]) do
				local fn, args = d[1], d[2]
				if args then
					fn(unpack(args))
				else
					fn()
				end
			end
			delayed[f] = nil
		end

		for uid, kill in pairs(pendingDestroy) do
			if f >= kill then
				spDestroyUnit(uid, false, true)
				pendingDestroy[uid] = nil
			end
		end

		if not nextErupt then
			nextErupt = f + R(FIRST_MIN, FIRST_MAX)
			return
		end

		local remain = nextErupt - f

		if remain > 0 and remain <= BUILDUP then
			if f % 4 == 0 then
				spawnAshBuild()
			end
			if math.random() < 0.02 then
				spawnFireRimCEG()
			end
			if math.random() < 0.03 then
				spawnFireSlopeCEG()
			end

			if not buildupSoundPlayed then
				SendToUnsynced("volcano_buildup_rumble")
				SendToUnsynced("quake_warning", "SEISMIC ACTIVITY DETECTED")
				buildupSoundPlayed = true
			end
			return
		end

		if f >= nextErupt then
			buildupSoundPlayed = false

			for b = 1, 3 do
				DelayCall(function()
					for i = 1, math.random(3, 5) do
						spawnFireRimCEG()
					end
				end, nil, b * (3 * 30))
			end

			math.random()
			local n = math.random(5, 11) -- number of fireballs
			local step = math.max(1, math.floor(60 / n))
			local start = 30 + math.random(0, 4)

			for i = 1, n do
				DelayCall(launchFireball, nil, start + (i - 1) * step + math.random(0, 4))
			end

			for i = 1, math.random(10, 16) do
				DelayCall(spawnFireMouthCEG, nil, math.random(0, 150))
			end

			for i = 1, math.random(12, 18) do
				DelayCall(spawnFireSlopeCEG, nil, math.random(0, 180))
			end

			DelayCall(function()
				for i = 1, 28 do
					spawnAshBig()
				end
			end, nil, start)

			for i = 1, 18 do
				spawnAshSmall()
			end

			nextErupt = f + R(COOLDOWN_MIN, COOLDOWN_MAX)
		end

		------------------------------------------------------------------
		-- EJECT PLUME + LAVA SPLASHES + SHOCKWAVE
		------------------------------------------------------------------
		if firstFireballFrame and not ejectScheduled then
			if f >= firstFireballFrame + VOLCANO_EJECT_DELAY_FRAMES then
				ejectScheduled = true
				firstFireballFrame = nil

				SendToUnsynced("volcano_eject_sound")

				local groundY = spGetGroundHeight(VX, VZ)
				local baseY = groundY + VRIM

				-- Eject plume (unchanged)
				for i = 1, math.random(3, 5) do
					DelayCall(function()
						spSpawnCEG("volcano_eject", VX + math.random(-40, 40), baseY + math.random(180, 420), VZ + math.random(-40, 40))
					end, nil, math.random(0, 25))
				end

				-- Lava splashes (nukexl)
				local splashBaseY = baseY + 34
				local splashCount = math.random(2, 3)

				for i = 1, splashCount do
					DelayCall(function()
						spSpawnCEG("volcano_lava_splash_nukexl", VX + math.random(-45, 45), splashBaseY, VZ + math.random(-45, 45))
					end, nil, (i - 1) * math.random(2, 4))
				end

				-- Shockwave (single, anchored)
				spSpawnCEG("shockwaveceg", VX, baseY, VZ)

				-- Additional fire effects (same height as shockwave)
				spSpawnCEG("volcano1_flames", VX, baseY, VZ)
				spSpawnCEG("volcano_rising_fireball_spawner", VX, baseY, VZ)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Projectile visuals
	--------------------------------------------------------------------------------
	local activeFireballs = {}

	function gadget:ProjectileCreated(id, ownerID, weaponDefID)
		local wd = WeaponDefs[weaponDefID]
		if wd and wd.name == "Volcano Fireball" then
			activeFireballs[id] = true
		end
	end

	function gadget:ProjectileDestroyed(id)
		activeFireballs[id] = nil
	end

	function gadget:ProjectileMoved(id, x, y, z)
		if activeFireballs[id] then
			spSpawnCEG(FIRE_CEG, x, y, z)
		end
	end

--------------------------------------------------------------------------------
-- UNSYNCED (SOUNDS + WARNING UI)
--------------------------------------------------------------------------------
else
	local spPlaySoundFile = SpringUnsynced.PlaySoundFile
	local spGetGameFrame = SpringShared.GetGameFrame
	local spGetViewGeometry = SpringUnsynced.GetViewGeometry

	local glPushMatrix = gl.PushMatrix
	local glPopMatrix = gl.PopMatrix
	local glTranslate = gl.Translate
	local glText = gl.Text

	local WARNING_FRAMES = 90 -- ~3 seconds at 30 fps

	local warningText, warningEnd

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("volcano_buildup_rumble", function()
			spPlaySoundFile("sounds/atmos/lavarumble2.wav", 1.0, "ui")
		end)

		gadgetHandler:AddSyncAction("volcano_eject_sound", function()
			spPlaySoundFile("sounds/atmos-local/lavaburst2.wav", 1.5, "ui")
			spPlaySoundFile("sounds/atmos/lavarumble3.wav", 0.9, "ui")
			spPlaySoundFile("sounds/weapons/xplolrg1.wav", 0.55, "ui")
		end)

		gadgetHandler:AddSyncAction("quake_warning", function(_, msg)
			warningText = msg or "SEISMIC ACTIVITY DETECTED"
			warningEnd = spGetGameFrame() + WARNING_FRAMES

			SpringShared.Echo("[Volcano] Warning: " .. warningText)
			spPlaySoundFile("sounds/voice-soundeffects/LavaAlert.wav", 1.0, "ui")
		end)
	end

	-- Big warning text at top of screen during WARNING_FRAMES
	function gadget:DrawScreen()
		local frame = spGetGameFrame()
		if warningText and frame < warningEnd then
			local vsx, vsy = spGetViewGeometry()
			glPushMatrix()
			glTranslate(vsx * 0.5, vsy * 0.7, 0)
			glText(warningText, 0, 0, 36, "oc")
			glPopMatrix()
		end
	end
end
--------------------------------------------------------------------------------
