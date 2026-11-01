local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Zombie Wrecks GL4",
		desc = "Draws the special effects around zombie wrecks, and plays sounds",
		author = "efrec",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local RULESPARAM_ENABLED = "zombies_enabled"

if gadgetHandler:IsSyncedCode() then
	local maybeZombies = Spring.GetModOptions().zombies ~= "disabled" or (GG.Zombies and GG.Zombies.IdleMode == true)
	if not maybeZombies then
		return false
	end

	local SendToUnsynced = SendToUnsynced

	function gadget:Initialize()
		GG.ZombieWreckEffects = {
			---@param featureID FeatureID
			---@param armFrame integer
			---@param riseFrame integer
			Arm = function(featureID, armFrame, riseFrame)
				SendToUnsynced("zombieWreckArm", featureID, armFrame, riseFrame)
			end,
			---@param featureID FeatureID
			Disarm = function(featureID)
				SendToUnsynced("zombieWreckDisarm", featureID)
			end,
		}
	end

	function gadget:Shutdown()
		GG.ZombieWreckEffects = nil
	end

	return
end

if not Spring.GetGameRulesParam(RULESPARAM_ENABLED) then
	return false
end

local drawsWithShaders = Platform.check("gl4")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local gameSpeed = Game.gameSpeed

local SMOKE_TEXTURE = "bitmaps/atmos/smoke_puff.tga"
local SMOKE_COLOR = { 0.6, 0.36, 0.76 }

local SMOKE_SPRITE_COUNT = 28
local SMOKE_LIFE_FRAMES = 50
local SMOKE_LINGER_FRAMES = 9
local SMOKE_START_DISTANCE_SCALE = 0.67
local SMOKE_COUNT_S_CURVE_BLEND = 0.35
local SMOKE_SILENT_START_FRACTION = 0.125
local SMOKE_HOLD_FRAMES_AFTER_PUSHBACK = gameSpeed
local PUFF_SPRITE_COUNT = 6
local PUFF_FRAMES = gameSpeed * 2

local FLASH_COUNT = 10
local FLASH_LIGHTNING_SIZE = 0.5
local FLASH_LIGHTNING_INTENSITY = 0.75
local LIGHTNING_SMALL_WRECK_SCALE = 0.7
local LIGHTNING_FULL_SIZE_WRECK_RADIUS = 40
local SMOKE_FINISH_FRAMES_BEFORE_RISE = gameSpeed * 2
local STRIKE_COUNT = 3
local STRIKE_INTERVAL_FRAMES = 12
---@type string[]
local THUNDER_SOUNDS = {
	"sounds/atmos/thunder1.wav",
	"sounds/atmos/thunder2.wav",
	"sounds/atmos/thunder3.wav",
	"sounds/atmos/thunder4.wav",
	"sounds/atmos/thunder5.wav",
	"sounds/atmos/thunder6.wav",
}
local THUNDER_VOLUME = 0.8
local THUNDER_FULL_VOLUME_WRECK_RADIUS = 40
local THUNDER_FULL_VOLUME_CAMERA_DISTANCE = 600
local THUNDER_SILENT_CAMERA_DISTANCE = 3000
local UPDATE_INTERVAL_FRAMES = 3
local SETTLED_SPEED_SQUARED = 0.01
local WRECK_INSTANCE_CAPACITY = 512

local BILLBOARD_SMOKE_SPRITE_COUNT = 3
local BILLBOARD_CULL_RADIUS = 200
local BILLBOARD_LIGHTNING_MULTIPLIER = 1.25
local BILLBOARD_BOLT_FRAMES = 10
local BILLBOARD_BOLT_HEIGHT = 220

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spGetCameraPosition = Spring.GetCameraPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureVelocity = Spring.GetFeatureVelocity
local spGetFeatureAllyTeam = Spring.GetFeatureAllyTeam
local spGetFeatureRulesParam = Spring.GetFeatureRulesParam
local spGetGameFrame = Spring.GetGameFrame
local spGetLocalAllyTeamID = Spring.GetLocalAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spIsPosInLos = Spring.IsPosInLos
local spIsSphereInView = Spring.IsSphereInView
local spValidFeatureID = Spring.ValidFeatureID

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local localAllyTeamID = spGetLocalAllyTeamID()
local fullView = false

local wrecks = {} ---@type table<FeatureID, table?>

