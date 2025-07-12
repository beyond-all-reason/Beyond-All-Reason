function gadget:GetInfo()
	return {
		name = "Territorial Domination Graphics",
		desc = "Renders territorial domination grid overlay and UI elements",
		author = "SethDGamre",
		date = "2025.02.08",
		license = "GNU GPL, v2",
		layer = -10,
		enabled = true,
		depends = { 'gl4' },
	}
end

local modOptions = Spring.GetModOptions()
local isSynced = gadgetHandler:IsSyncedCode()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) or isSynced then return false end

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local makeInstanceVBOTable = InstanceVBOTable.makeInstanceVBOTable
local makeVAOandAttach = InstanceVBOTable.makeVAOandAttach
local pushElementInstance = InstanceVBOTable.pushElementInstance
local uploadAllElements = InstanceVBOTable.uploadAllElements

local getMiniMapFlipped = VFS.Include("luaui/Include/minimap_utils.lua").getMiniMapFlipped

local SQUARE_SIZE = 1024
local SQUARE_ALPHA = 0.2
local SQUARE_HEIGHT = 10
local MAX_CAPTURE_CHANGE = 0.12
local OWNERSHIP_THRESHOLD = 1 / math.sqrt(2)
local CAPTURE_SOUND_RESET_THRESHOLD = OWNERSHIP_THRESHOLD * 0.5
local CAPTURE_SOUND_VOLUME = 1.0
local UPDATE_FRAME_RATE_INTERVAL = Game.gameSpeed
local NOTIFY_DELAY = math.floor(Game.gameSpeed * 1)

local squareVBO = nil
local squareVAO = nil
local squareShader = nil
local instanceVBO = nil

local captureGrid = {}
local notifyFrames = {}
local currentFrame = 0
local lastMoveFrame = 0

local myAllyID = Spring.GetMyAllyTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
local teams = Spring.GetTeamList()
local amSpectating = Spring.GetSpectatingState()
local previousAllyID = nil
local allyColors = {}

local blankColor = { 0.5, 0.5, 0.5, 0.0 }
local enemyColor = { 1, 0, 0, SQUARE_ALPHA }
local alliedColor = { 0, 1, 0, SQUARE_ALPHA }

local spIsGUIHidden = Spring.IsGUIHidden
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local spPlaySoundFile = Spring.PlaySoundFile

local planeLayout = {
	{ id = 1, name = 'posscale',     size = 4 }, -- a vec4 for pos + scale
	{ id = 2, name = 'ownercolor',   size = 4 }, --  vec4 the color of this new
	{ id = 3, name = 'capturestate', size = 4 }, -- vec4 speed, progress, startframe, showSquareTimestamp
}

local vertexShaderSource = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout (location = 0) in vec4 vertexPosition;
layout (location = 1) in vec4 instancePositionScale;
layout (location = 2) in vec4 instanceColor;
layout (location = 3) in vec4 captureParameters;

uniform sampler2D heightmapTexture;
uniform int isMinimapRendering;
uniform int flipMinimap;
uniform float mapSizeXAxis;
uniform float mapSizeZAxis;
uniform float minCameraDrawHeight;
uniform float maxCameraDrawHeight;
uniform float updateFrameRateInterval;

out VertexOutput {
	vec4 color;
	float progressValue;
	float progressSpeed;
	float startFrame;
	vec2 textureCoordinate;
	float cameraDistance;
	float isInMinimap;
	float currentGameFrame;
	float captureTimestamp;
};

