local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Water Type Overlay GL4",
		desc      = "Renders lava/acid shader overlay for water type presets",
		author    = "BARb",
		date      = "2026",
		license   = "GNU GPL v2",
		layer     = -5,
		enabled   = true,
	}
end

-- Bail early if no shader support
if not gl.CreateShader then
	return
end

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

if not LuaShader or not InstanceVBOTable then
	return
end

-- State
local active = false
local activeType = nil  -- "lava" or "acid"
local lavaShader = nil
local foglightShader = nil
local planeVAO = nil
local engineWaterHidden = false

local lavaLevel = 0
local targetLevel = 0
local currentLevel = 0
local baseWaterLevel = 0  -- engine water plane at activation time
local LERP_SPEED = 4.0  -- controls ease-out convergence rate
local heatdistortx = 0
local heatdistortz = 0
local smoothFPS = 30
local tideAmplitude = 2
local tidePeriod = 200

local allowDeferredMapRendering = (Spring.GetConfigInt("AllowDeferredMapRendering") == 1)

-- Check if the real lava gadget is active (don't overlay on actual lava maps)
local springLava = Spring.Lava
local isRealLavaMap = springLava and springLava.isLavaMap

-- Texture paths
local lavaDiffuseEmit = "LuaUI/images/lava/lava2_diffuseemit.dds"
local lavaNormalHeight = "LuaUI/images/lava/lava2_normalheight.dds"
local lavaDistortion = "LuaUI/images/lavadistortion.png"

local elmosPerSquare = 256

-- Fog light config
local fogheightabovelava = 20

-- Shader configs per water type
local shaderConfigs = {
	lava = {
		HEIGHTOFFSET = 2.0,
		COASTWIDTH = 25.0,
		WORLDUVSCALE = 2.0,
		COASTCOLOR = "vec3(2.0, 0.5, 0.0)",
		SPECULAREXPONENT = 64.0,
		SPECULARSTRENGTH = 1.0,
		LOSDARKNESS = 0.5,
		SHADOWSTRENGTH = 0.4,
		OUTOFMAPHEIGHT = -100,
		SWIRLFREQUENCY = 0.025,
		SWIRLAMPLITUDE = 0.003,
		PARALLAXDEPTH = 16.0,
		PARALLAXOFFSET = 0.5,
		GLOBALROTATEFREQUENCY = 0.0001,
		GLOBALROTATEAMPLIDUE = 0.05,
		FOGHEIGHTABOVELAVA = 20,
		FOGCOLOR = "vec3(2.0, 0.5, 0.0)",
		FOGFACTOR = 0.06,
		EXTRALIGHTCOAST = 0.6,
		FOGLIGHTDISTORTION = 4.0,
		FOGABOVELAVA = 1.0,
		SWIZZLECOLORS = "fragColor.rgb = (fragColor.rgb * vec3(1.0, 1.0, 1.0)).rgb;",
	},
	acid = {
		HEIGHTOFFSET = 2.0,
		COASTWIDTH = 16.0,
		WORLDUVSCALE = 3.0,
		COASTCOLOR = "vec3(0.3, 1.5, 0.2)",
		SPECULAREXPONENT = 12.0,
		SPECULARSTRENGTH = 1.0,
		LOSDARKNESS = 0.5,
		SHADOWSTRENGTH = 0.4,
		OUTOFMAPHEIGHT = -100,
		SWIRLFREQUENCY = 0.008,
		SWIRLAMPLITUDE = 0.01,
		PARALLAXDEPTH = 24.0,
		PARALLAXOFFSET = 0.15,
		GLOBALROTATEFREQUENCY = 0.0001,
		GLOBALROTATEAMPLIDUE = 0.05,
		FOGHEIGHTABOVELAVA = 20,
		FOGCOLOR = "vec3(0.3, 1.2, 0.2)",
		FOGFACTOR = 0.1,
		EXTRALIGHTCOAST = 0.5,
		FOGLIGHTDISTORTION = 1.0,
		FOGABOVELAVA = 0.1,
		SWIZZLECOLORS = "fragColor.rgb = (fragColor.rgb * vec3(0.15, 1.0, 0.45)).rgb;",
	},
}

-- Extra per-type params
local typeParams = {
	lava = {
		tideAmplitude = 2,
		tidePeriod = 200,
		fogHeight = 20,
		fogEnabled = true,
	},
	acid = {
		tideAmplitude = 3,
		tidePeriod = 40,
		fogHeight = 20,
		fogEnabled = true,
	},
}

-- Compiled shader caches per type
local compiledShaders = {}  -- { lava = { surface=shader, foglight=shader }, acid = { ... } }

local function compileForType(typeName)
	if compiledShaders[typeName] then return compiledShaders[typeName] end
	local cfg = shaderConfigs[typeName]
	if not cfg then return nil end

	local surfaceCache = {
		vssrcpath = "shaders/GLSL/lava/lava.vert.glsl",
		fssrcpath = "shaders/GLSL/lava/lava.frag.glsl",
		shaderName = "Water Overlay Surface (" .. typeName .. ")",
		uniformInt = {
			heightmapTex = 0, lavaDiffuseEmit = 1, lavaNormalHeight = 2,
			lavaDistortion = 3, shadowTex = 4, infoTex = 5,
		},
		uniformFloat = { lavaHeight = 1, heatdistortx = 1, heatdistortz = 1 },
		shaderConfig = cfg,
	}
	local fogCache = {
		vssrcpath = "shaders/GLSL/lava/lava_fog_light.vert.glsl",
		fssrcpath = "shaders/GLSL/lava/lava_fog_light.frag.glsl",
		shaderName = "Water Overlay Fog (" .. typeName .. ")",
		uniformInt = { mapDepths = 0, modelDepths = 1, lavaDistortion = 2 },
		uniformFloat = { lavaHeight = 1, heatdistortx = 1, heatdistortz = 1 },
		shaderConfig = cfg,
	}

	local surface = LuaShader.CheckShaderUpdates(surfaceCache)
	local fog = LuaShader.CheckShaderUpdates(fogCache)

	if surface and fog then
		compiledShaders[typeName] = { surface = surface, foglight = fog, surfaceCache = surfaceCache, fogCache = fogCache }
		Spring.Echo("[WaterOverlay] Compiled shaders for " .. typeName)
		return compiledShaders[typeName]
	else
		if surface then surface:Delete() end
		if fog then fog:Delete() end
		Spring.Echo("[WaterOverlay] Failed to compile shaders for " .. typeName)
		return nil
	end
end

local function ensurePlaneVAO()
	if planeVAO then return true end
	local xsquares = 3 * Game.mapSizeX / elmosPerSquare
	local zsquares = 3 * Game.mapSizeZ / elmosPerSquare
	local vertexBuffer = InstanceVBOTable.makePlaneVBO(1, 1, xsquares, zsquares)
	local indexBuffer = InstanceVBOTable.makePlaneIndexVBO(xsquares, zsquares)
	planeVAO = gl.GetVAO()
	if not planeVAO then return false end
	planeVAO:AttachVertexBuffer(vertexBuffer)
	planeVAO:AttachIndexBuffer(indexBuffer)
	return true
end

local function activateOverlay(typeName)
	if isRealLavaMap then return end
	if typeName ~= "lava" and typeName ~= "acid" then return end

	local shaders = compileForType(typeName)
	if not shaders then return end

	if not ensurePlaneVAO() then return end

	-- Apply type-specific params
	local tp = typeParams[typeName] or typeParams.lava
	tideAmplitude = tp.tideAmplitude
	tidePeriod = tp.tidePeriod
	fogheightabovelava = tp.fogHeight

	activeType = typeName
	lavaShader = shaders.surface
	foglightShader = shaders.foglight
	baseWaterLevel = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0
	currentLevel = baseWaterLevel + targetLevel
	lavaLevel = currentLevel
	heatdistortx = 0
	heatdistortz = 0

	if not engineWaterHidden then
		Spring.SetDrawWater(false)
		engineWaterHidden = true
	end
	active = true
	Spring.SendLuaRulesMsg("wateroverlay:activate:" .. typeName)
end

local function deactivateOverlay()
	if engineWaterHidden then
		Spring.SetDrawWater(true)
		engineWaterHidden = false
	end
	active = false
	activeType = nil
	lavaShader = nil
	foglightShader = nil
	Spring.SendLuaRulesMsg("wateroverlay:deactivate")
end

-- Expose API via WG
function widget:Initialize()
	if isRealLavaMap then
		Spring.Echo("[WaterOverlay] Real lava map detected, overlay disabled")
	end
	WG.WaterTypeOverlay = {
		activate = activateOverlay,
		deactivate = deactivateOverlay,
		isActive = function() return active end,
		getActiveType = function() return activeType end,
		setLevel = function(level)
			Spring.Echo("[WaterOverlay] setLevel: " .. tostring(level) .. " baseWL=" .. tostring(baseWaterLevel) .. " active=" .. tostring(active))
			targetLevel = level
			Spring.SendLuaRulesMsg("wateroverlay:level:" .. string.format("%.1f", level))
		end,
		getLevel = function() return currentLevel end,
		getTargetLevel = function() return targetLevel end,
		setTideAmplitude = function(v)
			tideAmplitude = v
		end,
		setTidePeriod = function(v)
			tidePeriod = math.max(1, v)
		end,
		setFogHeight = function(v)
			fogheightabovelava = v
		end,
	}
end

function widget:Shutdown()
	deactivateOverlay()
	for typeName, shaders in pairs(compiledShaders) do
		if shaders.surface then shaders.surface:Delete() end
		if shaders.foglight then shaders.foglight:Delete() end
	end
	compiledShaders = {}
	planeVAO = nil
	WG.WaterTypeOverlay = nil
end

function widget:DrawWorldPreUnit()
	if not active or not lavaShader or not planeVAO then return end

	-- Update heat distortion
	local _, _, isPaused = Spring.GetGameSpeed()
	if not isPaused then
		local camX, camY, camZ = Spring.GetCameraDirection()
		local camvlength = math.sqrt(camX * camX + camZ * camZ + 0.01)
		smoothFPS = 0.9 * smoothFPS + 0.1 * math.max(Spring.GetFPS(), 15)
		heatdistortx = heatdistortx - camX / (camvlength * smoothFPS)
		heatdistortz = heatdistortz - camZ / (camvlength * smoothFPS)
	end

	-- Smooth interpolation: ease-out toward target level
	local goal = baseWaterLevel + targetLevel
	local dt = 1.0 / math.max(smoothFPS, 15)
	local diff = goal - currentLevel
	if math.abs(diff) > 0.01 then
		currentLevel = currentLevel + diff * (1 - math.exp(-LERP_SPEED * dt))
	else
		currentLevel = goal
	end
	lavaLevel = currentLevel

	-- Animate tide
	local gameFrame = Spring.GetGameFrame()
	local tideLevel = math.sin(gameFrame / tidePeriod) * tideAmplitude + lavaLevel

	lavaShader:Activate()
	lavaShader:SetUniform("lavaHeight", tideLevel)
	lavaShader:SetUniform("heatdistortx", heatdistortx)
	lavaShader:SetUniform("heatdistortz", heatdistortz)

	gl.Texture(0, "$heightmap")
	gl.Texture(1, lavaDiffuseEmit)
	gl.Texture(2, lavaNormalHeight)
	gl.Texture(3, lavaDistortion)
	gl.Texture(4, "$shadow")
	gl.Texture(5, "$info")

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)

	planeVAO:DrawElements(GL.TRIANGLES)
	lavaShader:Deactivate()

	gl.DepthTest(false)
	gl.DepthMask(false)

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)
	gl.Texture(4, false)
	gl.Texture(5, false)
end

function widget:DrawWorld()
	if not active or not foglightShader or not planeVAO then return end
	if not allowDeferredMapRendering then return end

	local tp = typeParams[activeType]
	if not tp or not tp.fogEnabled then return end

	local gameFrame = Spring.GetGameFrame()
	local tideLevel = math.sin(gameFrame / tidePeriod) * tideAmplitude + lavaLevel

	foglightShader:Activate()
	foglightShader:SetUniform("lavaHeight", tideLevel + fogheightabovelava)
	foglightShader:SetUniform("heatdistortx", heatdistortx)
	foglightShader:SetUniform("heatdistortz", heatdistortz)

	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Texture(2, lavaDistortion)

	gl.Blending(GL.SRC_ALPHA, GL.ONE)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)

	planeVAO:DrawElements(GL.TRIANGLES)
	foglightShader:Deactivate()

	gl.DepthTest(false)
	gl.DepthMask(false)

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end