local shader ---@type LuaShader?
local spriteVBO ---@type InstanceVBOTable?
local spriteCornerVBO ---@type VBO?
local billboardBolts = {} ---@type table[]

local updateWreckSprites ---@type fun(featureID: FeatureID, wreck: table)
local removeWreckSprite ---@type fun(featureID: FeatureID)
local drawWrecks ---@type fun()
local spawnFlash ---@type fun(wreck: table)
local spawnStrike ---@type fun(wreck: table)
local flashesPerWreck, strikesPerWreck = FLASH_COUNT, STRIKE_COUNT

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vertexShaderSource = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout (location = 0) in vec3 corner_index;

layout (location = 1) in vec4 wreck_position;
layout (location = 2) in vec4 frames;
layout (location = 3) in vec4 hold_until_frame;

out DataVS {
	vec2 uv;
	float alpha;
};

#line 15000
void main() {
	float frame = timeInfo.x + timeInfo.w;
	float settleFrame = frames.x;
	float armFrame = frames.y;
	float riseFrame = frames.z;
	float seed = frames.w;
	float spriteIndex = corner_index.z;
	float finishFrame = riseFrame - SMOKE_FINISH_FRAMES_BEFORE_RISE;
	float progress = clamp((frame - armFrame) / max(finishFrame - armFrame, 1.0), 0.0, 1.0);

	vec3 center = wreck_position.xyz;
	float size = 0.0;
	alpha = 0.0;

	if (spriteIndex < SMOKE_SPRITE_COUNT) {
		float wreckRadius = max(wreck_position.w, 12.0);
		float phaseRandom = fract(sin(seed * 12.9898 + spriteIndex * 78.233) * 43758.5453);
		float loopFrames = SMOKE_LIFE_FRAMES + SMOKE_LINGER_FRAMES;
		float loopIndex = mod(floor((frame - armFrame) / loopFrames + phaseRandom), 1024.0);
		float angleRandom = fract(sin(seed * 39.3468 + spriteIndex * 11.135 + loopIndex * 7.919) * 24634.6345);
		float distanceRandom = fract(sin(seed * 73.1562 + spriteIndex * 52.931 + loopIndex * 3.571) * 12345.6789);
		float heightRandom = fract(sin(seed * 5.4321 + spriteIndex * 91.717 + loopIndex * 5.113) * 65432.1234);
		float smokeTimerProgress = clamp((progress - SMOKE_SILENT_START_FRACTION) / (1.0 - SMOKE_SILENT_START_FRACTION), 0.0, 1.0);
		float smokeCountFraction = mix(smokeTimerProgress, smoothstep(0.0, 1.0, smokeTimerProgress), SMOKE_COUNT_S_CURVE_BLEND);
		float smokeParticleCount = frame < hold_until_frame.x ? 0.0 : SMOKE_SPRITE_COUNT * smokeCountFraction;
		float loopFrame = fract((frame - armFrame) / loopFrames + phaseRandom) * loopFrames;
		float loopAge = min(loopFrame / SMOKE_LIFE_FRAMES, 1.0);
		float linger = max(loopFrame - SMOKE_LIFE_FRAMES, 0.0) / SMOKE_LINGER_FRAMES;
		bool loopEndsBeforeFinish = frame - loopFrame <= finishFrame - loopFrames;
		if (spriteIndex < smokeParticleCount && frame >= armFrame && loopEndsBeforeFinish) {
			float angle = angleRandom * 6.2832;
			float wreckScale = clamp(wreckRadius / 20.0, 0.6, 2.2);
			float endDistance = wreckRadius * 0.35 * heightRandom;
			vec3 endPosition = vec3(cos(angle + 2.1) * endDistance, 3.0 + wreckRadius * 0.4 * distanceRandom, sin(angle + 2.1) * endDistance);
			float startDistance = (wreckRadius + 30.0 * distanceRandom) * SMOKE_START_DISTANCE_SCALE;
			vec3 startPosition = vec3(cos(angle) * startDistance, 45.0 + 45.0 * heightRandom, sin(angle) * startDistance) * wreckScale;
			float drawnInFraction = pow(loopAge, 1.4);
			vec3 wobble = vec3(sin(frame * 0.09 + phaseRandom * 6.0), 0.0, cos(frame * 0.07 + angleRandom * 6.0)) * 3.0 * (1.0 - loopAge);
			center += mix(startPosition, endPosition, drawnInFraction) + wobble;
			float possession = smoothstep(0.7, 1.0, progress);
			size = mix(34.0, 5.0 + 6.0 * possession, drawnInFraction) * wreckScale;
			alpha = mix(0.08, 0.7 + 0.3 * possession, drawnInFraction) * smoothstep(0.0, 0.1, loopAge) * (1.0 - linger);
		}
	} else {
		float puffAge = (frame - settleFrame) / PUFF_FRAMES;
		if (puffAge >= 0.0 && puffAge <= 1.0) {
			float angle = seed + spriteIndex * 6.2832 / PUFF_SPRITE_COUNT;
			center += vec3(cos(angle) * puffAge * 24.0, 6.0 + puffAge * 18.0, sin(angle) * puffAge * 24.0);
			size = 14.0 + 30.0 * puffAge;
			alpha = 0.7 * (1.0 - puffAge);
		}
	}

	vec3 right = cameraViewInv[0].xyz;
	vec3 up = cameraViewInv[1].xyz;
	vec3 worldPosition = center + (right * corner_index.x + up * corner_index.y) * size;
	gl_Position = cameraViewProj * vec4(worldPosition, 1.0);
	uv = corner_index.xy * 0.5 + 0.5;
}
]]

