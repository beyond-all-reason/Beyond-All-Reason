function gadget:GetInfo()
	return {
		name = "Zombie Wrecks GL4",
		desc = "Draws the purple puff, warning flashes, and descending specter on wrecks that will rise as zombies",
		author = "efrec",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Synced API, for game_zombies.lua:
--   GG.ZombieWreckEffects.Arm(featureID, armFrame, riseFrame)
--     starts or retimes the effects on a wreck that will rise at riseFrame
--   GG.ZombieWreckEffects.Disarm(featureID)
--     stops the effects on a wreck that rose, was cleared, or no longer exists
--
-- Each client decides for itself whether a wreck's effects are shown. A player sees them on wrecks of
-- their own ally team's units and on wrecks their ally team has seen at least once, whatever their
-- current vision.

if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced

	function gadget:Initialize()
		GG.ZombieWreckEffects = {
			---@param featureID FeatureID
			---@param armFrame integer frame the current timer started
			---@param riseFrame integer frame the wreck rises
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

if not gl.CreateShader then
	return false
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local SMOKE_TEXTURE = "bitmaps/smoke/smoke00.tga"
local SMOKE_COLOR = { 0.55, 0.42, 0.62 }

local SPECTER_STYLE = Spring.GetConfigString("ZombieSpecterStyle", "indrawn")
local SMOKE_SPRITE_COUNT = 28
local SMOKE_LIFE_FRAMES = 60
local SMOKE_COUNT_S_CURVE_BLEND = 0.35
local SMOKE_SILENT_START_FRACTION = 0.125
local SMOKE_HOLD_FRAMES_AFTER_PUSHBACK = Game.gameSpeed
local PUFF_SPRITE_COUNT = 6
local PUFF_FRAMES = Game.gameSpeed * 2

local FLASH_COUNT = 10
local FLASH_LIGHTNING_SIZE = 0.5
local SMOKE_FINISH_FRAMES_BEFORE_RISE = Game.gameSpeed * 2
local STRIKE_COUNT = 3
local STRIKE_INTERVAL_FRAMES = 12
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
local spValidFeatureID = Spring.ValidFeatureID

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local localAllyTeamID = spGetLocalAllyTeamID()
local fullView = false

---@type table<FeatureID, table?>
local wrecks = {}

local shader
---@type InstanceVBOTable?
local spriteVBO

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vertexShaderSource = [[
#version 420
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
		float angleRandom = fract(sin(seed * 39.3468 + spriteIndex * 11.135) * 24634.6345);
		float distanceRandom = fract(sin(seed * 73.1562 + spriteIndex * 52.931) * 12345.6789);
		float heightRandom = fract(sin(seed * 5.4321 + spriteIndex * 91.717) * 65432.1234);
		float smokeTimerProgress = clamp((progress - SMOKE_SILENT_START_FRACTION) / (1.0 - SMOKE_SILENT_START_FRACTION), 0.0, 1.0);
		float smokeCountFraction = mix(smokeTimerProgress, smoothstep(0.0, 1.0, smokeTimerProgress), SMOKE_COUNT_S_CURVE_BLEND);
		float smokeParticleCount = frame < hold_until_frame.x ? 0.0 : SMOKE_SPRITE_COUNT * smokeCountFraction;
		float loopAge = fract((frame - armFrame) / SMOKE_LIFE_FRAMES + phaseRandom);
		bool loopEndsBeforeFinish = frame - loopAge * SMOKE_LIFE_FRAMES <= finishFrame - SMOKE_LIFE_FRAMES;
		if (spriteIndex < smokeParticleCount && frame >= armFrame && loopEndsBeforeFinish) {
			float angle = angleRandom * 6.2832;
			float wreckScale = clamp(wreckRadius / 20.0, 0.6, 2.2);
			vec3 endPosition = vec3(cos(angle + 2.1) * wreckRadius * 0.35 * heightRandom, 3.0 + wreckRadius * 0.4 * distanceRandom, sin(angle + 2.1) * wreckRadius * 0.35 * heightRandom);
			vec3 startPosition;
			float drawnInFraction;
			#if SPECTER_STYLE == 1
				startPosition = vec3(cos(angle) * (wreckRadius + 30.0 * distanceRandom), 45.0 + 45.0 * heightRandom, sin(angle) * (wreckRadius + 30.0 * distanceRandom)) * wreckScale;
				drawnInFraction = pow(loopAge, 1.4);
			#else
				startPosition = vec3(cos(angle) * (wreckRadius * 1.5 + 50.0 * distanceRandom), 2.0, sin(angle) * (wreckRadius * 1.5 + 50.0 * distanceRandom)) * wreckScale;
				drawnInFraction = pow(loopAge, 1.2);
				endPosition.y = 2.0 + wreckRadius * 0.3 * distanceRandom;
			#endif
			vec3 wobble = vec3(sin(frame * 0.09 + phaseRandom * 6.0), 0.0, cos(frame * 0.07 + angleRandom * 6.0)) * 3.0 * (1.0 - loopAge);
			center += mix(startPosition, endPosition, drawnInFraction) + wobble;
			float possession = smoothstep(0.7, 1.0, progress);
			size = mix(34.0, 5.0 + 6.0 * possession, drawnInFraction) * wreckScale;
			alpha = mix(0.08, 0.7 + 0.3 * possession, drawnInFraction) * smoothstep(0.0, 0.1, loopAge);
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
	local vertexCount = #vertexData / 3
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)
	vbo:Define(vertexCount, { { id = 0, name = "corner_index", size = 3 } })
	vbo:Upload(vertexData)
	return vbo, vertexCount
end

local function initGL4()
	local cornerVBO, vertexCount = makeSpriteCornerVBO()
	spriteVBO = InstanceVBOTable.makeInstanceVBOTable({
		{ id = 1, name = "wreck_position", size = 4 },
		{ id = 2, name = "frames", size = 4 },
		{ id = 3, name = "hold_until_frame", size = 4 },
	}, 64, "gfx_zombie_wrecks_gl4")
	spriteVBO.vertexVBO = cornerVBO
	spriteVBO.numVertices = vertexCount
	spriteVBO.VAO = InstanceVBOTable.fillVAOSlots(
		InstanceVBOTable.makeVAOandAttach(spriteVBO.vertexVBO, spriteVBO.instanceVBO),
		false,
		true
	)

	local defines = table.concat({
		"#define SMOKE_SPRITE_COUNT " .. string.format("%.1f", SMOKE_SPRITE_COUNT),
		"#define SMOKE_LIFE_FRAMES " .. string.format("%.1f", SMOKE_LIFE_FRAMES),
		"#define SMOKE_COUNT_S_CURVE_BLEND " .. string.format("%.2f", SMOKE_COUNT_S_CURVE_BLEND),
		"#define SMOKE_SILENT_START_FRACTION " .. string.format("%.3f", SMOKE_SILENT_START_FRACTION),
		"#define SMOKE_FINISH_FRAMES_BEFORE_RISE " .. string.format("%.1f", SMOKE_FINISH_FRAMES_BEFORE_RISE),
		"#define SPECTER_STYLE " .. (SPECTER_STYLE == "seep" and "2" or "1"),
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
	return shader:Initialize()
end

--------------------------------------------------------------------------------
-- Wreck tracking
--------------------------------------------------------------------------------

local function isWreckShown(wreck)
	return fullView or wreck.allyTeamID == localAllyTeamID or wreck.seen
end

local function updateWreckSprites(featureID, wreck)
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
	elseif spriteVBO.instanceIDtoIndex[featureID] then
		popElementInstance(spriteVBO, featureID)
	end
end

---Eases in between a quadratic and an exponential curve, so flashes come closer together as the rise nears.
local function flashEasing(progress)
	local quadratic = progress * progress
	local exponential = (2 ^ (10 * progress) - 1) / 1023
	return 0.5 * (quadratic + exponential)
end

local function flashWreck(wreck)
	if GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("scavradiation", wreck.x, wreck.y, wreck.z, FLASH_LIGHTNING_SIZE)
	end
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
	if GG.SpawnEnvironmentalLightning then
		GG.SpawnEnvironmentalLightning("zombiestrike", wreck.x, wreck.y, wreck.z)
	end
	local volumeScale = thunderVolumeScale(wreck)
	if playsThunder and math.random() < volumeScale then
		local sound = THUNDER_SOUNDS[math.random(#THUNDER_SOUNDS)]
		Spring.PlaySoundFile(sound, THUNDER_VOLUME * volumeScale, wreck.x, wreck.y, wreck.z, "sfx")
	end
end

local function armWreck(_, featureID, armFrame, riseFrame)
	if not spriteVBO and not initGL4() then
		gadgetHandler:RemoveGadget()
		return
	end
	local wreck = wrecks[featureID]
	if not wreck then
		local x, y, z = spGetFeaturePosition(featureID)
		if not x then
			return
		end
		wreck = {
			radius = Spring.GetFeatureRadius(featureID) or 0,
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
	if spriteVBO and spriteVBO.instanceIDtoIndex[featureID] then
		popElementInstance(spriteVBO, featureID)
	end
end

local function updateWreck(featureID, wreck, frame)
	if not spValidFeatureID(featureID) then
		disarmWreck(nil, featureID)
		return
	end

	local changed = false
	if not wreck.settleFrame then
		local velocityX, velocityY, velocityZ = spGetFeatureVelocity(featureID)
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

	if wreck.settleFrame and wreck.flashCount < FLASH_COUNT then
		local progress = (frame - wreck.armFrame) / math.max(wreck.riseFrame - wreck.armFrame, 1)
		local easedProgress = flashEasing(math.min(progress, 1))
		local flashed = false
		while wreck.flashCount < FLASH_COUNT and easedProgress >= (wreck.flashCount + 1) / (FLASH_COUNT + 1) do
			wreck.flashCount = wreck.flashCount + 1
			flashed = true
		end
		if flashed and isWreckShown(wreck) then
			flashWreck(wreck)
		end
	end
	if wreck.settleFrame and wreck.strikeCount < STRIKE_COUNT then
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

function gadget:DrawWorld()
	if not spriteVBO or spriteVBO.usedElements == 0 or Spring.IsGUIHidden() then
		return
	end
	gl.Texture(0, SMOKE_TEXTURE)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	shader:Activate()
	spriteVBO.VAO:DrawArrays(GL.TRIANGLES, spriteVBO.numVertices, 0, spriteVBO.usedElements, 0)
	shader:Deactivate()
	gl.DepthMask(true)
	gl.DepthTest(false)
	gl.Texture(0, false)
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("zombieWreckArm", armWreck)
	gadgetHandler:AddSyncAction("zombieWreckDisarm", disarmWreck)
	local _, isFullView = spGetSpectatingState()
	fullView = isFullView

	-- After a reload, the rise frame is all that survives, so the specter restarts from now.
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
	if spriteVBO and spriteVBO.VAO then
		spriteVBO.VAO:Delete()
	end
	if shader then
		shader:Finalize()
	end
end