void main() {
	color = instanceColor;
	progressSpeed = captureParameters.x;
	progressValue = captureParameters.y;
	startFrame = captureParameters.z;
	captureTimestamp = captureParameters.w;
	currentGameFrame = timeInfo.x;
	
	textureCoordinate = vertexPosition.xy * 0.5 + 0.5;
	
	vec3 cameraPosition = cameraViewInv[3].xyz;
	cameraDistance = cameraPosition.y;
	
	// Handle two different coordinate systems: minimap 2D vs world 3D
	if (isMinimapRendering == 1) {
		// Convert world coordinates to minimap UV coordinates (0-1 range)
		vec2 minimapPosition = (instancePositionScale.xz / vec2(mapSizeXAxis, mapSizeZAxis));
		vec2 squareSize = vec2(instancePositionScale.w / mapSizeXAxis, instancePositionScale.w / mapSizeZAxis) * 0.5;
		
		vec2 vertexPositionMinimap = vertexPosition.xy * squareSize + minimapPosition;
		
		if (flipMinimap == 0) {
			vertexPositionMinimap.y = 1.0 - vertexPositionMinimap.y;
		}
		
		// Convert from UV (0-1) to NDC (-1 to 1) for final positioning
		gl_Position = vec4(vertexPositionMinimap.x * 2.0 - 1.0, vertexPositionMinimap.y * 2.0 - 1.0, 0.0, 1.0);
		isInMinimap = 1.0;
	} else {
		// Position square in 3D world space, conforming to terrain height
		vec4 worldPosition = vec4(vertexPosition.x * instancePositionScale.w * 0.5, 0.0, vertexPosition.y * instancePositionScale.w * 0.5, 1.0);
		worldPosition.xz += instancePositionScale.xz;
		
		vec2 heightmapUV = heightmapUVatWorldPos(worldPosition.xz);
		float terrainHeight = textureLod(heightmapTexture, heightmapUV, 0.0).x;
		
		worldPosition.y = terrainHeight + instancePositionScale.y;
		
		gl_Position = cameraViewProj * worldPosition;
		isInMinimap = 0.0;
	}
}
]]

local fragmentShaderSource = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform float minCameraDrawHeight;
uniform float maxCameraDrawHeight;
uniform float updateFrameRateInterval;

in VertexOutput {
	vec4 color;
	float progressValue;
	float progressSpeed;
	float startFrame;
	vec2 textureCoordinate;
	float cameraDistance;
	float isInMinimap;
	float currentGameFrame;
	float captureTimestamp;
};

out vec4 fragmentColor;