local fragmentShaderSource = [[
#version 420
#extension GL_ARB_shading_language_420pack : require
#line 20000

//__DEFINES__

uniform sampler2D smokeTexture;

in DataVS {
	vec2 uv;
	float alpha;
};

out vec4 fragColor;

#line 25000
void main() {
	vec4 smoke = texture(smokeTexture, uv);
	fragColor = vec4(SMOKE_COLOR * smoke.rgb, smoke.a * alpha);
}
]]

local function makeSpriteCornerVBO()
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, -1 }, { 1, 1 }, { -1, 1 } }
	local vertexData = {}
	for spriteIndex = 0, SMOKE_SPRITE_COUNT + PUFF_SPRITE_COUNT - 1 do
		for _, corner in ipairs(corners) do
			vertexData[#vertexData + 1] = corner[1]
			vertexData[#vertexData + 1] = corner[2]
			vertexData[#vertexData + 1] = spriteIndex
		end
	end
	local vertexCount = #corners * (SMOKE_SPRITE_COUNT + PUFF_SPRITE_COUNT)
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not vbo then
		return nil, 0
	end
	vbo:Define(vertexCount, { { id = 0, name = "corner_index", size = 3 } })
	vbo:Upload(vertexData)
	return vbo, vertexCount
end

local function initGL4()
	local cornerVBO, vertexCount = makeSpriteCornerVBO()
	if not cornerVBO then
		return false
	end
	spriteCornerVBO = cornerVBO
	local instanceTable = InstanceVBOTable.makeInstanceVBOTable({
		{ id = 1, name = "wreck_position", size = 4 },
		{ id = 2, name = "frames", size = 4 },
		{ id = 3, name = "hold_until_frame", size = 4 },
	}, WRECK_INSTANCE_CAPACITY, "gfx_zombie_wrecks_gl4")
	if not instanceTable then
		return false
	end
	instanceTable.vertexVBO = cornerVBO
	instanceTable.numVertices = vertexCount
	instanceTable.VAO = InstanceVBOTable.fillVAOSlots(
		InstanceVBOTable.makeVAOandAttach(instanceTable.vertexVBO, instanceTable.instanceVBO),
		false,
		true
	)
	spriteVBO = instanceTable

	local defines = table.concat({
		"#define SMOKE_SPRITE_COUNT " .. string.format("%.1f", SMOKE_SPRITE_COUNT),
		"#define SMOKE_LIFE_FRAMES " .. string.format("%.1f", SMOKE_LIFE_FRAMES),
		"#define SMOKE_LINGER_FRAMES " .. string.format("%.1f", SMOKE_LINGER_FRAMES),
		"#define SMOKE_START_DISTANCE_SCALE " .. string.format("%.2f", SMOKE_START_DISTANCE_SCALE),
		"#define SMOKE_COUNT_S_CURVE_BLEND " .. string.format("%.2f", SMOKE_COUNT_S_CURVE_BLEND),
		"#define SMOKE_SILENT_START_FRACTION " .. string.format("%.3f", SMOKE_SILENT_START_FRACTION),
		"#define SMOKE_FINISH_FRAMES_BEFORE_RISE " .. string.format("%.1f", SMOKE_FINISH_FRAMES_BEFORE_RISE),
		"#define PUFF_SPRITE_COUNT " .. string.format("%.1f", PUFF_SPRITE_COUNT),
		"#define PUFF_FRAMES " .. string.format("%.1f", PUFF_FRAMES),
		string.format("#define SMOKE_COLOR vec3(%.3f, %.3f, %.3f)", SMOKE_COLOR[1], SMOKE_COLOR[2], SMOKE_COLOR[3]),
	}, "\n")
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local vertexSource =
		vertexShaderSource:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs):gsub("//__DEFINES__", defines)
	local fragmentSource = fragmentShaderSource:gsub("//__DEFINES__", defines)
	shader = LuaShader({
		vertex = vertexSource,
		fragment = fragmentSource,
		uniformInt = { smokeTexture = 0 },
	}, "gfx_zombie_wrecks_gl4")
	if not shader:Initialize() then
		return false
	end
	gl.DeleteList(gl.CreateList(function()
		gl.Texture(0, SMOKE_TEXTURE)
		gl.Texture(0, false)
	end))
	return true
end

--------------------------------------------------------------------------------
-- Wreck tracking
--------------------------------------------------------------------------------

local function isWreckShown(wreck)
	return fullView or wreck.allyTeamID == localAllyTeamID or wreck.seen
end

local function ignoreWreckSprite() end

local function removeWreckSpriteInstance(featureID)
	---@cast spriteVBO -nil
	if spriteVBO.instanceIDtoIndex[featureID] then
		popElementInstance(spriteVBO, featureID)
	end
end

local function updateWreckSpriteInstance(featureID, wreck)
	---@cast spriteVBO -nil
	if wreck.settleFrame and isWreckShown(wreck) then
		pushElementInstance(spriteVBO, {
			wreck.x,
			wreck.y,
			wreck.z,
			wreck.radius,
			wreck.settleFrame,
			wreck.armFrame,
			wreck.riseFrame,
			wreck.seed,
			wreck.holdUntilFrame,
			0,
			0,
			0,
		}, featureID, true)
	else
		removeWreckSpriteInstance(featureID)
	end
end

---Eases in between a quadratic and an exponential curve, so flashes come closer together as the rise nears.
local function flashEasing(progress)
	local quadratic = progress * progress
	local exponential = (2 ^ (10 * progress) - 1) / 1023
	return 0.5 * (quadratic + exponential)
end

local function addBillboardBolt(wreck, height)
	billboardBolts[#billboardBolts + 1] = {
		x = wreck.x,
		y = wreck.y,
		z = wreck.z,
		startFrame = spGetGameFrame(),
		height = height,
		seed = math.random() * 6.2832,
	}
end

local function spawnLightningFlash(wreck)
	GG.SpawnEnvironmentalLightning(
		"scavradiation",
		wreck.x,
		wreck.y,
		wreck.z,
		FLASH_LIGHTNING_SIZE * wreck.lightningScale,
		FLASH_LIGHTNING_INTENSITY * wreck.lightningScale
	)
end

local function spawnBillboardFlash(wreck)
	addBillboardBolt(wreck, BILLBOARD_BOLT_HEIGHT * FLASH_LIGHTNING_SIZE * wreck.lightningScale)
end

local function spawnLightningStrike(wreck)
	GG.SpawnEnvironmentalLightning(
		"zombiestrike",
		wreck.x,
		wreck.y,
		wreck.z,
		FLASH_LIGHTNING_SIZE * wreck.lightningScale,
		FLASH_LIGHTNING_INTENSITY * wreck.lightningScale
	)
end

local function spawnBillboardStrike(wreck)
	addBillboardBolt(wreck, BILLBOARD_BOLT_HEIGHT * wreck.lightningScale)
end

local function thunderVolumeScale(wreck)
	local cameraX, cameraY, cameraZ = spGetCameraPosition()
	local offsetX, offsetY, offsetZ = cameraX - wreck.x, cameraY - wreck.y, cameraZ - wreck.z
	local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY + offsetZ * offsetZ)
	local cameraCloseness = 1
		- (distance - THUNDER_FULL_VOLUME_CAMERA_DISTANCE)
			/ (THUNDER_SILENT_CAMERA_DISTANCE - THUNDER_FULL_VOLUME_CAMERA_DISTANCE)
	local wreckSizeFraction = wreck.radius / THUNDER_FULL_VOLUME_WRECK_RADIUS
	return math.min(1, math.max(0, cameraCloseness)) * math.min(1, wreckSizeFraction)
end

local function strikeWreck(wreck, playsThunder)
	spawnStrike(wreck)
	local volumeScale = thunderVolumeScale(wreck)
	if playsThunder and math.random() < volumeScale then
		local sound = THUNDER_SOUNDS[math.random(#THUNDER_SOUNDS)] --[[@as string]]
		Spring.PlaySoundFile(sound, THUNDER_VOLUME * volumeScale, wreck.x, wreck.y, wreck.z, 0)
	end
end

local function armWreck(_, featureID, armFrame, riseFrame)
	local wreck = wrecks[featureID]
	if not wreck then
		local x, y, z = spGetFeaturePosition(featureID)
		if not x then
			return
		end
		local radius = Spring.GetFeatureRadius(featureID) or 0
		wreck = {
			radius = radius,
			lightningScale = LIGHTNING_SMALL_WRECK_SCALE
				+ (1 - LIGHTNING_SMALL_WRECK_SCALE) * math.min(1, radius / LIGHTNING_FULL_SIZE_WRECK_RADIUS),
			x = x,
			y = y,
			z = z,
			allyTeamID = spGetFeatureAllyTeam(featureID),
			seen = false,
			flashCount = 0,
			holdUntilFrame = 0,
			seed = featureID % 628 / 100,
		}
		wrecks[featureID] = wreck
	elseif riseFrame > wreck.riseFrame then
		wreck.holdUntilFrame = spGetGameFrame() + SMOKE_HOLD_FRAMES_AFTER_PUSHBACK
	end
	wreck.armFrame = armFrame
	wreck.riseFrame = riseFrame
	wreck.strikeCount = 0
	updateWreckSprites(featureID, wreck)
end

local function disarmWreck(_, featureID)
	wrecks[featureID] = nil
	removeWreckSprite(featureID)
end

local function updateWreck(featureID, wreck, frame)
	if not spValidFeatureID(featureID) then
		disarmWreck(nil, featureID)
		return
	end

	local changed = false
	if not wreck.settleFrame then
		local velocityX, velocityY, velocityZ = spGetFeatureVelocity(featureID)
		---@cast velocityY -nil
		---@cast velocityZ -nil
		if
			not velocityX
			or velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ < SETTLED_SPEED_SQUARED
		then
			wreck.x, wreck.y, wreck.z = spGetFeaturePosition(featureID)
			wreck.settleFrame = frame
			changed = true
		end
	end
	if not wreck.seen and spIsPosInLos(wreck.x, wreck.y, wreck.z, localAllyTeamID) then
		wreck.seen = true
		changed = true
	end
	if changed then
		updateWreckSprites(featureID, wreck)
	end

	if wreck.settleFrame and wreck.flashCount < flashesPerWreck then
		local progress = (frame - wreck.armFrame) / math.max(wreck.riseFrame - wreck.armFrame, 1)
		local easedProgress = flashEasing(math.min(progress, 1))
		local flashed = false
		while wreck.flashCount < flashesPerWreck and easedProgress >= (wreck.flashCount + 1) / (flashesPerWreck + 1) do
			wreck.flashCount = wreck.flashCount + 1
			flashed = true
		end
		if flashed and isWreckShown(wreck) then
			spawnFlash(wreck)
		end
	end
	if wreck.settleFrame and wreck.strikeCount < strikesPerWreck then
		local nextStrikeFrame = wreck.riseFrame
			- SMOKE_FINISH_FRAMES_BEFORE_RISE
			+ wreck.strikeCount * STRIKE_INTERVAL_FRAMES
		if frame >= nextStrikeFrame then
			wreck.strikeCount = wreck.strikeCount + 1
			if isWreckShown(wreck) then
				strikeWreck(wreck, wreck.strikeCount == 1)
			end
		end
	end
end

local function refreshAllSprites()
	for featureID, wreck in pairs(wrecks) do
		updateWreckSprites(featureID, wreck)
	end
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL_FRAMES ~= 0 then
		return
	end
	for featureID, wreck in pairs(wrecks) do
		updateWreck(featureID, wreck, frame)
	end
end

function gadget:PlayerChanged()
	local _, isFullView = spGetSpectatingState()
	local allyTeamID = spGetLocalAllyTeamID()
	if allyTeamID ~= localAllyTeamID then
		for _, wreck in pairs(wrecks) do
			wreck.seen = false
		end
	end
	localAllyTeamID = allyTeamID
	fullView = isFullView
	refreshAllSprites()
end

local function smokeCountFraction(wreck, frame)
	if frame < wreck.holdUntilFrame then
		return 0
	end
	local finishFrame = wreck.riseFrame - SMOKE_FINISH_FRAMES_BEFORE_RISE
	local progress = math.min(1.0, math.max(0.0, (frame - wreck.armFrame) / math.max(finishFrame - wreck.armFrame, 1)))
	local smokeTimerProgress =
		math.min(1, math.max(0, (progress - SMOKE_SILENT_START_FRACTION) / (1 - SMOKE_SILENT_START_FRACTION)))
	local smoothed = smokeTimerProgress * smokeTimerProgress * (3 - 2 * smokeTimerProgress)
	return smokeTimerProgress + (smoothed - smokeTimerProgress) * SMOKE_COUNT_S_CURVE_BLEND
end

local function hashRandom(a, b)
	local value = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return value - math.floor(value)
end

local function drawBillboardSmoke(wreck, frame)
	local wreckRadius = math.max(wreck.radius, 12)
	local wreckScale = math.min(2.2, math.max(0.6, wreckRadius / 20))
	local finishFrame = wreck.riseFrame - SMOKE_FINISH_FRAMES_BEFORE_RISE
	local particleCount = BILLBOARD_SMOKE_SPRITE_COUNT * smokeCountFraction(wreck, frame)
	for spriteIndex = 0, BILLBOARD_SMOKE_SPRITE_COUNT - 1 do
		local phaseRandom = hashRandom(wreck.seed, spriteIndex)
		local loopFrames = SMOKE_LIFE_FRAMES + SMOKE_LINGER_FRAMES
		local loopPosition = (frame - wreck.armFrame) / loopFrames + phaseRandom
		local loopIndex = math.floor(loopPosition)
		local loopHash = loopIndex % 1024
		local loopFrame = (loopPosition - loopIndex) * loopFrames
		local loopAge = math.min(loopFrame / SMOKE_LIFE_FRAMES, 1.0)
		local linger = math.max(loopFrame - SMOKE_LIFE_FRAMES, 0) / SMOKE_LINGER_FRAMES
		local loopEndsBeforeFinish = frame - loopFrame <= finishFrame - loopFrames
		if spriteIndex < particleCount and frame >= wreck.armFrame and loopEndsBeforeFinish then
			local angle = hashRandom(wreck.seed + loopHash * 7.919, spriteIndex + 11) * 6.2832
			local distanceRandom = hashRandom(wreck.seed + loopHash * 3.571, spriteIndex + 53)
			local heightRandom = hashRandom(wreck.seed + loopHash * 5.113, spriteIndex + 91)
			local drawnInFraction = loopAge ^ 1.4
			local startDistance = (wreckRadius + 30 * distanceRandom) * SMOKE_START_DISTANCE_SCALE * wreckScale
			local endDistance = wreckRadius * 0.35 * heightRandom
			local distance = startDistance + (endDistance - startDistance) * drawnInFraction
			local startHeight = (45 + 45 * heightRandom) * wreckScale
			local endHeight = 3 + wreckRadius * 0.4 * distanceRandom
			local height = startHeight + (endHeight - startHeight) * drawnInFraction
			local size = (34 + (5 - 34) * drawnInFraction) * wreckScale
			local alpha = (0.08 + (0.7 - 0.08) * drawnInFraction) * math.min(1, loopAge / 0.1) * (1 - linger)
			gl.Color(SMOKE_COLOR[1], SMOKE_COLOR[2], SMOKE_COLOR[3], alpha)
			gl.PushMatrix()
			gl.Translate(wreck.x + math.cos(angle) * distance, wreck.y + height, wreck.z + math.sin(angle) * distance)
			gl.Billboard()
			gl.TexRect(-size, -size, size, size)
			gl.PopMatrix()
		end
	end
end

local function drawBillboardBolt(bolt, frame)
	local boltAge = (frame - bolt.startFrame) / BILLBOARD_BOLT_FRAMES
	gl.Color(0.82, 0.7, 1, 1 - boltAge)
	gl.LineWidth(3)
	gl.BeginEnd(GL.LINE_STRIP, function()
		gl.Vertex(bolt.x, bolt.y, bolt.z)
		for step = 1, 6 do
			local jitter = 12 * (hashRandom(bolt.seed, step) - 0.5)
			gl.Vertex(
				bolt.x + jitter + math.cos(bolt.seed) * step * 2,
				bolt.y + bolt.height * step / 6,
				bolt.z - jitter + math.sin(bolt.seed) * step * 2
			)
		end
	end)
	gl.LineWidth(1)
end

local function drawBillboards()
	local frame = spGetGameFrame()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	gl.Texture(0, SMOKE_TEXTURE)
	for _, wreck in pairs(wrecks) do
		if
			wreck.settleFrame
			and isWreckShown(wreck)
			and spIsSphereInView(wreck.x, wreck.y, wreck.z, BILLBOARD_CULL_RADIUS)
		then
			drawBillboardSmoke(wreck, frame)
		end
	end
	gl.Texture(0, false)
	for index = #billboardBolts, 1, -1 do
		local bolt = billboardBolts[index]
		if frame - bolt.startFrame >= BILLBOARD_BOLT_FRAMES then
			billboardBolts[index] = billboardBolts[#billboardBolts]
			billboardBolts[#billboardBolts] = nil
		else
			drawBillboardBolt(bolt, frame)
		end
	end
	gl.Color(1, 1, 1, 1)
	gl.DepthMask(true)
	gl.DepthTest(false)
end

local function drawWreckSpriteInstances()
	---@cast spriteVBO -nil
	---@cast shader -nil
	if spriteVBO.usedElements == 0 then
		return
	end
	gl.Texture(0, SMOKE_TEXTURE)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	shader:Activate()
	local vao = spriteVBO.VAO --[[@as VAO]]
	vao:DrawArrays(GL.TRIANGLES, spriteVBO.numVertices, 0, spriteVBO.usedElements, 0)
	shader:Deactivate()
	gl.DepthMask(true)
	gl.DepthTest(false)
	gl.Texture(0, false)
end

function gadget:DrawWorld()
	if Spring.IsGUIHidden() then
		return
	end
	drawWrecks()
end

function gadget:Initialize()
	if drawsWithShaders and not initGL4() then
		drawsWithShaders = false
	end
	if drawsWithShaders then
		updateWreckSprites = updateWreckSpriteInstance
		removeWreckSprite = removeWreckSpriteInstance
		drawWrecks = drawWreckSpriteInstances
	else
		updateWreckSprites = ignoreWreckSprite
		removeWreckSprite = ignoreWreckSprite
		drawWrecks = drawBillboards
		flashesPerWreck = math.ceil(FLASH_COUNT * BILLBOARD_LIGHTNING_MULTIPLIER)
		strikesPerWreck = math.ceil(STRIKE_COUNT * BILLBOARD_LIGHTNING_MULTIPLIER)
	end
	if GG.SpawnEnvironmentalLightning then
		spawnFlash = spawnLightningFlash
		spawnStrike = spawnLightningStrike
	else
		spawnFlash = spawnBillboardFlash
		spawnStrike = spawnBillboardStrike
	end

	gadgetHandler:AddSyncAction("zombieWreckArm", armWreck)
	gadgetHandler:AddSyncAction("zombieWreckDisarm", disarmWreck)
	local _, isFullView = spGetSpectatingState()
	fullView = isFullView

	local frame = spGetGameFrame()
	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		local riseFrame = spGetFeatureRulesParam(featureID, "zombie_rez_frame")
		if riseFrame and riseFrame > frame then
			armWreck(nil, featureID, frame, riseFrame)
		end
	end
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("zombieWreckArm")
	gadgetHandler:RemoveSyncAction("zombieWreckDisarm")
	if spriteVBO then
		spriteVBO:Delete()
	end
	if spriteCornerVBO then
		spriteCornerVBO:Delete()
	end
	if shader then
		shader:Finalize()
	end
end
