function gadget:GetInfo()
	return {
		name      = "Map Lava Gadget 2.4",
		desc      = "lava",
		author    = "knorke, Beherith, The_Yak, Anarchid, Kloot, Gajop, ivand, Damgam",
		date      = "Feb 2011, Nov 2013, 2022!",
		license   = "Lua: GNU GPL, v2 or later, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer     = -3,
		enabled   = true
	}
end

local lava = Spring.Lava
local lavaMap = lava.isLavaMap

--_G.Game.mapSizeX = Game.mapSizeX
--_G.Game.mapSizeY = Game.mapSizeY

if gadgetHandler:IsSyncedCode() then

	local tideIndex = 1
	local tideContinueFrame = 0
	local gameframe = 0
	local tideRhym = {}

	local lavaLevel = lava.level
	local lavaGrow = lava.grow
	local lavaDamage = lava.damage
	local lavaDamageMode = lava.damageMode
	local lavaDamagesFeatures = lava.damageFeatures
	if lavaDamageMode == "direct" or lavaDamageMode == "proportional" then
		-- these modes specify damage per second, damage is applied every 10 frames
		lavaDamage = lavaDamage/3
	end

	local nolavaburstcegs = lava.nolavaburstcegs

	local spAddUnitDamage = Spring.AddUnitDamage
	local spDestroyFeature = Spring.DestroyFeature
	local spDestroyUnit = Spring.DestroyUnit
	local spGetAllUnits = Spring.GetAllUnits
	local spGetFeatureDefID = Spring.GetFeatureDefID
	local spGetFeaturePosition = Spring.GetFeaturePosition
	local spGetFeatureResources = Spring.GetFeatureResources
	local spGetUnitBasePosition = Spring.GetUnitBasePosition
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitHealth = Spring.GetUnitHealth
	local spSetFeatureReclaim = Spring.SetFeatureReclaim
	local spSpawnCEG = Spring.SpawnCEG

	local function addTideRhym (targetLevel, speed, remainTime)
		local newTide = {}
		newTide.targetLevel = targetLevel
		newTide.speed = speed
		newTide.remainTime = remainTime
		table.insert (tideRhym, newTide)
	end

	for _, rhym in ipairs(lava.tideRhym) do
		addTideRhym(unpack(rhym))
	end

	local function getLavaDamageFunction()
		if lavaDamageMode == "direct" then
			-- direct lava damage
			return function(unitID, gaiaTeamID)
				spAddUnitDamage (unitID, lavaDamage, 0, gaiaTeamID, 1)
			end
		elseif lavaDamageMode == "proportional" then
			-- proportional damage
			return function(unitID, gaiaTeamID)
				local health, maxhealth = spGetUnitHealth(unitID)
				spAddUnitDamage (unitID, maxhealth*lavaDamage, 0, gaiaTeamID, 1)
			end
		elseif lavaDamageMode == "dontdie" then
			-- leave unit with maxhealth*lavaDamage health remaining
			return function(unitID, gaiaTeamID)
				local health, maxhealth = spGetUnitHealth(unitID)
				spAddUnitDamage (unitID, health - maxhealth*lavaDamage, 0, gaiaTeamID, 1)
			end
		elseif lavaDamageMode == "destroy" then
			-- directly destroy unit
			return function(unitID, gaiaTeamID)
				spDestroyUnit (unitID, true, false, gaiaTeamID)
			end
		else
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Bad damage mode for lava: " .. tostring(lavaDamageMode))
			return function() end
		end
	end
	local lavaDamageFunction = getLavaDamageFunction()

	function updateLava()
		if (lavaGrow < 0 and lavaLevel < tideRhym[tideIndex].targetLevel)
			or (lavaGrow > 0 and lavaLevel > tideRhym[tideIndex].targetLevel) then
			tideContinueFrame = gameframe + tideRhym[tideIndex].remainTime*30
			lavaGrow = 0
			--Spring.Echo ("Next LAVA LEVEL change in " .. (tideContinueFrame-gameframe)/30 .. " seconds")
		end

		if gameframe == tideContinueFrame then
			tideIndex = tideIndex + 1
			if tideIndex > table.getn(tideRhym) then
				tideIndex = 1
			end
			--Spring.Echo ("tideIndex=" .. tideIndex .. " target=" ..tideRhym[tideIndex].targetLevel )
			if lavaLevel < tideRhym[tideIndex].targetLevel then
				lavaGrow = tideRhym[tideIndex].speed
			else
				lavaGrow = -tideRhym[tideIndex].speed
			end
		end
		_G.lavaGrow = lavaGrow
	end

	local function clamp(low, x, high)
		return math.min(math.max(x, low), high)
	end

	function gadget:Initialize()
		if lavaMap == false then
			gadgetHandler:RemoveGadget(self)
			return
		end
		_G.lavaLevel = lavaLevel
		_G.lavaGrow = lavaGrow
		Spring.SetGameRulesParam("lavaLevel", -99999)
	end

	function gadget:GameFrame (f)
		gameframe = f
		_G.lavaLevel = lavaLevel+math.sin(f/30)*0.5
		--_G.lavaLevel = lavaLevel + clamp(-0.95, math.sin(f / 30), 0.95) * 0.5 --clamp to avoid jittering when sin(x) is around +-1

		if f % 10 == 0 then
			lavaDeathCheck()
		end

		updateLava()
		lavaLevel = lavaLevel+lavaGrow
		Spring.SetGameRulesParam("lavaLevel", lavaLevel)

		local x = math.random(1,Game.mapX*512)
		local z = math.random(1,Game.mapY*512)
		local y = Spring.GetGroundHeight(x,z)
		if nolavaburstcegs == false then
			if y < lavaLevel then
				--This should be in config file to customize effects on lava plane
				if f % 5 == 0 then
					Spring.SpawnCEG("lavasplash", x, lavaLevel+5, z)
					local r = math.random(1,2)
					if r == 1 then
						Spring.PlaySoundFile("lavaburst1", math.random(80,100)/100, x, y, z, 'sfx')
					elseif r == 2 then
						Spring.PlaySoundFile("lavaburst2", math.random(80,100)/100, x, y, z, 'sfx')
					end
				end
			end
		end
			if f % 5 == 0 then
				for i = 1,10 do
					local x = math.random(1,Game.mapX*512)
					local z = math.random(1,Game.mapY*512)
					local y = Spring.GetGroundHeight(x,z)
					if math.random(1,3) == 1 and y < lavaLevel then
						local r = math.random(1,5)
						if r == 1 then
							Spring.PlaySoundFile("lavabubbleshort1", math.random(25,65)/100, x, y, z, 'sfx')
						elseif r == 2 then
							Spring.PlaySoundFile("lavabubbleshort2", math.random(25,65)/100, x, y, z, 'sfx')
						elseif r == 3 then
							Spring.PlaySoundFile("lavarumbleshort1", math.random(20,40)/100, x, y, z, 'sfx')
						elseif r == 4 then
							Spring.PlaySoundFile("lavarumbleshort2", math.random(20,40)/100, x, y, z, 'sfx')
						elseif r == 5 then
							Spring.PlaySoundFile("lavarumbleshort3", math.random(20,40)/100, x, y, z, 'sfx')
						end
						break
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

	function lavaDeathCheck ()
		local gaiaTeamID = Spring.GetGaiaTeamID()
		local all_units = spGetAllUnits()
		for _, unitID in ipairs(all_units) do
			local UnitDefID = spGetUnitDefID(unitID)
			if not UnitDefs[UnitDefID].canFly then
				x,y,z = spGetUnitBasePosition(unitID)
				if y and y < lavaLevel then
					lavaDamageFunction(unitID, gaiaTeamID)
					--This should be in config file to change effects/cegs
					spSpawnCEG("lavadamage", x, y+5, z)
				end
			end
		end
		if lavaDamagesFeatures then
			local all_features = Spring.GetAllFeatures()
			for _, featureID in ipairs(all_features) do
				local FeatureDefID = spGetFeatureDefID(featureID)
				if not FeatureDefs[FeatureDefID].geoThermal then
					x,y,z = spGetFeaturePosition(featureID)
					if (y and y < lavaLevel) then
						local reclaimLeft = select(5, spGetFeatureResources (featureID))
						if reclaimLeft <= 0 then
							spDestroyFeature(featureID)
							spSpawnCEG("lavadamage", x, y+5, z)
						else
							local newReclaimLeft = reclaimLeft - 0.033
							spSetFeatureReclaim(featureID, newReclaimLeft)
							spSpawnCEG("lavadamage", x, y+5, z)
						end
					end
				end
			end
		end
	end

	local DAMAGE_EXTSOURCE_WATER = -5

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID)
		if weaponDefID ~= DAMAGE_EXTSOURCE_WATER then
			   -- not water damage, do not modify
			   return damage, 1.0
		end
		local unitDef = UnitDefs[unitDefID]
		local moveDef = unitDef.moveDef
		if moveDef == nil or moveDef.family ~= "hover" then
			  -- not a hovercraft, do not modify
			  return damage, 1.0
		end
		return 0.0, 1.0
	end