void main() {
	vec2 centerPoint = vec2(0.5);
	vec2 distanceToEdges = min(textureCoordinate, 1.0 - textureCoordinate);
	float distanceToEdge = min(distanceToEdges.x, distanceToEdges.y);
	
	float borderOpacity = 0.0;
	
	// Only render borders in main view, not minimap
	if (isInMinimap < 0.5) {
		float borderFadeDistance = 0.005;
		borderOpacity = smoothstep(borderFadeDistance, 0.0, distanceToEdge);
	}
	
	// Create animated progress circle that grows from center to corners
	float distanceToCorner = 1.4142135623730951; // sqrt(2) diagonal distance
	float distanceToCenter = length(textureCoordinate - centerPoint) * 2.0;
	float animatedProgress = (progressValue + progressSpeed * (currentGameFrame - startFrame)) * distanceToCorner;
	float circleSoftness = 0.05;
	
	float circleFillAmount = 1.0 - clamp((distanceToCenter - animatedProgress) / circleSoftness, 0.0, 1.0);
	circleFillAmount = step(0.0, circleFillAmount) * circleFillAmount;
	
	vec4 modifiedColor = color;
	
	// Fade territory visibility based on camera height
	float fillFadeAlpha = 1.0;
	if (isInMinimap < 0.5) {
		float fadeRange = maxCameraDrawHeight - minCameraDrawHeight;
		fillFadeAlpha = clamp((cameraDistance - minCameraDrawHeight) / fadeRange, 0.0, 1.0);
		
		// Add pulsing effect for recently captured territories
		if (captureTimestamp > 0.0) {
			float timeSinceCapture = currentGameFrame - captureTimestamp;
			float pulseFrequency = 0.05;
			float pulseDuration = 120.0;
			
			if (timeSinceCapture < pulseDuration) {
				float pulseIntensity = (1.0 - timeSinceCapture / pulseDuration) * 0.8;
				float pulse = sin(timeSinceCapture * pulseFrequency) * 0.5 + 0.5;
				fillFadeAlpha = max(fillFadeAlpha, pulse * pulseIntensity);
				modifiedColor.rgb = mix(modifiedColor.rgb, vec3(1.0), pulse * pulseIntensity * 0.3);
			}
		}
	}
	
	vec4 fillColor = vec4(modifiedColor.rgb, modifiedColor.a * circleFillAmount * fillFadeAlpha);
	
	vec4 borderColor = vec4(1.0, 1.0, 1.0, 0.8);
	
	float borderAlpha = borderOpacity;
	
	// Complex border visibility: show full borders at high camera, only corners at low camera
	if (isInMinimap < 0.5) {
		float heightRatio = clamp((cameraDistance - minCameraDrawHeight) / (maxCameraDrawHeight - minCameraDrawHeight), 0.0, 1.0);
		
		// At low camera: hide interior borders, only show corners
		float innerFadeRadius = mix(1.41, 0.0, heightRatio);
		
		float baseWidth = 0.5;
		float maxWidthMultiplier = 1.0;
		float dynamicBorderWidth = baseWidth * (1.0 + (maxWidthMultiplier - 1.0) * heightRatio);
		
		if (distanceToCenter < innerFadeRadius - dynamicBorderWidth) {
			borderAlpha = 0.0;
		} else if (distanceToCenter < innerFadeRadius) {
			borderAlpha *= smoothstep(innerFadeRadius - dynamicBorderWidth, innerFadeRadius, distanceToCenter);
		}
		
		// Thicker borders at higher camera positions for better visibility
		float minBorderThickness = 0.005;
		float maxBorderThickness = 0.009;
		float borderThickness = mix(minBorderThickness, maxBorderThickness, heightRatio);
		
		float edgeDistance = distanceToEdge / borderThickness;
		if (edgeDistance < 1.0) {
			borderAlpha = max(borderAlpha, (1.0 - smoothstep(0.0, 1.0, edgeDistance)) * heightRatio);
		}
		
		borderAlpha *= mix(0.66, 0.85, heightRatio);
	}
	
	vec4 finalColor = fillColor;
	if (borderAlpha > 0.01) {
		finalColor = mix(fillColor, borderColor, borderAlpha);
	}
	
	fragmentColor = finalColor;
}
]]

local function initializeAllyColors()
	for _, teamID in ipairs(teams) do
		local allyID = select(6, Spring.GetTeamInfo(teamID))
		if allyID and not allyColors[allyID] then
			if allyID ~= gaiaAllyTeamID then
				local r, g, b, a = Spring.GetTeamColor(teamID)
				allyColors[allyID] = { r, g, b, SQUARE_ALPHA }
			else
				allyColors[allyID] = blankColor
			end
		end
	end
end

local function getMaxCameraHeight()
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local fallbackMaxFactor = 1.4 --to handle all camera modes
	local maxFactor = Spring.GetConfigFloat("OverheadMaxHeightFactor", fallbackMaxFactor)
	local absoluteMinimum = 500
	local minimumFactor = 0.8
	local reductionFactor = 0.8
	local minimumMaxHeight = 3000
	local maximumMaxHeight = 5000

	local maxDimension = math.max(mapSizeX, mapSizeZ)
	local maxHeight = math.min(math.max(maxDimension * maxFactor * reductionFactor, minimumMaxHeight), maximumMaxHeight)
	local minHeight = math.max(absoluteMinimum, maxHeight * minimumFactor * reductionFactor)

	return minHeight, maxHeight
end

