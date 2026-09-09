local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map Lava Gadget 2.5",
		desc = "lava",
		author = "knorke, Beherith, The_Yak, Anarchid, Kloot, Gajop, ivand, Damgam, Chronographer",
		date = "Feb 2011, Nov 2013, 2022!",
		license = "GNU GPL v2",
		layer = -3,
		enabled = true,
	}
end

local lava = BAR.Lava
local lavaMap = lava.isLavaMap
local gameSpeed = Game.gameSpeed

--_G.Game.mapSizeX = Game.mapSizeX
--_G.Game.mapSizeY = Game.mapSizeY

if gadgetHandler:IsSyncedCode() then
	local tideIndex = 1
	local tideContinueFrame = 0
	local gameframe = 0
	local tideRhythm = {}
	local lavaUnits = {}
	local damageRateTick = 0

	local lavaLevel = lava.level
	local lavaGrow = lava.grow

	local minGroundHeight = 0
	local GROUND_EXTREMES_UPDATE_RATE = 300 -- refresh cached min ground height every 10 seconds

	local lavaSlow = 0.8 -- slow fraction (0-1) for units in lava, 0.8 = 20% max speed when fully sumberged
	local SLOW_STEP = 0.05 -- quantize slow so wading units don't rewrite move data every damage tick
	local SLOW_STEP_INV = 1 / SLOW_STEP

	-- damage is specified in health lost per second, damage is applied every DAMAGE_RATE frames
	local DAMAGE_RATE = 10 -- frames
	local FULL_CHECK_INTERVAL = 4 -- do full discovery scan every Nth DAMAGE_RATE tick
	local FEATURE_REFRESH_INTERVAL = 8 -- re-read cached feature positions every Nth full check (terraform/impulse)
	local lavaDamage = lava.damage * (DAMAGE_RATE / gameSpeed)
	local lavaDamageFeatures = lava.damageFeatures
	local lavaDamageAirUnits = true

	-- ceg effects
	local lavaEffectBurst = lava.effectBurst
	local lavaEffectDamage = lava.effectDamage

	-- speedups
	local spAddUnitDamage = Spring.AddUnitDamage
	local spAddFeatureDamage = Spring.AddFeatureDamage
	local spGetFeatureDefID = Spring.GetFeatureDefID
	local spGetFeaturePosition = Spring.GetFeaturePosition
	local spGetUnitBasePosition = Spring.GetUnitBasePosition
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetMoveData = Spring.GetUnitMoveTypeData
	local spMoveCtrlEnabled = Spring.MoveCtrl.IsEnabled
	local spSetMoveData = Spring.MoveCtrl.SetGroundMoveTypeData
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetUnitsInBox = Spring.GetUnitsInBox
	local spSpawnCEG = Spring.SpawnCEG
	local random = math.random
	local clamp = math.clamp
	local floor = math.floor
	local sin = math.sin

	local unitMoveDef = {}
	local canFly = {}
	local unitHeight = {}
	local speedDefs = {}
	local turnDefs = {}
	local accDefs = {}
	local isDecoration = {}
	local maxUnitHeight = 0 -- upper bound for midPos.y of a unit whose base is at lava level
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitMoveDef[unitDefID] = unitDef.moveDef -- Will remove this when decision on hovercraft is made
		if unitDef.canFly then
			canFly[unitDefID] = true
		else
			speedDefs[unitDefID] = unitDef.speed
			turnDefs[unitDefID] = unitDef.turnRate
			accDefs[unitDefID] = unitDef.maxAcc
		end
		local height = Spring.GetUnitDefDimensions(unitDefID).height
		unitHeight[unitDefID] = height
		if height > maxUnitHeight then
			maxUnitHeight = height
		end
		if unitDef.customParams and unitDef.customParams.decoration then
			isDecoration[unitDefID] = true
		end
	end
	local geoThermal = {}
	local featureHasMetal = {}
	local isDecorationFeature = {}
	for featureDefID, featureDef in pairs(FeatureDefs) do
		if featureDef.geoThermal then
			geoThermal[featureDefID] = true
		end
		if featureDef.metal and featureDef.metal > 0 then
			featureHasMetal[featureDefID] = true
		end
		if featureDef.customParams and featureDef.customParams.decoration then
			isDecorationFeature[featureDefID] = true
		end
	end

	local function addTideRhythm(targetLevel, speed, remainTime)
		local newTide = {}
		newTide.targetLevel = targetLevel
		newTide.speed = speed
		newTide.remainTime = remainTime
		table.insert(tideRhythm, newTide)
	end

	for _, rhythm in ipairs(lava.tideRhythm) do
		addTideRhythm(unpack(rhythm))
	end

	local function updateLava()
		if
			(lavaGrow < 0 and lavaLevel < tideRhythm[tideIndex].targetLevel)
			or (lavaGrow > 0 and lavaLevel > tideRhythm[tideIndex].targetLevel)
		then
			tideContinueFrame = gameframe + math.round(tideRhythm[tideIndex].remainTime * gameSpeed)
			lavaGrow = 0
			--Spring.Echo ("Next LAVA LEVEL change in " .. (tideContinueFrame-gameframe)/30 .. " seconds")
		end

		if gameframe == tideContinueFrame then
			tideIndex = tideIndex + 1
			if tideIndex > #tideRhythm then
				tideIndex = 1
			end
			--Spring.Echo ("tideIndex=" .. tideIndex .. " target=" ..tideRhythm[tideIndex].targetLevel )
			if lavaLevel < tideRhythm[tideIndex].targetLevel then
				lavaGrow = tideRhythm[tideIndex].speed
			else
				lavaGrow = -tideRhythm[tideIndex].speed
			end
		end
		_G.lavaGrow = lavaGrow
	end

	local function updateSlow(unitID, unitDefID, unitSlow)
		if spMoveCtrlEnabled(unitID) then
			return false
		end
		local baseSpeed = speedDefs[unitDefID]
		local baseTurnRate = turnDefs[unitDefID]
		local baseAccRate = accDefs[unitDefID]
		if not baseSpeed or not baseTurnRate or not baseAccRate then
			return false
		end
		return (pcall(spSetMoveData, unitID, {
			maxSpeed = baseSpeed * unitSlow,
			turnRate = baseTurnRate * unitSlow,
			accRate = baseAccRate * unitSlow,
		}))
	end

	-- Bulk-restore all slowed units when lava retreats below the map surface
	local function restoreAllLavaUnits()
		for unitID, data in pairs(lavaUnits) do
			if data.slowed then
				updateSlow(unitID, data.unitDefID, 1)
			end
		end
		lavaUnits = {}
	end

	-- Fast path: only damage/slow units already known to be in lava
	local function lavaKnownUnitsCheck()
		for unitID, data in pairs(lavaUnits) do
			local x, y, z = spGetUnitBasePosition(unitID)
			if not y then -- unit no longer exists
				lavaUnits[unitID] = nil
			elseif y < lavaLevel then
				if data.slowed then
					local unitSlow = clamp(1 - (((lavaLevel - y) / data.height) * lavaSlow), 1 - lavaSlow, 0.9)
					unitSlow = floor(unitSlow * SLOW_STEP_INV + 0.5) * SLOW_STEP
					if unitSlow ~= data.currentSlow and updateSlow(unitID, data.unitDefID, unitSlow) then
						data.currentSlow = unitSlow
					end
				end
				spAddUnitDamage(unitID, lavaDamage, nil, nil)
				spSpawnCEG(lavaEffectDamage, x, y + 5, z)
			else -- unit exited lava
				if data.slowed then
					updateSlow(unitID, data.unitDefID, 1)
				end
				lavaUnits[unitID] = nil
			end
		end
	end

	-- Discovery: find units newly entering lava. The engine-side box query only returns units
	-- whose midPos is at most maxUnitHeight above the lava, so units high and dry never reach Lua.
	local function lavaNewUnitsCheck()
		local candidates = spGetUnitsInBox(-1e9, -1e9, -1e9, 1e9, lavaLevel + maxUnitHeight, 1e9)
		for i = 1, #candidates do
			local unitID = candidates[i]
			if not lavaUnits[unitID] then -- tracked units were already handled by lavaKnownUnitsCheck
				local unitDefID = spGetUnitDefID(unitID)
				if isDecoration[unitDefID] then
					-- skip decoration units
				elseif canFly[unitDefID] then
					if lavaDamageAirUnits then
						local x, y, z = spGetUnitBasePosition(unitID)
						if y and y < lavaLevel then
							spAddUnitDamage(unitID, lavaDamage, nil, nil)
							spSpawnCEG(lavaEffectDamage, x, y + 5, z)
						end
					end
				else
					local x, y, z = spGetUnitBasePosition(unitID)
					if y and y < lavaLevel then -- first entry into lava
						local height = unitHeight[unitDefID]
						local maxSpeed = speedDefs[unitDefID]
						local turnRate = turnDefs[unitDefID]
						local accelRate = accDefs[unitDefID]
						local data
						if
							(height and height > 0)
							and (maxSpeed and maxSpeed ~= 0)
							and (turnRate and turnRate ~= 0)
							and (accelRate and accelRate ~= 0)
							and (spGetMoveData(unitID).name == "ground")
						then
							data = { unitDefID = unitDefID, height = height, currentSlow = 1, slowed = true }
							local unitSlow = clamp(1 - (((lavaLevel - y) / height) * lavaSlow), 1 - lavaSlow, 0.9)
							unitSlow = floor(unitSlow * SLOW_STEP_INV + 0.5) * SLOW_STEP
							if updateSlow(unitID, unitDefID, unitSlow) then
								data.currentSlow = unitSlow
							end
						else
							data = { unitDefID = unitDefID, slowed = false }
						end
						lavaUnits[unitID] = data
						spAddUnitDamage(unitID, lavaDamage, nil, nil)
						spSpawnCEG(lavaEffectDamage, x, y + 5, z)
					end
				end
			end
		end
	end

	-- Cached positions of features lava can damage; features rarely move, so we only re-read
	-- their positions every FEATURE_REFRESH_INTERVAL checks instead of querying all of them every time
	local featureX = {}
	local featureY = {}
	local featureZ = {}
	local featureRefreshTick = 0

	local function trackFeature(featureID)
		local featureDefID = spGetFeatureDefID(featureID)
		-- always damage non-metal features (trees, foliage); metal features only if lavaDamageFeatures is set
		-- decoration features (e.g. commander tombstones) are never damaged
		if
			not geoThermal[featureDefID]
			and not isDecorationFeature[featureDefID]
			and (lavaDamageFeatures or not featureHasMetal[featureDefID])
		then
			featureX[featureID], featureY[featureID], featureZ[featureID] = spGetFeaturePosition(featureID)
		end
	end

	local function lavaFeaturesCheck()
		featureRefreshTick = featureRefreshTick + 1
		if featureRefreshTick >= FEATURE_REFRESH_INTERVAL then
			featureRefreshTick = 0
			for featureID in pairs(featureY) do
				featureX[featureID], featureY[featureID], featureZ[featureID] = spGetFeaturePosition(featureID)
			end
		end
		for featureID, y in pairs(featureY) do
			if y < lavaLevel then
				local x, z = featureX[featureID], featureZ[featureID]
				spAddFeatureDamage(featureID, lavaDamage, nil, nil)
				spSpawnCEG(lavaEffectDamage, x, y + 5, z)
			end
		end
	end

	-- Full scan: discover new units entering lava, damage all, check features
	local function lavaObjectsCheck()
		lavaKnownUnitsCheck()
		lavaNewUnitsCheck()
		lavaFeaturesCheck()
	end

	function gadget:Initialize()
		if lavaMap == false then
			gadgetHandler:RemoveGadget(self)
			return
		end
		minGroundHeight = select(3, Spring.GetGroundExtremes())
		_G.lavaLevel = lavaLevel
		_G.lavaGrow = lavaGrow
		Spring.SetGameRulesParam("lavaLevel", -99999)
		for _, featureID in ipairs(Spring.GetAllFeatures()) do
			trackFeature(featureID)
		end
	end

	function gadget:FeatureCreated(featureID)
		trackFeature(featureID)
	end

	function gadget:FeatureDestroyed(featureID)
		featureX[featureID], featureY[featureID], featureZ[featureID] = nil, nil, nil
	end

	local mapSizeX = Game.mapX * 512
	local mapSizeY = Game.mapY * 512
	local lavaEffectBurstSounds = lava.effectBurstSounds
	local lavaAmbientSounds = lava.ambientSounds
	local publishedLavaLevel

	function gadget:GameFrame(f)
		gameframe = f
		_G.lavaLevel = lavaLevel + sin(f / gameSpeed) * 0.5
		--_G.lavaLevel = lavaLevel + clamp(math.sin(f / 30), -0.95, 0.95) * 0.5 -- clamp to avoid jittering when sin(x) is around +-1

		-- Periodically refresh cached min ground height (handles terraforming)
		if f % GROUND_EXTREMES_UPDATE_RATE == 0 then
			minGroundHeight = select(3, Spring.GetGroundExtremes())
		end

		local lavaAboveGround = lavaLevel >= minGroundHeight

		if f % DAMAGE_RATE == 0 then
			if lavaAboveGround then
				damageRateTick = damageRateTick + 1
				if damageRateTick >= FULL_CHECK_INTERVAL then
					damageRateTick = 0
					lavaObjectsCheck() -- full scan: discover new units, check features
				else
					lavaKnownUnitsCheck() -- fast path: only already-tracked lava units
				end
			elseif next(lavaUnits) then
				-- Lava retreated below map: bulk-restore any slowed units
				restoreAllLavaUnits()
			end
		end

		updateLava()
		lavaLevel = lavaLevel + (lavaGrow / gameSpeed)
		if lavaLevel ~= publishedLavaLevel then
			publishedLavaLevel = lavaLevel
			Spring.SetGameRulesParam("lavaLevel", lavaLevel)
		end

		-- burst and sound effects (skip entirely when lava is below the map surface)
		if lavaAboveGround and f % 5 == 0 then
			-- bursts
			if lavaEffectBurst then
				local x = random(1, mapSizeX)
				local z = random(1, mapSizeY)
				local y = spGetGroundHeight(x, z)

				if y < lavaLevel then
					spSpawnCEG(lavaEffectBurst, x, lavaLevel + 5, z)

					if lavaEffectBurstSounds and #lavaEffectBurstSounds > 0 then
						local soundIndex = random(1, #lavaEffectBurstSounds)
						local sound = lavaEffectBurstSounds[soundIndex]
						Spring.PlaySoundFile(sound[1], random(sound[2], sound[3]) / 100, x, y, z, "sfx")
					end
				end
			end
			-- ambient sounds
			if lavaAmbientSounds and #lavaAmbientSounds > 0 then
				for i = 1, 10 do
					if random(1, 3) == 1 then
						local x = random(1, mapSizeX)
						local z = random(1, mapSizeY)
						local y = spGetGroundHeight(x, z)
						if y < lavaLevel then
							local soundIndex = random(1, #lavaAmbientSounds)
							local sound = lavaAmbientSounds[soundIndex]
							Spring.PlaySoundFile(sound[1], random(sound[2], sound[3]) / 100, x, y, z, "sfx")
							break
						end
					end
				end
			end
		end

		-- new to use notif system
		-- if lavaGrow then
		--   if lavaGrow > 0 and not lavaNotificationPlayed then
		--     lavaNotificationPlayed = true
		--     LavaGrowsNotificationHere
		--   elseif lavaGrow < 0 and not lavaNotificationPlayed then
		--     lavaNotificationPlayed = true
		--     LavaFallsNotificationHere
		--   elseif lavaGrow == 0 and lavaNotificationPlayed then
		--     lavaNotificationPlayed = false
		--   end
		-- end

		-- old lava rise/drop echos
		-- if lavaGrow and lavaGrow > 0 then
		-- 	Spring.Echo("LavaIsRising")
		-- elseif lavaGrow and lavaGrow < 0 then
		-- 	Spring.Echo("LavaIsDropping")
		-- end
	end

	local DAMAGE_EXTSOURCE_WATER = -5

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID)
		if weaponDefID ~= DAMAGE_EXTSOURCE_WATER then
			-- not water damage, do not modify
			return damage, 1.0
		end
		local moveDef = unitMoveDef[unitDefID]
		if moveDef == nil or moveDef.family ~= "hover" then -- Out of date use of family to be removed post GDT discussion
			-- not a hovercraft, do not modify
			return damage, 1.0
		end
		return 0.0, 1.0
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
		lavaUnits[unitID] = nil
	end
else -- UNSYCNED
	local texturesamplingmode = "" -- ':l:' causes MASSIVE load on zoom out and downsampling textures!
	local lavaDiffuseEmit = texturesamplingmode .. lava.diffuseEmitTex -- pack emissiveness into alpha channel (this is also used as heat for distortion)
	local lavaNormalHeight = texturesamplingmode .. lava.normalHeightTex -- pack height into normals alpha
	local lavaDistortion = texturesamplingmode .. "LuaUI/images/lavadistortion.png"

	local lavaShader
	local lavaPlaneVAO

	local foglightShader

	local foglightenabled = lava.fogEnabled
	local fogheightabovelava = lava.fogHeight
	local allowDeferredMapRendering = (Spring.GetConfigInt("AllowDeferredMapRendering") == 1) -- map depth buffer is required for the foglight shader pass

	local tideamplitude = lava.tideAmplitude
	local tideperiod = lava.tidePeriod
	local lavatidelevel = lava.level

	local heatdistortx = 0
	local heatdistortz = 0
	local smoothFPS = 15

	local elmosPerSquare = 256 -- The resolution of the lava

	local autoreload = false -- set to true to reload the shader every time it is edited

	local LuaShader = gl.LuaShader
	local InstanceVBOTable = gl.InstanceVBOTable

	local unifiedShaderConfig = {
		-- for lavaplane
		HEIGHTOFFSET = 2.0, -- how many elmos above the 'actual' lava height we should render, to avoid ROAM clipping artifacts
		COASTWIDTH = lava.coastWidth, -- how wide the coast of the lava should be
		WORLDUVSCALE = lava.uvScale, -- How many times to tile the lava texture across the entire map
		COASTCOLOR = lava.coastColor, -- the color of the lava coast
		SPECULAREXPONENT = lava.specularExp, -- the specular exponent of the lava plane
		SPECULARSTRENGTH = 1.0, -- The peak brightness of specular highlights
		LOSDARKNESS = lava.losDarkness, -- how much to darken the out-of-los areas of the lava plane
		SHADOWSTRENGTH = lava.shadowStrength, -- how much light a shadowed fragment can receive
		OUTOFMAPHEIGHT = -100, -- what value to use when we are sampling the heightmap outside of the true bounds
		SWIRLFREQUENCY = lava.swirlFreq, -- How fast the main lava texture swirls around default 0.025
		SWIRLAMPLITUDE = lava.swirlAmp, -- How much the main lava texture is swirled around default 0.003
		PARALLAXDEPTH = lava.parallaxDepth, -- set to >0 to enable
		PARALLAXOFFSET = lava.parallaxOffset, -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
		GLOBALROTATEFREQUENCY = 0.0001, -- how fast the whole lava plane shifts around
		GLOBALROTATEAMPLIDUE = 0.05, -- how big the radius of the circle we rotate around is

		-- for foglight:
		FOGHEIGHTABOVELAVA = fogheightabovelava, -- how much higher above the lava the fog light plane is
		FOGCOLOR = lava.fogColor, -- the color of the fog light
		FOGFACTOR = lava.fogFactor, -- how dense the fog is
		EXTRALIGHTCOAST = lava.coastLightBoost, -- how much extra brightness should coastal areas get
		FOGLIGHTDISTORTION = lava.fogDistortion, -- lower numbers are higher distortion amounts
		FOGABOVELAVA = lava.fogAbove, -- the multiplier for how much fog should be above lava fragments, ~0.2 means the lava itself gets hardly any fog, while 2.0 would mean the lava gets a lot of extra fog

		-- for both:
		SWIZZLECOLORS = "fragColor.rgb = (fragColor.rgb * " .. lava.colorCorrection .. ").rgb;", -- yes you can swap around and weight color channels, right after final color, default is 'rgb'
	}

	local lavaVSSrcPath = "shaders/GLSL/lava/lava.vert.glsl"
	local lavaFSSrcPath = "shaders/GLSL/lava/lava.frag.glsl"
	local fogLightVSSrcPath = "shaders/GLSL/lava/lava_fog_light.vert.glsl"
	local fogLightFSSrcPath = "shaders/GLSL/lava/lava_fog_light.frag.glsl"

	local lavaShaderSourceCache = {
		vssrcpath = lavaVSSrcPath,
		fssrcpath = lavaFSSrcPath,
		shaderName = "Lava Surface Shader GL4",
		uniformInt = {
			heightmapTex = 0,
			lavaDiffuseEmit = 1,
			lavaNormalHeight = 2,
			lavaDistortion = 3,
			shadowTex = 4,
			infoTex = 5,
		},
		uniformFloat = {
			lavaHeight = 1,
			heatdistortx = 1,
			heatdistortz = 1,
		},
		shaderConfig = unifiedShaderConfig,
	}

	local fogLightShaderSourceCache = {
		vssrcpath = fogLightVSSrcPath,
		fssrcpath = fogLightFSSrcPath,
		shaderName = "Lava Light Shader GL4",
		uniformInt = {
			mapDepths = 0,
			modelDepths = 1,
			lavaDistortion = 2,
		},
		uniformFloat = {
			lavaHeight = 1,
			heatdistortx = 1,
			heatdistortz = 1,
		},
		shaderConfig = unifiedShaderConfig,
	}

	local myPlayerID = tostring(Spring.GetLocalPlayerID())
	function gadget:GameFrame(f)
		local syncedLavaLevel = SYNCED.lavaLevel
		if syncedLavaLevel then
			lavatidelevel = math.sin(f / tideperiod) * tideamplitude + syncedLavaLevel
		end
		local lavaGrow = SYNCED.lavaGrow
		if lavaGrow then
			if lavaGrow > 0 and not lavaRisingNotificationPlayed then
				lavaRisingNotificationPlayed = true
				if Script.LuaUI("NotificationEvent") then
					Script.LuaUI.NotificationEvent("LavaRising " .. myPlayerID)
				end
			elseif lavaGrow < 0 and not lavaDroppingNotificationPlayed then
				lavaDroppingNotificationPlayed = true
				if Script.LuaUI("NotificationEvent") then
					Script.LuaUI.NotificationEvent("LavaDropping " .. myPlayerID)
				end
			elseif lavaGrow == 0 and (lavaRisingNotificationPlayed or lavaDroppingNotificationPlayed) then
				lavaRisingNotificationPlayed = false
				lavaDroppingNotificationPlayed = false
			end
		end
	end

	function gadget:Initialize()
		if lavaMap == false then
			gadgetHandler:RemoveGadget(self)
			return
		end
		if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
			gadgetHandler:RemoveGadget()
			return
		end

		Spring.SetDrawWater(false)

		-- Now for all intents and purposes, we kinda need to make a lava plane that is 3x the rez of our map
		-- If, e.g our map size is 16x16, we will have 1024 heightmap. If we make a 128 size vbo, then what?
		-- numverts = 128 * 384 * 384 *2 tris then we will get 280k tris ....
		local xsquares = 3 * Game.mapSizeX / elmosPerSquare
		local zsquares = 3 * Game.mapSizeZ / elmosPerSquare
		local vertexBuffer, vertexBufferSize = InstanceVBOTable.makePlaneVBO(1, 1, xsquares, zsquares)
		local indexBuffer, indexBufferSize = InstanceVBOTable.makePlaneIndexVBO(xsquares, zsquares)
		lavaPlaneVAO = gl.GetVAO()
		lavaPlaneVAO:AttachVertexBuffer(vertexBuffer)
		lavaPlaneVAO:AttachIndexBuffer(indexBuffer)

		lavaShader = LuaShader.CheckShaderUpdates(lavaShaderSourceCache)

		if not lavaShader then
			Spring.Echo("Failed to compile Lava Shader")
			gadgetHandler:RemoveGadget()
			return
		end

		foglightShader = LuaShader.CheckShaderUpdates(fogLightShaderSourceCache)

		if not foglightShader then
			Spring.Echo("Failed to compile foglightShader")
			gadgetHandler:RemoveGadget()
			return
		end
	end

	function gadget:DrawWorldPreUnit()
		if lavatidelevel then
			local _, gameSpeed, isPaused = Spring.GetGameSpeed()
			if not isPaused then
				local camX, camY, camZ = Spring.GetCameraDirection()
				local camvlength = math.sqrt(camX * camX + camZ * camZ + 0.01)
				smoothFPS = 0.9 * smoothFPS + 0.1 * math.max(Spring.GetFPS(), 15)
				heatdistortx = heatdistortx - camX / (camvlength * smoothFPS)
				heatdistortz = heatdistortz - camZ / (camvlength * smoothFPS)
			end
			--Spring.Echo(camX, camZ, heatdistortx, heatdistortz,gameSpeed, isPaused)

			-- Expose lava render state to widgets (e.g., PIP minimap overlay)
			if Script.LuaUI("LavaRenderState") then
				Script.LuaUI.LavaRenderState(lavatidelevel, heatdistortx, heatdistortz)
			end

			if autoreload then
				lavaShader = LuaShader.CheckShaderUpdates(lavaShaderSourceCache) or lavaShader
				foglightShader = LuaShader.CheckShaderUpdates(fogLightShaderSourceCache) or foglightShader
			end

			lavaShader:Activate()
			lavaShader:SetUniform("lavaHeight", lavatidelevel)
			lavaShader:SetUniform("heatdistortx", heatdistortx)
			lavaShader:SetUniform("heatdistortz", heatdistortz)

			gl.Texture(0, "$heightmap") -- Texture file
			gl.Texture(1, lavaDiffuseEmit) -- Texture file
			gl.Texture(2, lavaNormalHeight) -- Texture file
			gl.Texture(3, lavaDistortion) -- Texture file
			gl.Texture(4, "$shadow") -- Texture file
			gl.Texture(5, "$info") -- Texture file

			gl.DepthTest(GL.LEQUAL) -- dont draw fragments below terrain
			gl.DepthMask(true) -- actually write to the depth buffer, because otherwise units below lava will fully render over this

			lavaPlaneVAO:DrawElements(GL.TRIANGLES)
			lavaShader:Deactivate()

			gl.DepthTest(false)
			gl.DepthMask(false)

			gl.Texture(0, false) -- Texture file
			gl.Texture(1, false) -- Texture file
			gl.Texture(2, false) -- Texture file
			gl.Texture(3, false) -- Texture file
			gl.Texture(4, false) -- Texture file
			gl.Texture(5, false) -- Texture file
		end
	end

	function gadget:DrawWorld()
		if lavatidelevel and foglightenabled and allowDeferredMapRendering then
			--Now to draw the fog light a good 32 elmos above it :)
			foglightShader:Activate()
			foglightShader:SetUniform("lavaHeight", lavatidelevel + fogheightabovelava)
			foglightShader:SetUniform("heatdistortx", heatdistortx)
			foglightShader:SetUniform("heatdistortz", heatdistortz)

			gl.Texture(0, "$map_gbuffer_zvaltex") -- Texture file
			gl.Texture(1, "$model_gbuffer_zvaltex") -- Texture file
			gl.Texture(2, lavaDistortion) -- Texture file

			gl.Blending(GL.SRC_ALPHA, GL.ONE) -- this will additively blend the foglight above everything
			gl.DepthTest(GL.LEQUAL) -- dont draw fragments below the foglightlevel
			gl.DepthMask(false) -- dont write to the depth buffer

			lavaPlaneVAO:DrawElements(GL.TRIANGLES)
			foglightShader:Deactivate()

			gl.DepthTest(false)
			gl.DepthMask(false)

			gl.Texture(0, false) -- Texture file
			gl.Texture(1, false) -- Texture file
			gl.Texture(2, false) -- Texture file

			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
	end

	function gadget:Shutdown()
		Spring.SetDrawWater(true)
	end
end --ende unsync