else  -- UNSYCNED

	local texturesamplingmode = '' -- ':l:' causes MASSIVE load on zoom out and downsampling textures!
	local lavaDiffuseEmit = texturesamplingmode .. lava.diffuseEmitTex -- pack emissiveness into alpha channel (this is also used as heat for distortion)
	local lavaNormalHeight = texturesamplingmode .. lava.normalHeightTex -- pack height into normals alpha
	local lavaDistortion = texturesamplingmode .. "LuaUI/images/lavadistortion.png"

	local lavaShader
	local lavaPlaneVAO

	local foglightShader

	local foglightenabled = lava.fogEnabled
	local fogheightabovelava = lava.fogHeight
	local allowDeferredMapRendering =  (Spring.GetConfigInt("AllowDeferredMapRendering") == 1) -- map depth buffer is required for the foglight shader pass

	local tideamplitude = lava.tideAmplitude
	local tideperiod = lava.tidePeriod
	local lavatidelevel = lava.level

	local heatdistortx = 0
	local heatdistortz = 0

	local elmosPerSquare = 256 -- The resolution of the lava

	local luaShaderDir = "LuaUI/Widgets/Include/"
	local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
	VFS.Include(luaShaderDir.."instancevbotable.lua") -- we are only gonna use the plane maker func of this


	local unifiedShaderConfig = {
		-- for lavaplane
		HEIGHTOFFSET = 2.0,  -- how many elmos above the 'actual' lava height we should render, to avoid ROAM clipping artifacts
		COASTWIDTH = lava.coastWidth, -- how wide the coast of the lava should be
		WORLDUVSCALE = lava.uvScale, -- How many times to tile the lava texture across the entire map
		COASTCOLOR = lava.coastColor, -- the color of the lava coast
		SPECULAREXPONENT = lava.specularExp,  -- the specular exponent of the lava plane
		SPECULARSTRENGTH = 1.0, -- The peak brightness of specular highlights
		LOSDARKNESS = lava.losDarkness, -- how much to darken the out-of-los areas of the lava plane
		SHADOWSTRENGTH = lava.shadowStrength, -- how much light a shadowed fragment can recieve
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
		SWIZZLECOLORS = 'fragColor.rgb = (fragColor.rgb * '..lava.colorCorrection..').rgb;', -- yes you can swap around and weight color channels, right after final color, default is 'rgb'
	}


	local lavaVSSrc = VFS.LoadFile("shaders/GLSL/lava/lava.vert.glsl")
	local lavaFSSrc = VFS.LoadFile("shaders/GLSL/lava/lava.frag.glsl")
	local fogLightVSSrc = VFS.LoadFile("shaders/GLSL/lava/lava_fog_light.vert.glsl")
	local fogLightFSSrc = VFS.LoadFile("shaders/GLSL/lava/lava_fog_light.frag.glsl")

	local myPlayerID = tostring(Spring.GetMyPlayerID())
	function gadget:GameFrame(f)
		if SYNCED.lavaLevel then
			lavatidelevel = math.sin(Spring.GetGameFrame() / tideperiod) * tideamplitude + SYNCED.lavaLevel
		end
		if SYNCED.lavaGrow then
			local lavaGrow = SYNCED.lavaGrow
			if lavaGrow then
				if lavaGrow > 0 and not lavaRisingNotificationPlayed then
					lavaRisingNotificationPlayed = true
					if Script.LuaUI("NotificationEvent") then
						Script.LuaUI.NotificationEvent("LavaRising "..myPlayerID)
					end
				elseif lavaGrow < 0 and not lavaDroppingNotificationPlayed then
					lavaDroppingNotificationPlayed = true
					if Script.LuaUI("NotificationEvent") then
						Script.LuaUI.NotificationEvent("LavaDropping "..myPlayerID)
					end
				elseif lavaGrow == 0 and (lavaRisingNotificationPlayed or lavaDroppingNotificationPlayed) then
					lavaRisingNotificationPlayed = false
					lavaDroppingNotificationPlayed = false
				end
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
		local vertexBuffer, vertexBufferSize = makePlaneVBO(1, 1,  xsquares, zsquares)
		local indexBuffer, indexBufferSize = makePlaneIndexVBO(xsquares, zsquares)
		lavaPlaneVAO = gl.GetVAO()
		lavaPlaneVAO:AttachVertexBuffer(vertexBuffer)
		lavaPlaneVAO:AttachIndexBuffer(indexBuffer)


		local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
		lavaVSSrc = lavaVSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		lavaFSSrc = lavaFSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

		lavaShader = LuaShader({
			vertex = lavaVSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
			fragment = lavaFSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
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
		}, "Lava Shader")


		fogLightVSSrc = fogLightVSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		fogLightFSSrc = fogLightFSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		foglightShader = LuaShader({
			vertex = fogLightVSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
			fragment = fogLightFSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
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
		}, "FogLight shader ")
		local shaderCompiled = lavaShader:Initialize()
		if not shaderCompiled then
			Spring.Echo("Failed to compile Lava Shader")
			gadgetHandler:RemoveGadget()
			return
		end

		shaderCompiled = foglightShader:Initialize()
		if not shaderCompiled then
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
				local camvlength = math.sqrt(camX*camX + camZ *camZ + 0.01)
				local fps = math.max(Spring.GetFPS(), 15)
				heatdistortx = heatdistortx - camX / (camvlength * fps)
				heatdistortz = heatdistortz - camZ / (camvlength * fps)
			end
			--Spring.Echo(camX, camZ, heatdistortx, heatdistortz,gameSpeed, isPaused)

			lavaShader:Activate()
			lavaShader:SetUniform("lavaHeight",lavatidelevel)
			lavaShader:SetUniform("heatdistortx",heatdistortx)
			lavaShader:SetUniform("heatdistortz",heatdistortz)

			gl.Texture(0, "$heightmap")-- Texture file
			gl.Texture(1, lavaDiffuseEmit)-- Texture file
			gl.Texture(2, lavaNormalHeight)-- Texture file
			gl.Texture(3, lavaDistortion)-- Texture file
			gl.Texture(4, "$shadow")-- Texture file
			gl.Texture(5, "$info")-- Texture file

			gl.DepthTest(GL.LEQUAL) -- dont draw fragments below terrain
			gl.DepthMask(true) -- actually write to the depth buffer, because otherwise units below lava will fully render over this

			lavaPlaneVAO:DrawElements(GL.TRIANGLES)
			lavaShader:Deactivate()

			gl.DepthTest(false)
			gl.DepthMask(false)

			gl.Texture(0, false)-- Texture file
			gl.Texture(1, false)-- Texture file
			gl.Texture(2, false)-- Texture file
			gl.Texture(3, false)-- Texture file
			gl.Texture(4, false)-- Texture file
			gl.Texture(5, false)-- Texture file
		end
	end

	function gadget:DrawWorld()
		if lavatidelevel and foglightenabled and allowDeferredMapRendering then
				--Now to draw the fog light a good 32 elmos above it :)
			foglightShader:Activate()
			foglightShader:SetUniform("lavaHeight",lavatidelevel + fogheightabovelava)
			foglightShader:SetUniform("heatdistortx",heatdistortx)
			foglightShader:SetUniform("heatdistortz",heatdistortz)

			gl.Texture(0, "$map_gbuffer_zvaltex")-- Texture file
			gl.Texture(1, "$model_gbuffer_zvaltex")-- Texture file
			gl.Texture(2, lavaDistortion)-- Texture file

			gl.Blending(GL.SRC_ALPHA, GL.ONE) -- this will additively blend the foglight above everything
			gl.DepthTest(GL.LEQUAL) -- dont draw fragments below the foglightlevel
			gl.DepthMask(false) -- dont write to the depth buffer

			lavaPlaneVAO:DrawElements(GL.TRIANGLES)
			foglightShader:Deactivate()

			gl.DepthTest(false)
			gl.DepthMask(false)

			gl.Texture(0, false)-- Texture file
			gl.Texture(1, false)-- Texture file
			gl.Texture(2, false)-- Texture file

			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
	end

	function gadget:Shutdown()
		Spring.SetDrawWater(true)
	end

end--ende unsync