local function createShader()
	local engineUniformBufferDefinitions = LuaShader.GetEngineUniformBufferDefs()
	local processedVertexShader = vertexShaderSource:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefinitions)
	local processedFragmentShader = fragmentShaderSource
	local minCameraHeight, maxCameraHeight = getMaxCameraHeight()

	squareShader = LuaShader({
		vertex = processedVertexShader,
		fragment = processedFragmentShader,
		uniformInt = {
			heightmapTexture = 0,
			isMinimapRendering = 0,
			flipMinimap = 0,
		},
		uniformFloat = {
			mapSizeXAxis = Game.mapSizeX,
			mapSizeZAxis = Game.mapSizeZ,
			minCameraDrawHeight = minCameraHeight,
			maxCameraDrawHeight = maxCameraHeight,
			updateFrameInterval = UPDATE_FRAME_RATE_INTERVAL,
		},
	}, "territorySquareShader")

	local shaderCompiled = squareShader:Initialize()
	if not shaderCompiled then
		Spring.Echo("Failed to compile territory square shader")
		return false
	end
	return true
end

local function makeSquareVBO(xsize, ysize, xresolution, yresolution)
	if not xsize then xsize = 1 end
	if not ysize then ysize = xsize end
	if not xresolution then xresolution = 1 end
	if not yresolution then yresolution = xresolution end

	xresolution = math.floor(xresolution)
	yresolution = math.floor(yresolution)

	local squareVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if squareVBO == nil then return nil end

	local VBOLayout = {
		{ id = 0, name = "position", size = 4 },
	}

	local vertexData = {}
	local vertexCount = 0

	for x = 0, xresolution do
		for y = 0, yresolution do
			local xPos = xsize * ((x / xresolution) - 0.5) * 2
			local yPos = ysize * ((y / yresolution) - 0.5) * 2

			vertexData[#vertexData + 1] = xPos -- x
			vertexData[#vertexData + 1] = yPos -- y (used as z in the shader)
			vertexData[#vertexData + 1] = 0 -- z (unused)
			vertexData[#vertexData + 1] = 1 -- w

			vertexCount = vertexCount + 1
		end
	end

	local indexData = {}
	local columnSize = yresolution + 1

	for x = 0, xresolution - 1 do
		for y = 0, yresolution - 1 do
			local baseIndex = x * columnSize + y

			-- First triangle (top-left)
			indexData[#indexData + 1] = baseIndex
			indexData[#indexData + 1] = baseIndex + 1
			indexData[#indexData + 1] = baseIndex + columnSize

			-- Second triangle (bottom-right)
			indexData[#indexData + 1] = baseIndex + 1
			indexData[#indexData + 1] = baseIndex + columnSize + 1
			indexData[#indexData + 1] = baseIndex + columnSize
		end
	end

	squareVBO:Define((xresolution + 1) * (yresolution + 1), VBOLayout)
	squareVBO:Upload(vertexData)

	local squareIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if squareIndexVBO == nil then
		squareVBO:Delete()
		return nil
	end

	squareIndexVBO:Define(#indexData)
	squareIndexVBO:Upload(indexData)

	return squareVBO, (xresolution + 1) * (yresolution + 1), squareIndexVBO, #indexData
end

local function updateGridSquareInstanceVBO(gridID, posScale, instanceColor, captureState)
	local instanceData = {
		posScale[1], posScale[2], posScale[3], posScale[4],               -- posscale: x, y, z, scale
		instanceColor[1], instanceColor[2], instanceColor[3], instanceColor[4], -- instanceColor: r, g, b, a
		captureState[1], captureState[2], captureState[3], captureState
		[4]                                                               -- capturestate: speed, progress, startframe, showSquareTimestamp
	}
	pushElementInstance(instanceVBO, instanceData, gridID, true, false)
end

local function initializeOpenGL4()
	local planeResolution = 32
	local squareVBO, numVertices, squareIndexVBO, numIndices = makeSquareVBO(1, 1, planeResolution, planeResolution)
	if not squareVBO then return false end

	instanceVBO = makeInstanceVBOTable(planeLayout, 12, "territory_square_shader")
	instanceVBO.vertexVBO = squareVBO
	instanceVBO.indexVBO = squareIndexVBO
	instanceVBO.numVertices = numIndices
	instanceVBO.primitiveType = GL.TRIANGLES

	squareVAO = makeVAOandAttach(squareVBO, instanceVBO.instanceVBO, squareIndexVBO)
	instanceVBO.VAO = squareVAO
	uploadAllElements(instanceVBO)
	return createShader()
end

function gadget:Initialize()
	if initializeOpenGL4() == false then
		gadgetHandler:RemoveGadget()
		return
	end

	amSpectating = Spring.GetSpectatingState()
	myAllyID = Spring.GetMyAllyTeamID()
	initializeAllyColors()
end

local function getSquareVisibility(newAllyOwnerID, oldAllyOwnerID, visibilityArray)
	if amSpectating or newAllyOwnerID == myAllyID then
		return true, false
	end

	local isCurrentlyVisible = false
	if visibilityArray and myAllyID >= 0 and myAllyID + 1 <= #visibilityArray then
		isCurrentlyVisible = string.sub(visibilityArray, myAllyID + 1, myAllyID + 1) == "1"
	end

	local shouldResetColor = oldAllyOwnerID == myAllyID and newAllyOwnerID ~= myAllyID

	return isCurrentlyVisible, shouldResetColor
end

local function notifyCapture(gridID)
	local gridData = captureGrid[gridID]
	return not amSpectating and gridData.allyOwnerID == myAllyID and not gridData.playedCapturedSound and
	gridData.newProgress > OWNERSHIP_THRESHOLD
end

local function doCaptureEffects(gridID)
	local gridData = captureGrid[gridID]
	notifyFrames[currentFrame + NOTIFY_DELAY] = gridID
	gridData.showSquareTimestamp = currentFrame
end

local function updateGridSquareColor(gridData)
	if not gridData.isVisible then
		return
	end

	if gridData.allyOwnerID == gaiaAllyTeamID then
		gridData.currentColor = blankColor
	elseif amSpectating then
		allyColors[gaiaAllyTeamID] = blankColor
		gridData.currentColor = allyColors[gridData.allyOwnerID] or blankColor
	else
		if gridData.allyOwnerID == myAllyID then
			gridData.currentColor = alliedColor
		else
			gridData.currentColor = enemyColor
		end
	end
end

local function processSpectatorModeChange()
	local currentSpectating = Spring.GetSpectatingState()
	local currentAllyID = Spring.GetMyAllyTeamID()

	if currentSpectating ~= amSpectating or (previousAllyID and currentAllyID ~= previousAllyID) then
		amSpectating = currentSpectating
		myAllyID = currentAllyID

		for gridID, gridSquareData in pairs(captureGrid) do
			local resetColor = false
			gridSquareData.isVisible, resetColor = getSquareVisibility(gridSquareData.allyOwnerID,
				gridSquareData.allyOwnerID, gridSquareData.visibilityArray)
			if resetColor then
				gridSquareData.currentColor = blankColor
			end
		end
	end
	previousAllyID = myAllyID
end

local function updateGridSquareVisuals()
	for gridID, _ in pairs(captureGrid) do
		local gridData = captureGrid[gridID]

		updateGridSquareColor(gridData)

		local captureChangePerFrame = 0
		if gridData.captureChange then
			captureChangePerFrame = gridData.captureChange / UPDATE_FRAME_RATE_INTERVAL
		end

		updateGridSquareInstanceVBO(
			gridID,
			{ gridData.gridMidpointX, SQUARE_HEIGHT, gridData.gridMidpointZ, SQUARE_SIZE },
			gridData.currentColor,
			{ captureChangePerFrame, gridData.oldProgress, currentFrame, gridData.showSquareTimestamp }
		)
		gridData.captureChange = nil
	end

	uploadAllElements(instanceVBO)
end

function gadget:RecvFromSynced(messageName, ...)
	if messageName == "InitializeGridSquare" then
		local gridID, allyOwnerID, progress, gridMidpointX, gridMidpointZ, visibilityArray = ...
		local isVisible, _ = getSquareVisibility(allyOwnerID, allyOwnerID, visibilityArray)
		captureGrid[gridID] = {
			visibilityArray = visibilityArray,
			allyOwnerID = allyOwnerID,
			oldProgress = progress,
			newProgress = progress,
			captureChange = 0,
			gridMidpointX = gridMidpointX,
			gridMidpointZ = gridMidpointZ,
			isVisible = isVisible,
			currentColor = blankColor,
			showSquareTimestamp = 0
		}
	elseif messageName == "InitializeConfigs" then
		SQUARE_SIZE, UPDATE_FRAME_RATE_INTERVAL = ...
	elseif messageName == "UpdateGridSquare" then
		local gridID, allyOwnerID, progress, visibilityArray = ...
		local gridData = captureGrid[gridID]
		if gridData then
			local ignoredProgress = 0.01
			local oldAllyOwnerID = gridData.allyOwnerID
			gridData.visibilityArray = visibilityArray
			gridData.allyOwnerID = allyOwnerID

			gridData.isVisible, _ = getSquareVisibility(allyOwnerID, oldAllyOwnerID, visibilityArray)
			if progress < ignoredProgress and oldAllyOwnerID == myAllyID then
				gridData.newProgress = 0
				gridData.allyOwnerID = gaiaAllyTeamID --hidden
			elseif not gridData.isVisible then
				gridData.newProgress = gridData.oldProgress
				gridData.captureChange = 0
			else
				gridData.oldProgress = gridData.newProgress
				gridData.captureChange = progress - gridData.oldProgress

				if math.abs(gridData.captureChange) > MAX_CAPTURE_CHANGE then
					gridData.oldProgress = progress -- Snap progress if change is too large
					gridData.captureChange = 0 -- No smooth animation needed if snapping
				end
				gridData.newProgress = progress

				if notifyCapture(gridID) then
					gridData.playedCapturedSound = true
					doCaptureEffects(gridID)
				end
			end
			if gridData.newProgress < CAPTURE_SOUND_RESET_THRESHOLD then
				gridData.playedCapturedSound = false
			end
		end
	end
end

function gadget:GameFrame(frame)
	currentFrame = frame

	if notifyFrames[frame] then
		local gridID = notifyFrames[frame]
		local gridData = captureGrid[gridID]
		spPlaySoundFile("scavdroplootspawn", CAPTURE_SOUND_VOLUME, gridData.gridMidpointX, 0, gridData.gridMidpointZ, 0,
			0, 0, "sfx")
		notifyFrames[frame] = nil
	end

	if frame % UPDATE_FRAME_RATE_INTERVAL == 0 and frame ~= lastMoveFrame then
		processSpectatorModeChange()
		updateGridSquareVisuals()
		lastMoveFrame = frame
	end
end

function gadget:DrawWorldPreUnit()
	if not squareShader or not squareVAO or not instanceVBO then return end

	if spIsGUIHidden() then return end

	glTexture(0, "$heightmap")
	glDepthTest(true)

	squareShader:Activate()
	squareShader:SetUniformInt("isMinimapRendering", 0)
	squareShader:SetUniformInt("flipMinimap", getMiniMapFlipped() and 1 or 0)
	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)

	squareShader:Deactivate()
	glTexture(0, false)
	glDepthTest(false)
end

function gadget:DrawInMiniMap()
	if not squareShader or not squareVAO or not instanceVBO then return end

	if spIsGUIHidden() then return end

	squareShader:Activate()
	squareShader:SetUniformInt("isMinimapRendering", 1)
	squareShader:SetUniformInt("flipMinimap", getMiniMapFlipped() and 1 or 0)

	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)

	squareShader:Deactivate()
end

function gadget:Shutdown()
	if squareVBO then
		squareVBO:Delete()
	end
	if instanceVBO and instanceVBO.instanceVBO then
		instanceVBO.instanceVBO:Delete()
	end
	if squareShader then
		squareShader:Finalize()
	end
end
